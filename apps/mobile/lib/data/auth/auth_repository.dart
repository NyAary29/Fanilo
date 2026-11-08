import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/dto.dart';
import '../secure/secure_store.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.needsReauth = false,
  });

  final AuthStatus status;
  final UserProfile? user;

  /// Le refresh token a été refusé : la synchronisation est impossible tant
  /// que l'utilisateur ne s'est pas reconnecté, mais les données locales
  /// restent accessibles (hors ligne).
  final bool needsReauth;

  static const unknown = AuthState(status: AuthStatus.unknown);
  static const signedOut = AuthState(status: AuthStatus.signedOut);
}

class DifferentUserException implements Exception {
  const DifferentUserException();
  @override
  String toString() =>
      'Un autre compte est déjà ouvert sur cet appareil. Déconnectez-le d\'abord.';
}

/// Session de l'utilisateur : jetons dans le stockage sécurisé, refresh
/// automatique (proactif et sur 401), profil mis en cache pour l'usage
/// hors ligne.
class AuthRepository extends StateNotifier<AuthState>
    implements AccessTokenProvider {
  AuthRepository(this._api, this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(AuthState.unknown);

  static const kAccess = 'fanilo.access_token';
  static const kAccessExp = 'fanilo.access_expires_at';
  static const kRefresh = 'fanilo.refresh_token';
  static const kUser = 'fanilo.user';

  /// Marge de refresh proactif avant l'expiration du jeton d'accès.
  static const refreshMargin = Duration(seconds: 60);

  final AuthApi _api;
  final SecureStore _store;
  final DateTime Function() _now;
  Future<String>? _refreshing;

  UserProfile? get user => state.user;

  /// Restaure la session au démarrage, sans réseau.
  Future<void> restore() async {
    final userJson = await _store.read(kUser);
    final refresh = await _store.read(kRefresh);
    if (userJson == null || refresh == null) {
      state = AuthState.signedOut;
      return;
    }
    try {
      final user = UserProfile.fromJson(
          (jsonDecode(userJson) as Map).cast<String, dynamic>());
      state = AuthState(status: AuthStatus.signedIn, user: user);
    } on Object {
      state = AuthState.signedOut;
    }
  }

  Future<UserProfile> login(String login, String password) async {
    final tokens = await _api.login(login.trim(), password);
    final profile = await _api.me(tokens.accessToken);
    final current = state.user;
    if (current != null && current.id != profile.id) {
      // Ré-authentification avec un autre compte : on ne mélange pas les
      // données locales de deux utilisateurs.
      try {
        await _api.logout(tokens.refreshToken);
      } on Object {
        // sans conséquence
      }
      throw const DifferentUserException();
    }
    await _saveTokens(tokens);
    await _store.write(kUser, jsonEncode(profile.toJson()));
    state = AuthState(status: AuthStatus.signedIn, user: profile);
    return profile;
  }

  Future<void> logout() async {
    final refresh = await _store.read(kRefresh);
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } on Object {
        // hors ligne : on efface quand même la session locale
      }
    }
    await _store.delete(kAccess);
    await _store.delete(kAccessExp);
    await _store.delete(kRefresh);
    await _store.delete(kUser);
    state = AuthState.signedOut;
  }

  @override
  Future<String> validAccessToken() async {
    final token = await _store.read(kAccess);
    final exp = DateTime.tryParse(await _store.read(kAccessExp) ?? '');
    if (token != null &&
        exp != null &&
        _now().toUtc().isBefore(exp.subtract(refreshMargin))) {
      return token;
    }
    return _refreshOnce();
  }

  @override
  Future<String> refreshAfterUnauthorized() => _refreshOnce();

  /// Un seul refresh à la fois (rotation des refresh tokens côté serveur).
  Future<String> _refreshOnce() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    final f = _doRefresh();
    _refreshing = f;
    return f.whenComplete(() => _refreshing = null);
  }

  Future<String> _doRefresh() async {
    final refresh = await _store.read(kRefresh);
    if (refresh == null) {
      _markNeedsReauth();
      throw const SessionExpiredException();
    }
    try {
      final tokens = await _api.refresh(refresh);
      await _saveTokens(tokens);
      if (state.needsReauth) {
        state = AuthState(status: state.status, user: state.user);
      }
      return tokens.accessToken;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 400) {
        _markNeedsReauth();
        throw const SessionExpiredException();
      }
      rethrow;
    }
  }

  void _markNeedsReauth() {
    if (state.status == AuthStatus.signedIn && !state.needsReauth) {
      state = AuthState(
          status: AuthStatus.signedIn, user: state.user, needsReauth: true);
    }
  }

  Future<void> _saveTokens(TokenPair t) async {
    await _store.write(kAccess, t.accessToken);
    await _store.write(kAccessExp, t.accessExpiresAt.toIso8601String());
    await _store.write(kRefresh, t.refreshToken);
  }
}
