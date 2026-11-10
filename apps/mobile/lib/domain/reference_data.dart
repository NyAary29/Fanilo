/// Référentiels distribués par l'API (contrat, section 8 bis) :
/// codes de signes et versions de l'information de consentement.
///
/// Ils ne sont **jamais** codés en dur dans l'application : ils viennent de
/// `GET /reference/sign-codes?module=` et `GET /reference/consent-information`
/// et sont conservés en local (dernière copie reçue) pour le travail hors
/// ligne. Le bandeau « DÉMO » dépend de `is_demo` et `status` renvoyés par le
/// serveur.
library;

import 'enums.dart';

class SignDefinition {
  const SignDefinition({
    required this.code,
    required this.modules,
    required this.labelFr,
    this.labelMg,
  });

  final String code;
  final Set<String> modules;
  final String labelFr;
  final String? labelMg;

  /// Libellé affiché (français pour l'instant ; malgache quand l'interface
  /// sera traduite).
  String get label => labelFr;
}

class SignCatalog {
  const SignCatalog({
    required this.catalogId,
    required this.version,
    required this.status,
    required this.isDemo,
    required this.signs,
  });

  final String catalogId;
  final String version;
  final String status;
  final bool isDemo;
  final List<SignDefinition> signs;

  /// Bandeau « DÉMO » tant que le référentiel n'est pas `validated` ou que le
  /// serveur le déclare de démonstration.
  bool get showDemoBanner => isDemo || status != 'validated';

  List<SignDefinition> forModule(String module) =>
      signs.where((s) => s.modules.contains(module)).toList();

  /// Lecture tolérante de `{catalog_id, version, status, is_demo, items}`.
  /// Un élément sans `code` est ignoré. En cas de doute, on considère le
  /// référentiel comme de démonstration.
  factory SignCatalog.fromJson(Map<String, dynamic> json) => SignCatalog(
        catalogId: json['catalog_id']?.toString() ?? '',
        version: json['version']?.toString() ?? '',
        status: json['status']?.toString() ?? 'demo',
        isDemo: json['is_demo'] as bool? ?? true,
        signs: [
          for (final raw in (json['items'] as List?) ?? const [])
            if (raw is Map && raw['code'] is String)
              SignDefinition(
                code: raw['code'] as String,
                labelFr: raw['label_fr']?.toString() ?? raw['code'] as String,
                labelMg: raw['label_mg'] as String?,
                modules: {
                  for (final m in (raw['modules'] as List?) ?? const []) m.toString()
                },
              ),
        ],
      );
}

/// Information présentée lors du consentement, pour une portée donnée.
class ConsentInformation {
  const ConsentInformation({
    required this.scope,
    required this.version,
    required this.status,
    required this.summaryFr,
    this.summaryMg,
  });

  final ConsentScope scope;
  final String version;
  final String status;
  final String summaryFr;
  final String? summaryMg;

  bool get isDemo => status != 'validated';
}

class ConsentInformationSet {
  const ConsentInformationSet(this.items);
  final List<ConsentInformation> items;

  /// Information à présenter pour [scope] (null si le serveur n'en sert
  /// aucune : la portée ne peut alors pas être recueillie).
  ConsentInformation? forScope(ConsentScope scope) {
    for (final i in items) {
      if (i.scope == scope) return i;
    }
    return null;
  }

  bool get anyDemo => items.any((i) => i.isDemo);

  /// Lecture tolérante de `{items: [{scope, version, status, summary_fr,
  /// summary_mg}]}`. Les portées inconnues et les versions vides sont ignorées.
  factory ConsentInformationSet.fromJson(Map<String, dynamic> json) =>
      ConsentInformationSet([
        for (final raw in (json['items'] as List?) ?? const [])
          if (raw is Map &&
              ConsentScope.fromWire(raw['scope'] as String?) != null &&
              (raw['version']?.toString().trim().isNotEmpty ?? false))
            ConsentInformation(
              scope: ConsentScope.fromWire(raw['scope'] as String?)!,
              version: raw['version'].toString().trim(),
              status: raw['status']?.toString() ?? 'demo',
              summaryFr: raw['summary_fr']?.toString() ?? '',
              summaryMg: raw['summary_mg'] as String?,
            ),
      ]);
}

/// Contenu de santé publié (`GET /contents/published`), validé par le
/// responsable clinique (ou `demo` si le serveur autorise la démonstration).
/// Sert de support aux conseils donnés pendant une visite ; l'application
/// n'écrit aucun texte médical elle-même.
class HealthContent {
  const HealthContent({
    required this.code,
    required this.module,
    required this.language,
    required this.title,
    required this.body,
    required this.status,
  });

  final String code;
  final String module;
  final String language;
  final String title;
  final String body;
  final String status;

  bool get isDemo => status != 'validated';
}

class PublishedContents {
  const PublishedContents(this.items);
  final List<HealthContent> items;

  bool get anyDemo => items.any((c) => c.isDemo);

  /// Contenus à proposer pour [module] (le module `common` est inclus par le
  /// serveur), en [language] de préférence : un code absent dans cette langue
  /// est repris dans une autre langue.
  List<HealthContent> forModule(String module, {String language = 'fr'}) {
    final byCode = <String, HealthContent>{};
    for (final c in items) {
      if (c.module != module && c.module != 'common') continue;
      final current = byCode[c.code];
      if (current == null || (current.language != language && c.language == language)) {
        byCode[c.code] = c;
      }
    }
    return byCode.values.toList()..sort((a, b) => a.code.compareTo(b.code));
  }

  /// Lecture tolérante de `{items: [ContentItem], total}`. Un contenu sans
  /// code ou sans texte est ignoré, ainsi qu'un statut non publié.
  factory PublishedContents.fromJson(Map<String, dynamic> json) => PublishedContents([
        for (final raw in (json['items'] as List?) ?? const [])
          if (raw is Map &&
              raw['code'] is String &&
              (raw['body']?.toString().trim().isNotEmpty ?? false) &&
              (raw['status'] == 'validated' || raw['status'] == 'demo'))
            HealthContent(
              code: raw['code'] as String,
              module: raw['module']?.toString() ?? 'common',
              language: raw['language']?.toString() ?? 'fr',
              title: raw['title']?.toString() ?? '',
              body: raw['body'].toString(),
              status: raw['status'] as String,
            ),
      ]);
}
