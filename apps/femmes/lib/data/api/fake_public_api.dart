import 'models.dart';
import 'public_api.dart';

/// Fausse API publique, fidèle à `docs/api-publique.md`, pour les tests et la
/// démonstration hors ligne (`--dart-define=FANILO_FAKE_API=true`).
///
/// Tous les contenus sont FICTIFS et marqués DÉMO. Aucune règle clinique ici :
/// le mot « ra » (sang) déclenche seulement le cas `urgent` pour tester
/// l'affichage.
class FakePublicApi implements PublicApi {
  FakePublicApi({this.answerAfterPolls});

  /// Nombre de lectures `pending` avant qu'une question passe `answered`
  /// (démonstration). Null : seulement via [answer] (tests).
  final int? answerAfterPolls;

  /// Délai simulé de la transcription d'une question vocale.
  Duration voiceDelay = Duration.zero;

  /// Transcription renvoyée pour une question vocale (null : non transcrite).
  String? voiceTranscript = 'fanontaniana am-peo';

  /// Un conseiller répond (comme une revue dans le tableau de bord).
  void answer(String questionId, String text,
          {CareOrientation? orientation, String? triage, String? code, String? visit}) =>
      questions[questionId]!
        ..answer = text
        ..orientation = orientation
        ..triage = triage
        ..code = code
        ..visit = visit;

  /// Si non nul, toutes les requêtes échouent avec cette erreur.
  ApiException? failWith;

  int _seq = 0;
  final Map<String, FakeQuestion> questions = {};
  final List<String> calls = [];

  static const _disclaimer = 'FANILO ne remplace pas un professionnel de santé.';

  static Content _c(String code, String title, String body) =>
      Content(code: code, title: '[DÉMO] $title', body: '[DÉMO] $body', status: 'demo');

  void _check(String call) {
    calls.add(call);
    if (failWith != null) throw failWith!;
  }

  @override
  Future<List<Site>> sites() async {
    _check('sites');
    return const [
      Site(id: 'site-1', name: 'CSB II Démo Bongolava A', district: 'Tsiroanomandidy', region: 'Bongolava'),
      Site(id: 'site-2', name: 'CSB II Démo Bongolava B', district: 'Fenoarivobe', region: 'Bongolava'),
      Site(id: 'site-3', name: 'CSB II Démo Antananarivo C', district: 'Antananarivo Renivohitra', region: 'Analamanga'),
    ];
  }

  @override
  Future<List<InformationItem>> information() async {
    _check('information');
    return const [
      InformationItem(
          scope: 'tanora',
          version: 'demo-0.1',
          status: 'demo',
          summaryFr: '[DÉMO] Vos questions sont lues par un conseiller pour vous orienter.'),
      InformationItem(
          scope: 'reny',
          version: 'demo-0.1',
          status: 'demo',
          summaryFr: '[DÉMO] Informations sur la grossesse et orientation vers le CSB.'),
      InformationItem(
          scope: 'voice_processing',
          version: 'demo-0.1',
          status: 'demo',
          summaryFr:
              "[DÉMO] Vos messages vocaux sont transcrits automatiquement. L'audio n'est pas conservé."),
    ];
  }

  @override
  Future<Menu> menus(Module module, String language) async {
    _check('menus:${module.name}:$language');
    final items = module == Module.reny
        ? [
            MenuItem(key: 1, content: _c('MSG_DEMO_INFO_ANC', 'Consultations prénatales',
                'Les dates de vos consultations sont fixées avec votre agent communautaire et le CSB.')),
            MenuItem(key: 2, content: _c('MSG_DEMO_INFO_NUTRITION', 'Alimentation',
                "Parlez de votre alimentation avec l'agent communautaire ou le CSB.")),
            MenuItem(key: 3, content: _c('MSG_DEMO_DANGER', 'Signes qui inquiètent',
                'Au moindre doute, allez au centre de santé le plus proche.')),
          ]
        : [
            MenuItem(key: 1, content: _c('MSG_DEMO_INFO_MENSTRUATION', 'Questions sur les règles',
                'Vous pouvez poser vos questions, en toute confidentialité, à un conseiller.')),
            MenuItem(key: 2, content: _c('MSG_DEMO_TANORA_COUNSELOR', 'Parler à un conseiller',
                'Un conseiller peut vous écouter en toute confidentialité.')),
          ];
    return Menu(
        configId: 'fake-demo', version: '0.1.0', isDemo: true, module: module, items: items);
  }

