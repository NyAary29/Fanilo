import 'dart:convert';
import 'dart:developer' as developer;


import '../../domain/reference_data.dart';
import '../api/api_client.dart';
import '../local/database.dart';

/// Référentiels (codes de signes, information de consentement) : récupérés
/// sur l'API quand le réseau est là, conservés en base (chiffrée) pour être
/// utilisables hors ligne. En cas d'échec, la dernière copie reçue reste en
/// vigueur ; s'il n'y en a aucune, l'écran concerné demande une
/// synchronisation.
class ReferenceRepository {
  ReferenceRepository(
    this.db,
    this.api, {
    this.modules = const ['reny'],
    this.minInterval = const Duration(hours: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase db;
  final ReferenceApi api;

  /// Modules dont on récupère les codes de signes.
  final List<String> modules;

  /// Délai minimal entre deux rafraîchissements non forcés.
  final Duration minInterval;
  final DateTime Function() _now;

  static String signCodesKey(String module) => 'sign-codes:$module';
  static const consentInformationKey = 'consent-information';
  static String contentsKey(String module) => 'contents:$module';

  Stream<SignCatalog?> watchSignCatalog(String module) =>
      _watch(signCodesKey(module)).map(
          (json) => json == null ? null : SignCatalog.fromJson(json));

  Stream<ConsentInformationSet?> watchConsentInformation() =>
      _watch(consentInformationKey).map(
          (json) => json == null ? null : ConsentInformationSet.fromJson(json));

  /// Contenus publiés (copie locale), null si jamais reçus.
  Stream<PublishedContents?> watchContents(String module) =>
      _watch(contentsKey(module)).map(
          (json) => json == null ? null : PublishedContents.fromJson(json));

  /// Rafraîchit la copie locale des contenus publiés (conseils de visite).
  /// Séparé de [refresh] : ce n'est pas un référentiel de sécurité et son
  /// échec n'a aucune incidence. Ne lève jamais d'exception.
  Future<bool> refreshContents({bool force = false}) async {
    var ok = true;
    for (final m in modules) {
      ok &= await _refreshOne(contentsKey(m), () => api.publishedContents(m),
          force: force, validate: (j) {
        if (j['items'] is! List) throw const FormatException('items manquant');
        return PublishedContents.fromJson(j);
      });
    }
    return ok;
  }

  Future<ConsentInformationSet?> consentInformation() async {
    final json = await _read(consentInformationKey);
    return json == null ? null : ConsentInformationSet.fromJson(json);
  }

  /// Rafraîchit les référentiels. Ne lève jamais d'exception : renvoie
  /// `true` si tout a été mis à jour (ou était encore récent).
  Future<bool> refresh({bool force = false}) async {
    var ok = true;
    for (final m in modules) {
      ok &= await _refreshOne(signCodesKey(m), () => api.signCodes(m),
          force: force, validate: (j) => SignCatalog.fromJson(j));
    }
    ok &= await _refreshOne(consentInformationKey, api.consentInformation,
        force: force, validate: (j) => ConsentInformationSet.fromJson(j));
    return ok;
  }

  Future<bool> _refreshOne(
    String key,
    Future<Map<String, dynamic>> Function() fetch, {
    required bool force,
    required Object Function(Map<String, dynamic>) validate,
  }) async {
    if (!force) {
      final row = await (db.select(db.referenceCache)
            ..where((r) => r.key.equals(key)))
          .getSingleOrNull();
      if (row != null && _now().toUtc().difference(row.fetchedAt) < minInterval) {
        return true;
      }
    }
    try {
      final json = await fetch();
      validate(json); // lève si la forme est inattendue : cache conservé
      await db.into(db.referenceCache).insertOnConflictUpdate(
          ReferenceCacheCompanion.insert(
              key: key, json: jsonEncode(json), fetchedAt: _now().toUtc()));
      return true;
    } on Object catch (e) {
      // Hors ligne, 503 (référentiel non servi), session expirée… : la copie
      // locale reste en vigueur.
      developer.log('Référentiel $key non rafraîchi', error: e, name: 'fanilo.reference');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _read(String key) async {
    final row = await (db.select(db.referenceCache)..where((r) => r.key.equals(key)))
        .getSingleOrNull();
    return _decode(row);
  }

  Stream<Map<String, dynamic>?> _watch(String key) =>
      (db.select(db.referenceCache)..where((r) => r.key.equals(key)))
          .watchSingleOrNull()
          .map(_decode);

  static Map<String, dynamic>? _decode(ReferenceCacheRow? row) {
    if (row == null) return null;
    try {
      return (jsonDecode(row.json) as Map).cast<String, dynamic>();
    } on Object {
      return null;
    }
  }
}
