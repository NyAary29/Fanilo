/// Modèles de l'API publique anonyme (`docs/api-publique.md`).
library;

enum Module {
  reny,
  tanora;

  static Module parse(String v) => Module.values.firstWhere((m) => m.name == v);
}

class Site {
  const Site({required this.id, required this.name, this.district, this.region});
  final String id;
  final String name;
  final String? district;
  final String? region;

  factory Site.fromJson(Map<String, dynamic> j) => Site(
        id: j['id'] as String,
        name: j['name'] as String,
        district: j['district'] as String?,
        region: j['region'] as String?,
      );

  String get place => [district, region].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
}

/// Information à présenter (portées `tanora`, `reny`, `voice_processing`).
class InformationItem {
  const InformationItem({
    required this.scope,
    required this.version,
    required this.status,
    required this.summaryFr,
    this.summaryMg,
  });
  final String scope;
  final String version;
  final String status;
  final String summaryFr;
  final String? summaryMg;

  bool get isValidated => status == 'validated';

  /// Texte dans la langue demandée, sinon en français.
  String summary(String language) =>
      language == 'mg' && (summaryMg?.isNotEmpty ?? false) ? summaryMg! : summaryFr;

  factory InformationItem.fromJson(Map<String, dynamic> j) => InformationItem(
        scope: j['scope'] as String,
        version: j['version'] as String,
        status: j['status'] as String,
        summaryFr: j['summary_fr'] as String,
        summaryMg: j['summary_mg'] as String?,
      );
}

/// Contenu publié, identifié par un code.
class Content {
  const Content({
    required this.code,
    required this.title,
    required this.body,
    this.audioUrl,
    required this.status,
  });
  final String code;
  final String title;
  final String body;
  final String? audioUrl;
  final String status;

  bool get isValidated => status == 'validated';

  factory Content.fromJson(Map<String, dynamic> j) => Content(
        code: j['code'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        audioUrl: j['audio_url'] as String?,
        status: j['status'] as String? ?? 'demo',
      );
}

class MenuItem {
  const MenuItem({required this.key, required this.content});
  final int key;
  final Content content;

  factory MenuItem.fromJson(Map<String, dynamic> j) =>
      MenuItem(key: (j['key'] as num).toInt(), content: Content.fromJson(j));
}

class Menu {
  const Menu({
    required this.configId,
    required this.version,
    required this.isDemo,
    required this.module,
    required this.items,
  });
  final String configId;
  final String version;
  final bool isDemo;
  final Module module;
  final List<MenuItem> items;

  factory Menu.fromJson(Map<String, dynamic> j) => Menu(
        configId: j['config_id'] as String,
        version: j['version'] as String,
        isDemo: j['is_demo'] as bool? ?? true,
        module: Module.parse(j['module'] as String),
        items: [
          for (final i in (j['items'] as List)) MenuItem.fromJson(i as Map<String, dynamic>)
        ],
      );
}

class FollowUp {
  const FollowUp({required this.token, required this.status});
  final String token;
  final String status;

  factory FollowUp.fromJson(Map<String, dynamic> j) =>
      FollowUp(token: j['token'] as String, status: j['status'] as String? ?? 'pending');
}

/// Réponse de `POST /public/ask`.
class AskResult {
  const AskResult({
    required this.questionId,
    this.transcript,
    this.transcriptNeedsReview = false,
    required this.outcome,
    this.actions = const [],
    this.content,
    required this.urgent,
    this.followUp,
    required this.isDemo,
    required this.disclaimer,
  });
  final String questionId;
  final String? transcript;
  final bool transcriptNeedsReview;

  /// `answer`, `danger_sign` ou `fallback`.
  final String outcome;
  final List<String> actions;
  final Content? content;

  /// Signe de danger reconnu OU suspecté : le bloc d'urgence s'affiche quel
  /// que soit `outcome`.
  final bool urgent;
  final FollowUp? followUp;
  final bool isDemo;
  final String disclaimer;

  /// Le bandeau DÉMO s'affiche si la réponse est démo ou si le contenu n'est
  /// pas validé.
  bool get showDemoBanner => isDemo || (content != null && !content!.isValidated);

  factory AskResult.fromJson(Map<String, dynamic> j) => AskResult(
        questionId: j['question_id'] as String,
        transcript: j['transcript'] as String?,
        transcriptNeedsReview: j['transcript_needs_review'] as bool? ?? false,
        outcome: j['outcome'] as String,
        actions: [for (final a in (j['actions'] as List? ?? const [])) a as String],
        content: j['content'] == null
            ? null
            : Content.fromJson(j['content'] as Map<String, dynamic>),
        urgent: j['urgent'] as bool? ?? false,
        followUp: j['follow_up'] == null
            ? null
            : FollowUp.fromJson(j['follow_up'] as Map<String, dynamic>),
        isDemo: j['is_demo'] as bool? ?? true,
        disclaimer: j['disclaimer'] as String? ?? '',
      );
}

/// État d'une question suivie par un conseiller.
class QuestionStatus {
  const QuestionStatus({
    required this.questionId,
    required this.module,
    required this.status,
    this.answer,
    this.answeredAt,
    this.orientation,
    this.triage,
    this.followUpCode,
    this.followUpStatus,
  });

  /// Classement du conseiller : `urgent`, `follow_up` ou `info`.
  final String? triage;

  /// Code à montrer au centre de santé (sans nom), ex. « K7-42 ».
  final String? followUpCode;

  /// Suivi par le centre : `expected`, `came` ou `no_show`.
  final String? followUpStatus;
  final String questionId;
  final Module module;

  /// Structure de santé vers laquelle le conseiller oriente (si répondu).
  final CareOrientation? orientation;

  /// `pending` ou `answered`.
  final String status;
  final String? answer;
  final DateTime? answeredAt;

  bool get isAnswered => status == 'answered';

  factory QuestionStatus.fromJson(Map<String, dynamic> j) => QuestionStatus(
        questionId: j['question_id'] as String,
        module: Module.parse(j['module'] as String),
        status: j['status'] as String,
        answer: j['answer'] as String?,
        answeredAt: j['answered_at'] == null
            ? null
            : DateTime.tryParse(j['answered_at'] as String),
        orientation: j['orientation'] is Map<String, dynamic>
            ? CareOrientation.fromJson(j['orientation'] as Map<String, dynamic>)
            : null,
        triage: j['triage'] as String?,
        followUpCode: j['follow_up_code'] as String?,
        followUpStatus: j['follow_up_status'] as String?,
      );
}

/// CareOrientation donnée par le conseiller : `csb` ou `reference_facility`.
class CareOrientation {
  const CareOrientation({required this.name, required this.kind, this.district, this.region});
  final String name;
  final String kind;
  final String? district;
  final String? region;

  bool get isReferenceFacility => kind == 'reference_facility';

  String get place =>
      [district, region].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  factory CareOrientation.fromJson(Map<String, dynamic> j) => CareOrientation(
        name: j['name'] as String,
        kind: j['kind'] as String? ?? 'csb',
        district: j['district'] as String?,
        region: j['region'] as String?,
      );
}

/// Audio enregistré, envoyé en multipart.
class VoiceClip {
  const VoiceClip({required this.bytes, required this.filename, required this.mimeType});
  final List<int> bytes;
  final String filename;
  final String mimeType;
}
