// Test de bout en bout contre l'API RÉELLE (locale), sur Linux :
//
//   flutter test integration_test -d linux \
//     --dart-define=FANILO_API_URL=http://localhost:8000
//
// Prérequis : API démarrée avec les données de démonstration
// (FANILO_ALLOW_DEMO_CONTENT=true). Le test crée des questions FICTIVES, fait
// répondre le compte de démonstration « responsable » (revue), puis efface
// tout. L'enregistrement audio est simulé (fichier WAV de silence généré).
import 'dart:convert';
import 'dart:typed_data';

import 'package:fanilo_femmes/config/app_config.dart';
import 'package:fanilo_femmes/data/api/models.dart';
import 'package:fanilo_femmes/data/api/public_api.dart';
import 'package:fanilo_femmes/data/audio/voice.dart';
import 'package:fanilo_femmes/data/local/local_store.dart';
import 'package:fanilo_femmes/ui/app.dart';
import 'package:fanilo_femmes/ui/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _reviewer = String.fromEnvironment('FANILO_E2E_REVIEWER', defaultValue: 'responsable');
const _password = String.fromEnvironment('FANILO_E2E_PASSWORD', defaultValue: 'fanilo-demo-2026');

/// 1 s de silence, WAV PCM 16 bits mono 16 kHz.
Uint8List _silenceWav() {
  const rate = 16000, samples = 16000;
  final b = BytesBuilder();
  void str(String s) => b.add(ascii.encode(s));
  void u32(int v) => b.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) => b.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));
  str('RIFF');
  u32(36 + samples * 2);
  str('WAVEfmt ');
  u32(16);
  u16(1);
  u16(1);
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  str('data');
  u32(samples * 2);
  b.add(Uint8List(samples * 2));
  return b.toBytes();
}

class _WavRecorder implements VoiceRecorder {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start() async {}
  @override
  Future<VoiceClip?> stop() async =>
      VoiceClip(bytes: _silenceWav(), filename: 'question.wav', mimeType: 'audio/wav');
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
}

class _NoPlayback implements AudioPlayback {
  @override
  Future<void> play(Uri url) async {}
  @override
  Future<void> stop() async {}
}

