/// Référentiel de codes de signes affiché à l'AC.
///
/// !!! DÉMONSTRATION — NON VALIDÉ CLINIQUEMENT — NE PAS UTILISER EN SOINS !!!
///
/// Copie fictive de `services/rules/rulesets/demo/sign_codes.demo.yaml`.
/// La liste réelle (F-07) doit être validée par le responsable clinique puis
/// distribuée à l'application (idéalement par l'API, ce que le contrat ne
/// prévoit pas encore). Tant que [SignCatalog.isValidated] est faux, l'écran
/// affiche un bandeau « DÉMO ».
class SignDefinition {
  const SignDefinition({
    required this.code,
    required this.modules,
    required this.label,
  });
  final String code;
  final Set<String> modules;
  final String label;
}

class SignCatalog {
  const SignCatalog({
    required this.catalogId,
    required this.version,
    required this.status,
    required this.signs,
  });

  final String catalogId;
  final String version;
  final String status;
  final List<SignDefinition> signs;

  bool get isValidated => status == 'validated';

  List<SignDefinition> forModule(String module) =>
      signs.where((s) => s.modules.contains(module)).toList();

  static const demo = SignCatalog(
    catalogId: 'fanilo-demo-signs',
    version: '0.1.0',
    status: 'demo',
    signs: [
      SignDefinition(
          code: 'SIGN_DEMO_01',
          modules: {'reny'},
          label: '[DÉMO] Signe fictif n° 1'),
      SignDefinition(
          code: 'SIGN_DEMO_02',
          modules: {'reny'},
          label: '[DÉMO] Signe fictif n° 2'),
      SignDefinition(
          code: 'SIGN_DEMO_03',
          modules: {'reny'},
          label: '[DÉMO] Signe fictif n° 3'),
      SignDefinition(
          code: 'SIGN_DEMO_04',
          modules: {'reny'},
          label: '[DÉMO] Signe fictif n° 4'),
      SignDefinition(
          code: 'SIGN_DEMO_05',
          modules: {'reny', 'tanora'},
          label: '[DÉMO] Signe fictif n° 5'),
      SignDefinition(
          code: 'SIGN_DEMO_06',
          modules: {'tanora'},
          label: '[DÉMO] Signe fictif n° 6 (tanora)'),
    ],
  );
}

/// Versions de l'information présentée lors du consentement.
///
/// FICTIF : le texte et ses versions doivent être validés (clinique et
/// juridique, F-01). Le contrat ne fournit pas encore d'endpoint pour les lister.
const List<String> kInformationVersions = ['INFO-DEMO-0.1'];
