import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'dto.dart';

// ---------------------------------------------------------------- erreurs

/// Réseau indisponible, délai dépassé, réponse illisible : erreur transitoire.
class NetworkException implements Exception {
  const NetworkException(this.message);
  final String message;
  @override
  String toString() => 'NetworkException: $message';
}

/// Réponse HTTP d'erreur (format FastAPI `{"detail": ...}`).
class ApiException implements Exception {
  const ApiException(this.statusCode, this.detail);
  final int statusCode;
  final String detail;

  bool get isTransient => statusCode >= 500 || statusCode == 429;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $detail';
}

/// Le refresh token est refusé : il faut se reconnecter pour synchroniser.
/// Les données locales restent utilisables.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'Session expirée : reconnexion nécessaire.';
}

// ---------------------------------------------------------------- interfaces

abstract interface class AuthApi {
  Future<TokenPair> login(String login, String password);
  Future<TokenPair> refresh(String refreshToken);
  Future<void> logout(String refreshToken);
  Future<UserProfile> me(String accessToken);
}

/// Sous-ensemble utilisé par `SyncService` (facile à simuler en test).
abstract interface class SyncApi {
  Future<PullResponse> pull({String? since, int limit = 500});
  Future<List<PushResult>> push(String deviceId, List<PushChange> changes);
}

abstract interface class InteractionApi {
  /// `POST /interactions/ask` en JSON avec des codes de signes cochés.
  Future<AskResponse> askWithSigns({
    required String module,
    String? beneficiaryId,
    required List<String> signCodes,
  });
}

/// Référentiels distribués aux applications (contrat, section 8 bis).
/// Les réponses sont renvoyées brutes (JSON) pour être mises en cache telles
/// quelles.
abstract interface class ReferenceApi {
  /// `GET /reference/sign-codes?module=`.
  Future<Map<String, dynamic>> signCodes(String module);

  /// `GET /reference/consent-information`.
  Future<Map<String, dynamic>> consentInformation();

  /// `GET /contents/published?module=` (contenus validés, plus `demo` si le
  /// serveur l'autorise). Réponse paginée `{items, total}`.
  Future<Map<String, dynamic>> publishedContents(String module);
}

/// Fournit un jeton d'accès valide et sait le renouveler (voir `AuthRepository`).
abstract interface class AccessTokenProvider {
  /// Jeton valide (rafraîchi de manière proactive s'il expire bientôt).
  Future<String> validAccessToken();

  /// Force un refresh après un 401. Lève [SessionExpiredException].
  Future<String> refreshAfterUnauthorized();
}

// ---------------------------------------------------------------- transport

class ApiTransport {
  ApiTransport({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;
  final Duration timeout;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.toString().replaceAll(RegExp(r'/+$'), '');
    final u = Uri.parse('$base$path');
    return query == null || query.isEmpty ? u : u.replace(queryParameters: query);
  }

  /// Envoie une requête JSON et renvoie le corps décodé (ou null si vide).
  Future<dynamic> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? bearer,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers['Accept'] = 'application/json';
    if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const NetworkException('Délai dépassé');
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }

    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (text.isEmpty) return null;
      try {
        return jsonDecode(text);
      } on FormatException {
        throw const NetworkException('Réponse illisible');
      }
    }
    throw ApiException(response.statusCode, _detail(text));
  }

  static String _detail(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded.containsKey('detail')) {
        final d = decoded['detail'];
        return d is String ? d : jsonEncode(d);
      }
    } on FormatException {
      // corps non JSON
    }
    return text.length > 200 ? text.substring(0, 200) : text;
  }
}

// ---------------------------------------------------------------- implémentations

class HttpAuthApi implements AuthApi {
  HttpAuthApi(this._t);
  final ApiTransport _t;

  @override
  Future<TokenPair> login(String login, String password) async {
    final json = await _t.send('POST', '/auth/login',
        body: {'login': login, 'password': password});
    return TokenPair.fromJson((json as Map).cast());
  }

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    final json = await _t.send('POST', '/auth/refresh',
        body: {'refresh_token': refreshToken});
    return TokenPair.fromJson((json as Map).cast());
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _t.send('POST', '/auth/logout', body: {'refresh_token': refreshToken});
  }

  @override
  Future<UserProfile> me(String accessToken) async {
    final json = await _t.send('GET', '/auth/me', bearer: accessToken);
    return UserProfile.fromJson((json as Map).cast());
  }
}

/// Appels authentifiés, avec un nouvel essai unique après refresh sur 401.
class HttpFaniloApi implements SyncApi, InteractionApi, ReferenceApi {
  HttpFaniloApi(this._t, this._tokens);
  final ApiTransport _t;
  final AccessTokenProvider _tokens;

  Future<dynamic> _authed(String method, String path,
      {Object? body, Map<String, String>? query}) async {
    final token = await _tokens.validAccessToken();
    try {
      return await _t.send(method, path, body: body, query: query, bearer: token);
    } on ApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
      final fresh = await _tokens.refreshAfterUnauthorized();
      return _t.send(method, path, body: body, query: query, bearer: fresh);
    }
  }

  @override
  Future<PullResponse> pull({String? since, int limit = 500}) async {
    final json = await _authed('GET', '/sync/pull', query: {
      if (since != null) 'since': since,
      'limit': '$limit',
    });
    return PullResponse.fromJson((json as Map).cast());
  }

  @override
  Future<List<PushResult>> push(String deviceId, List<PushChange> changes) async {
    final json = await _authed('POST', '/sync/push', body: {
      'device_id': deviceId,
      'changes': changes.map((c) => c.toJson()).toList(),
    });
    final results = ((json as Map)['results'] as List?) ?? const [];
    return results
        .map((r) => PushResult.fromJson((r as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<AskResponse> askWithSigns({
    required String module,
    String? beneficiaryId,
    required List<String> signCodes,
  }) async {
    final json = await _authed('POST', '/interactions/ask', body: {
      'module': module,
      if (beneficiaryId != null) 'beneficiary_id': beneficiaryId,
      'sign_codes': signCodes,
    });
    return AskResponse.fromJson((json as Map).cast());
  }

  @override
  Future<Map<String, dynamic>> signCodes(String module) async {
    final json =
        await _authed('GET', '/reference/sign-codes', query: {'module': module});
    return (json as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> consentInformation() async {
    final json = await _authed('GET', '/reference/consent-information');
    return (json as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> publishedContents(String module) async {
    final json = await _authed('GET', '/contents/published',
        // Malgache d'abord : seuls les messages destinés aux femmes sont servis.
        query: {'module': module, 'language': 'mg', 'limit': '200'});
    return (json as Map).cast<String, dynamic>();
  }
}