  AskResult _answer(Module module, String? transcript, {bool voice = false}) {
    final id = 'q-${++_seq}';
    final lower = (transcript ?? '').toLowerCase();
    final danger = RegExp(r'\bra\b|saignement|sang').hasMatch(lower);
    final needsCounselor =
        danger || voice || module == Module.tanora || !lower.contains('cpn');
    FollowUp? follow;
    if (needsCounselor) {
      final token = 'tok-$id-0123456789abcdef';
      questions[id] = FakeQuestion(module: module, token: token);
      follow = FollowUp(token: token, status: 'pending');
    }
    return AskResult(
      questionId: id,
      transcript: transcript,
      outcome: danger ? 'danger_sign' : (lower.contains('cpn') ? 'answer' : 'fallback'),
      actions: danger ? const ['refer_csb'] : const ['transfer_counselor'],
      content: danger
          ? _c('MSG_DEMO_REFER_CSB', 'Allez au centre de santé',
              'Rendez-vous au centre de santé le plus proche, sans attendre.')
          : lower.contains('cpn')
              ? _c('MSG_DEMO_INFO_ANC', 'Consultations prénatales',
                  'Les dates de vos consultations sont fixées avec votre agent communautaire et le CSB.')
              : _c('MSG_DEMO_TRANSFER_COUNSELOR', 'Question transmise à un conseiller',
                  "Votre question est transmise à un conseiller ; aucun délai n'est garanti."),
      urgent: danger,
      followUp: follow,
      isDemo: true,
      disclaimer: _disclaimer,
    );
  }

  @override
  Future<AskResult> askText(
      {required Module module,
      required String text,
      required String language,
      String? siteId}) async {
    _check('askText:${module.name}');
    return _answer(module, text);
  }

  @override
  Future<AskResult> askVoice(
      {required Module module,
      required VoiceClip clip,
      required String language,
      String? siteId,
      required bool voiceConsent}) async {
    _check('askVoice:${module.name}:$voiceConsent');
    if (voiceDelay > Duration.zero) await Future<void>.delayed(voiceDelay);
    if (!voiceConsent) {
      throw const ApiException(ApiErrorKind.consentRequired, statusCode: 422);
    }
    return _answer(module, voiceTranscript, voice: true);
  }

  @override
  Future<QuestionStatus> question(String questionId, String token) async {
    _check('question:$questionId');
    final q = questions[questionId];
    if (q == null || q.token != token) {
      throw const ApiException(ApiErrorKind.notFound, statusCode: 404);
    }
    q.polls++;
    if (answerAfterPolls != null && q.polls > answerAfterPolls! && q.answer == null) {
      q.answer = '[DÉMO] Réponse fictive du conseiller.';
      q.orientation = const CareOrientation(
          name: 'CSB II Démo Bongolava A',
          kind: 'csb',
          district: 'Tsiroanomandidy',
          region: 'Bongolava');
      q.triage = 'follow_up';
      q.code = 'K7-42';
      q.visit = 'expected';
    }
    final answered = q.answer != null;
    return QuestionStatus(
      questionId: questionId,
      module: q.module,
      status: answered ? 'answered' : 'pending',
      answer: q.answer,
      orientation: answered ? q.orientation : null,
      triage: answered ? q.triage : null,
      followUpCode: answered ? q.code : null,
      followUpStatus: answered ? q.visit : null,
      answeredAt: answered ? DateTime.utc(2026, 11, 9, 10) : null,
    );
  }

  @override
  Future<void> deleteQuestion(String questionId, String token) async {
    _check('delete:$questionId');
    final q = questions[questionId];
    if (q == null || q.token != token) {
      throw const ApiException(ApiErrorKind.notFound, statusCode: 404);
    }
    questions.remove(questionId);
  }
}

class FakeQuestion {
  FakeQuestion({required this.module, required this.token});
  final Module module;
  final String token;
  int polls = 0;
  String? answer;
  CareOrientation? orientation;
  String? triage;
  String? code;
  String? visit;
}
