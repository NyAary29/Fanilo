// Captures d'écran (fausse API, contenus FICTIFS), pour revue visuelle.
// Ignoré sans `FANILO_SHOTS_DIR` :
//
//   flutter test test/screenshots \
//     --dart-define=FANILO_SHOTS_DIR=/chemin/sortie \
//     --dart-define=FANILO_FONTS_DIR=$FLUTTER_ROOT/bin/cache/artifacts/material_fonts
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fanilo_femmes/data/api/models.dart';
import 'package:fanilo_femmes/data/api/public_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/env.dart';

const _dir = String.fromEnvironment('FANILO_SHOTS_DIR');
const _fonts = String.fromEnvironment('FANILO_FONTS_DIR');

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$_fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
    'Roboto-Italic.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_dir).createSync(recursive: true);
    File('$_dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget _wrap(Widget app) => RepaintBoundary(key: const Key('shot'), child: app);

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Retour').last);
  await tester.pumpAndSettle();
}

Future<void> _ask(WidgetTester tester, String module, String text) async {
  await _tap(tester, 'module-$module');
  await tester.enterText(find.byKey(const Key('ask-text')), text);
  FocusManager.instance.primaryFocus?.unfocus();
  await _tap(tester, 'ask-send');
}

void main() {
  setUpAll(() async {
    if (_dir.isNotEmpty) await _loadFonts();
  });

  testWidgets('captures', (tester) async {
    phone(tester);
    // Premier lancement (malagasy).
    var env = await TestEnv.create(onboarded: false, locale: 'mg');
    await tester.pumpWidget(_wrap(env.app()));
    await _shot(tester, '01-welcome-mg');
    await tester.scrollUntilVisible(find.byKey(const Key('welcome-continue')), 200);
    await _tap(tester, 'welcome-continue');
    await _shot(tester, '02-voice-consent-mg');
    await tester.scrollUntilVisible(find.byKey(const Key('voice-accept')), 200);
    await _tap(tester, 'voice-accept');
    await _shot(tester, '03-where-live-mg');
    await _tap(tester, 'site-site-1');
    await _shot(tester, '04-home-mg');
    await _tap(tester, 'module-reny');
    await _shot(tester, '05-home-reny-selected-mg');

    // Urgence (RENY « mandeha ra »).
    await tester.enterText(find.byKey(const Key('ask-text')), 'mandeha ra aho');
    FocusManager.instance.primaryFocus?.unfocus();
    await _tap(tester, 'ask-send');
    await _shot(tester, '06-answer-urgent-mg');
    await _back(tester);

    // TANORA → conseiller.
    await _ask(tester, 'tanora', 'fanontaniana momba ny fadimbolana');
    await _shot(tester, '07-answer-follow-up-mg');
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await _shot(tester, '08-answer-follow-up-bottom-mg');
    await tester.scrollUntilVisible(find.byKey(const Key('open-mine')), 100);
    await _tap(tester, 'open-mine');
    await _shot(tester, '09-my-questions-pending-mg');
    await _tap(tester, 'nav-home');
    for (final t in env.store.tickets) {
      env.api.answer(t.questionId, '[DÉMO] Réponse fictive du conseiller : allez au CSB.',
          orientation: const CareOrientation(
              name: 'CSB II Démo Bongolava A',
              kind: 'csb',
              district: 'Tsiroanomandidy',
              region: 'Bongolava'),
          triage: t.module.name == 'reny' ? 'urgent' : 'follow_up',
          code: t.module.name == 'reny' ? 'R4-17' : 'K7-42',
          visit: t.module.name == 'reny' ? 'came' : 'expected');
    }
    await tester.pump(const Duration(seconds: 16));
    await tester.pump(const Duration(milliseconds: 500));
    await _shot(tester, '10a-new-answer-snackbar-badge-mg');
    await _tap(tester, 'nav-mine');
    await _shot(tester, '10-my-questions-answered-mg');
    final mine = find.byKey(const Key('mine-list'));
    await tester.drag(mine, const Offset(0, -700));
    await _shot(tester, '10c-my-questions-code-mg');
    await tester.drag(mine, const Offset(0, -900));
    await _shot(tester, '10d-my-questions-urgent-came-mg');
    for (var i = 0; i < 4; i++) {
      await tester.drag(mine, const Offset(0, 500));
      await tester.pumpAndSettle();
    }
    env.api.failWith = const ApiException(ApiErrorKind.network);
    await _tap(tester, 'refresh-mine');
    await _shot(tester, '10b-my-questions-offline-mg');
    env.api.failWith = null;

    await _tap(tester, 'nav-info');
    await _shot(tester, '11-info-reny-mg');
    await _tap(tester, 'info-module-tanora');
    await _tap(tester, 'menu-1');
    await _shot(tester, '12-content-mg');
    await _back(tester);

    await _tap(tester, 'emergency-button');
    await _shot(tester, '13-emergency-mg');
    await _back(tester);
    await _tap(tester, 'settings-button');
    await _shot(tester, '14-settings-mg');
    await tester.pumpWidget(const SizedBox());

    // Français, sans accord pour la voix (micro verrouillé).
    env = await TestEnv.create(locale: 'fr');
    await tester.pumpWidget(_wrap(env.app()));
    await _shot(tester, '15-home-fr-no-voice-consent');
    await _tap(tester, 'mic-button');
    await _shot(tester, '16-voice-consent-sheet-fr');
    await _tap(tester, 'voice-accept');
    await _tap(tester, 'pick-tanora');
    await _tap(tester, 'mic-button');
    await _shot(tester, '17-voice-transcript-fr');
    await _back(tester);
    env.api.voiceTranscript = null;
    await _tap(tester, 'mic-button');
    await _tap(tester, 'mic-button');
    await _shot(tester, '18-voice-not-transcribed-fr');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }, skip: _dir.isEmpty);
}