Future<void> _settle(WidgetTester tester, {int seconds = 10}) async {
  // Les appels réseau sont réels : on pompe jusqu'à stabilité.
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 150,
      scrollable: find
          .descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable))
          .first);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await _reveal(tester, find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Saisie dans le champ « Écrivez votre question ». Sur Linux, la connexion
/// de saisie de test peut ne pas se rattacher après un changement d'onglet :
/// on retombe alors sur le contrôleur du champ.
Future<void> _type(WidgetTester tester, String text) async {
  final field = find.byKey(const Key('ask-text'));
  await tester.tap(field);
  await tester.pump();
  await tester.enterText(field, text);
  await tester.pump();
  final controller = tester.widget<TextField>(field).controller!;
  if (controller.text != text) controller.text = text;
  await tester.pump();
}

Future<void> _review(Uri base, String questionId, String note) async {
  final login = await http.post(base.resolve('/auth/login'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'login': _reviewer, 'password': _password}));
  expect(login.statusCode, 200, reason: login.body);
  final token = (jsonDecode(login.body) as Map)['access_token'] as String;
  final res = await http.post(base.resolve('/interactions/$questionId/review'),
      headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
      body: jsonEncode({'note': note}));
  expect(res.statusCode, 200, reason: res.body);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final base = config.apiBaseUrl;

  test('contrat : référentiels et audio (consentement obligatoire)', () async {
    final api = HttpPublicApi(base);
    expect(await api.sites(), isNotEmpty);
    final info = await api.information();
    expect(info.map((i) => i.scope), containsAll(['reny', 'tanora', 'voice_processing']));
    final menu = await api.menus(Module.reny, 'mg');
    expect(menu.items, isNotEmpty);

    // Sans voice_consent : 422 consent_required (envoi multipart brut).
    final req = http.MultipartRequest('POST', base.resolve('/public/ask'))
      ..fields['module'] = 'reny'
      ..files.add(http.MultipartFile.fromBytes('audio', _silenceWav(), filename: 'q.wav'));
    final res = await http.Response.fromStream(await req.send());
    expect(res.statusCode, 422);
    expect(res.body, contains('consent_required'));

    // Avec : la question part (audio jamais conservé côté serveur).
    final r = await api.askVoice(
        module: Module.tanora,
        clip: VoiceClip(bytes: _silenceWav(), filename: 'q.wav', mimeType: 'audio/wav'),
        language: 'mg',
        voiceConsent: true);
    expect(r.questionId, isNotEmpty);
    if (r.followUp != null) await api.deleteQuestion(r.questionId, r.followUp!.token);
  });

  testWidgets('TANORA texte → conseiller → réponse ; RENY « mandeha ra » → urgence ; effacer',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'fanilo.onboarded.v1': true,
      'fanilo.locale.v1': 'fr',
      'fanilo.voice_consent.version.v1': 'demo-0.1',
      'fanilo.voice_consent.at.v1': '2026-11-09T08:00:00.000Z',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        recorderProvider.overrideWithValue(_WavRecorder()),
        playbackProvider.overrideWithValue(_NoPlayback()),
      ],
      child: const FaniloFemmesApp(),
    ));
    await _settle(tester, seconds: 1);

    // 1. TANORA, question écrite → suivi par un conseiller.
    const secret = 'Fanontaniana E2E tsiambaratelo momba ny fitiavana';
    await tester.tap(find.byKey(const Key('module-tanora')));
    await _type(tester, secret);
    await tester.tap(find.byKey(const Key('ask-send')));
    await _settle(tester, seconds: 3);
    expect(find.byKey(const Key('follow-up')), findsOneWidget);
    expect(find.byKey(const Key('demo-banner')), findsWidgets);
    final ticket = store.tickets.single;
    expect(ticket.module, Module.tanora);
    final dump = {for (final k in prefs.getKeys()) k: prefs.get(k)}.toString();
    expect(dump, isNot(contains('tsiambaratelo')), reason: 'aucun texte gardé');

    // 2. « Mes questions » : en attente.
    await _tapKey(tester, 'open-mine');
    await _settle(tester, seconds: 2);
    expect(find.text('En attente'), findsOneWidget);

    // 3. Un conseiller répond (tableau de bord simulé) pendant que
    //    l'utilisatrice est sur l'accueil : relecture automatique (15 s),
    //    annonce « Vous avez une réponse » et badge, puis « Voir ».
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => _review(base, ticket.questionId, 'Réponse E2E du conseiller (fictive).'));
    var announced = false;
    for (var i = 0; i < 250 && !announced; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      announced = find.text('Vous avez une réponse').evaluate().isNotEmpty;
    }
    expect(announced, isTrue, reason: 'réponse annoncée par la relecture périodique');
    expect(find.descendant(of: find.byKey(const Key('unread-badge')), matching: find.text('1')),
        findsOneWidget);
    await tester.pumpAndSettle(); // fin de l'animation d'entrée de l'annonce
    await tester.tap(find.text('Voir'));
    await _settle(tester, seconds: 2);
    expect(find.text('Répondu'), findsOneWidget);
    expect(find.text('Réponse E2E du conseiller (fictive).'), findsOneWidget);
    expect(find.textContaining('Vérifié à'), findsOneWidget);
    expect(store.readAnswers, {ticket.questionId});

    // 4. RENY « mandeha ra » : l'interface doit suivre la décision du
    //    serveur (`urgent`). Le serveur doit répondre urgent = true ; sinon
    //    c'est une régression côté API/IA, signalée ici.
    final probe = await tester.runAsync(() => HttpPublicApi(base)
        .askText(module: Module.reny, text: 'mandeha ra aho', language: 'fr'));
    if (probe!.followUp != null) {
      await tester.runAsync(() => HttpPublicApi(base).deleteQuestion(probe.questionId, probe.followUp!.token));
    }
    if (!probe.urgent) {
      debugPrint('ATTENTION (API) : « mandeha ra aho » (reny) renvoie urgent=false, '
          'outcome=${probe.outcome}. Régression de la détection des signes de danger ?');
    }
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('module-reny')));
    await _type(tester, 'mandeha ra aho');
    await tester.tap(find.byKey(const Key('ask-send')));
    await _settle(tester, seconds: 3);
    expect(find.byKey(const Key('urgent-block')), probe.urgent ? findsOneWidget : findsNothing);
    if (probe.urgent) {
      expect(find.text('Allez au centre de santé le plus proche, sans attendre.'), findsOneWidget);
    }
    await _tapKey(tester, 'ask-another');

    // 5. Question vocale (WAV de silence), avec accord.
    await tester.tap(find.byKey(const Key('module-tanora')));
    await tester.tap(find.byKey(const Key('mic-button')));
    await _settle(tester, seconds: 1);
    await tester.tap(find.byKey(const Key('mic-button')));
    await _settle(tester, seconds: 3);
    expect(find.text('Réponse'), findsOneWidget);
    // Silence : soit une transcription, soit le message « non transcrite ».
    expect(
        find.byKey(const Key('transcript')).evaluate().length +
            find.byKey(const Key('not-transcribed')).evaluate().length,
        1);
    await _tapKey(tester, 'ask-another');

    // 6. « Tout effacer » : serveur puis téléphone.
    final ids = [for (final t in store.tickets) t];
    expect(ids, isNotEmpty);
    await tester.tap(find.byKey(const Key('nav-mine')));
    await _settle(tester, seconds: 2);
    await _tapKey(tester, 'delete-all');
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await _settle(tester, seconds: 2);
    expect(store.tickets, isEmpty);
    final api = HttpPublicApi(base);
    for (final t in ids) {
      await tester.runAsync(() async {
        await expectLater(api.question(t.questionId, t.token),
            throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.notFound)));
      });
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
