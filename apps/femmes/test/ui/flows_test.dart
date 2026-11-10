import 'package:fanilo_femmes/config/emergency.dart';
import 'package:fanilo_femmes/data/api/fake_public_api.dart';
import 'package:fanilo_femmes/data/api/models.dart';
import 'package:fanilo_femmes/data/api/public_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/env.dart';

Future<void> _ask(WidgetTester tester, {required String module, required String text}) async {
  await tester.tap(find.byKey(Key('module-$module')));
  await tester.pump();
  await tester.enterText(find.byKey(const Key('ask-text')), text);
  await tester.tap(find.byKey(const Key('ask-send')));
  await tester.pumpAndSettle();
}

/// Fait défiler la liste principale jusqu'à [finder] (listes paresseuses).
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 150,
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

/// Démonte l'application (minuteries de « Ny fanontaniako »).
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets('accueil en malagasy par défaut (repli Material en français)', (tester) async {
    phone(tester);
    final env = await TestEnv.create(locale: 'mg');
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    expect(find.text('Salama !'), findsOneWidget);
    expect(find.text('Tsindrio ary miteny'), findsOneWidget);
    expect(find.text('RENY'), findsOneWidget);
    expect(find.text('TANORA'), findsOneWidget);
    expect(find.text('Trano'), findsOneWidget);
    expect(find.text('Ny fanontaniako'), findsOneWidget);
    expect(find.byKey(const Key('emergency-button')), findsOneWidget);
    await _reveal(tester, find.byKey(const Key('disclaimer')));
    expect(find.byKey(const Key('disclaimer')), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('TANORA texte → suivi conseiller, bandeau DÉMO ; rien du texte sur le téléphone',
      (tester) async {
    phone(tester);
    final env = await TestEnv.create();
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    const secret = 'Fanontaniana tsiambaratelo momba ny fadimbolana';
    await _ask(tester, module: 'tanora', text: secret);

    expect(find.byKey(const Key('demo-banner')), findsWidgets);
    expect(find.byKey(const Key('follow-up')), findsOneWidget);
    expect(find.text('Votre question a été envoyée à un conseiller.'), findsOneWidget);
    expect(find.text('Vous trouverez la réponse dans « Mes questions ».'), findsOneWidget);
    expect(find.byKey(const Key('urgent-block')), findsNothing);
    await _reveal(tester, find.byKey(const Key('disclaimer')));
    expect(find.byKey(const Key('disclaimer')), findsOneWidget);

    final tickets = env.store.tickets;
    expect(tickets, hasLength(1));
    expect(tickets.single.module.name, 'tanora');
    // Confidentialité : ni la question ni la transcription ne sont gardées.
    expect(env.dump(), isNot(contains('tsiambaratelo')));
    expect(env.dump(), isNot(contains('fadimbolana')));
    expect(env.dump(), isNot(contains('[DÉMO]')));

    // Retour : le champ texte est vidé.
    await _tapKey(tester, 'ask-another');
    expect(find.text(secret), findsNothing);
    await _unmount(tester);
  });

  testWidgets('RENY « mandeha ra » → grand bloc rouge d\'urgence', (tester) async {
    phone(tester);
    final env = await TestEnv.create();
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await _ask(tester, module: 'reny', text: 'mandeha ra aho');
    expect(find.byKey(const Key('urgent-block')), findsOneWidget);
    expect(find.text('Allez au centre de santé le plus proche, sans attendre.'), findsOneWidget);
    expect(find.byKey(const Key('content-MSG_DEMO_REFER_CSB')), findsOneWidget);
    expect(find.byKey(const Key('demo-banner')), findsWidgets);
    await _reveal(tester, find.byKey(const Key('disclaimer')));
    expect(find.byKey(const Key('disclaimer')), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('réponse simple sans suivi : pas de ticket', (tester) async {
    phone(tester);
    final env = await TestEnv.create();
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await _ask(tester, module: 'reny', text: 'cpn inona');
    expect(find.byKey(const Key('content-MSG_DEMO_INFO_ANC')), findsOneWidget);
    expect(find.byKey(const Key('follow-up')), findsNothing);
    expect(env.store.tickets, isEmpty);
    await _unmount(tester);
  });

  testWidgets('sans module choisi : on demande RENY ou TANORA', (tester) async {
    phone(tester);
    final env = await TestEnv.create();
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ask-text')), 'fanontaniana');
    await tester.tap(find.byKey(const Key('ask-send')));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez d\'abord : RENY ou TANORA'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pick-tanora')));
    await tester.pumpAndSettle();
    expect(env.api.calls, contains('askText:tanora'));
    await _unmount(tester);
  });

  testWidgets('erreur 429 : message simple, rien de gardé', (tester) async {
    phone(tester);
    final env = await TestEnv.create();
    env.api.failWith = const ApiException(ApiErrorKind.rateLimited, statusCode: 429);
    await tester.pumpWidget(env.app());
    await tester.pump();
    await _ask(tester, module: 'tanora', text: 'x');
    expect(find.text('Trop de questions. Réessayez plus tard.'), findsOneWidget);
    expect(env.store.tickets, isEmpty);
    await _unmount(tester);
  });

  testWidgets('Mes questions : en attente → un conseiller répond → relecture → effacer',
      (tester) async {
    phone(tester);
    final env = await TestEnv.create();
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await _ask(tester, module: 'tanora', text: 'q1');
    await _tapKey(tester, 'open-mine');
    final id = env.store.tickets.single.questionId;

    expect(find.byKey(Key('ticket-$id')), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.byKey(Key('answer-$id')), findsNothing);
    expect(find.textContaining('Vérifié à'), findsOneWidget);

    env.api.answer(id, '[DÉMO] Réponse fictive du conseiller.');
    await tester.tap(find.byKey(const Key('refresh-mine')));
    await tester.pumpAndSettle();
    expect(find.text('Répondu'), findsOneWidget);
    expect(find.text('[DÉMO] Réponse fictive du conseiller.'), findsOneWidget);
    expect(find.byKey(Key('new-$id')), findsOneWidget);
    expect(find.byKey(Key('orientation-$id')), findsNothing, reason: 'pas d\'orientation');
    // Seul l'identifiant de la réponse lue est gardé, pas la réponse.
    expect(env.store.readAnswers, {id});
    expect(env.dump(), isNot(contains('Réponse fictive')));

    await tester.tap(find.byKey(Key('delete-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(env.api.calls, contains('delete:$id'));
    expect(env.api.questions, isEmpty);
    expect(env.store.tickets, isEmpty);
    expect(env.store.readAnswers, isEmpty);
    expect(find.byKey(const Key('mine-empty')), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('relecture toutes les 15 s au premier plan, badge et annonce « Vous avez une réponse »',
      (tester) async {
    phone(tester, height: 2600); // deux cartes répondues visibles
    final env = await TestEnv.create();
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await _ask(tester, module: 'tanora', text: 'a');
    await _tapKey(tester, 'ask-another');
    await _ask(tester, module: 'reny', text: 'mandeha ra');
    await _tapKey(tester, 'ask-another');
    expect(env.store.tickets, hasLength(2));
    expect(find.text('Vous avez une réponse'), findsNothing);

    // Les conseillers répondent pendant que l'utilisatrice est sur l'accueil.
    for (final t in env.store.tickets) {
      env.api.answer(t.questionId, 'Valiny ${t.module.name}',
          orientation: t.module == Module.reny
              ? const CareOrientation(name: 'CSB II Démo Bongolava A', kind: 'csb')
              : null,
          triage: t.module == Module.reny ? 'follow_up' : 'info',
          code: t.module == Module.reny ? 'B3-09' : null,
          visit: t.module == Module.reny ? 'no_show' : null);
    }
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('Vous avez une réponse'), findsOneWidget);
    expect(
        find.descendant(of: find.byKey(const Key('unread-badge')), matching: find.text('2')),
        findsOneWidget);

    // Ouvrir la liste : réponses lues, badge effacé.
    await tester.tap(find.byKey(const Key('nav-mine')));
    await tester.pumpAndSettle();
    expect(find.text('Répondu'), findsNWidgets(2));
    expect(find.text('Nouveau'), findsNWidgets(2));
    expect(find.text('CSB II Démo Bongolava A'), findsOneWidget);
    expect(find.text('Centre de santé'), findsOneWidget);
    expect(find.text('À suivre'), findsOneWidget);
    expect(find.text('Information'), findsOneWidget);
    expect(find.text('B3-09'), findsOneWidget, reason: 'un seul code (RENY)');
    expect(find.text("Vous n'êtes pas encore venue : allez-y si besoin"), findsOneWidget);
    expect(find.textContaining('Le centre vous attend'), findsNothing);
    expect(find.text('Vous avez une réponse'), findsNothing, reason: 'annonce retirée');
    expect(env.store.readAnswers, hasLength(2));
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsNothing);

    await tester.tap(find.byKey(const Key('nav-mine')));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'delete-all');
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(env.store.tickets, isEmpty);
    expect(env.api.questions, isEmpty);
    await _unmount(tester);
  });

  testWidgets('arrière-plan : pas de relecture ; retour au premier plan : relecture et annonce',
      (tester) async {
    phone(tester);
    final env = await TestEnv.create();
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await _ask(tester, module: 'tanora', text: 'a');
    await _tapKey(tester, 'ask-another');
    final id = env.store.tickets.single.questionId;

    for (final st in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    await tester.pump();
    final before = env.api.calls.where((c) => c.startsWith('question:')).length;
    env.api.answer(id, 'Mandehana any amin\'ny hopitaly.',
        orientation: const CareOrientation(
            name: 'CHRR Démo Bongolava',
            kind: 'reference_facility',
            district: 'Tsiroanomandidy',
            region: 'Bongolava'),
        triage: 'urgent',
        code: 'K7-42',
        visit: 'came');
    await tester.pump(const Duration(seconds: 40));
    expect(env.api.calls.where((c) => c.startsWith('question:')).length, before,
        reason: 'aucune relecture en arrière-plan');

    for (final st in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    await tester.pumpAndSettle();
    expect(env.api.calls.where((c) => c.startsWith('question:')).length, greaterThan(before));
    expect(find.text('Vous avez une réponse'), findsOneWidget);

    // « Voir » ouvre la liste.
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    expect(find.text('Répondu'), findsOneWidget);
    expect(find.text('Mandehana any amin\'ny hopitaly.'), findsOneWidget);
    expect(find.byKey(Key('orientation-$id')), findsOneWidget);
    expect(find.text('Allez à :'), findsOneWidget);
    expect(find.text('CHRR Démo Bongolava'), findsOneWidget);
    expect(find.text('Tsiroanomandidy · Bongolava'), findsOneWidget);
    expect(find.text('Hôpital de référence'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.byKey(Key('urgent-$id')), findsOneWidget);
    await _reveal(tester, find.byKey(Key('visit-$id')));
    expect(find.text('Montrez ce code au centre de santé'), findsOneWidget);
    expect(find.text('K7-42'), findsOneWidget);
    expect(find.text('Votre venue est enregistrée'), findsOneWidget);
    expect(env.store.readAnswers, {id});
    await _unmount(tester);
  });

  testWidgets('au démarrage : relecture des tickets gardés et annonce d\'une réponse reçue',
      (tester) async {
    phone(tester);
    final env = await TestEnv.create(extra: {
      'fanilo.tickets.v1':
          '[{"question_id":"q-old","token":"tok-old-0123456789","module":"reny","created_at":"2026-11-08T10:00:00.000Z"}]',
    });
    env.api.questions['q-old'] = FakeQuestion(module: Module.reny, token: 'tok-old-0123456789')
      ..answer = 'Valiny taloha';
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    expect(env.api.calls, contains('question:q-old'));
    expect(find.text('Vous avez une réponse'), findsOneWidget);
    expect(
        find.descendant(of: find.byKey(const Key('unread-badge')), matching: find.text('1')),
        findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('serveur injoignable : message explicite, « Réessayer », puis « Vérifié à »',
      (tester) async {
    phone(tester);
    final env = await TestEnv.create();
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await _ask(tester, module: 'tanora', text: 'a');
    await _tapKey(tester, 'ask-another');
    env.api.failWith = const ApiException(ApiErrorKind.network);
    await tester.tap(find.byKey(const Key('nav-mine')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('server-unreachable')), findsOneWidget);
    expect(find.text('Impossible de joindre le serveur'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget, reason: 'dernier état connu gardé');

    env.api.failWith = null;
    await tester.tap(find.byKey(const Key('retry-mine')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('server-unreachable')), findsNothing);
    expect(find.textContaining('Vérifié à'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('question effacée ailleurs (404) : « Introuvable »', (tester) async {
    phone(tester);
    final env = await TestEnv.create();
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await _ask(tester, module: 'tanora', text: 'a');
    env.api.questions.clear();
    await _tapKey(tester, 'open-mine');
    expect(find.text('Introuvable'), findsOneWidget);
    await _unmount(tester);
  });

  group('accord pour la voix', () {
    testWidgets('sans accord : le micro n\'enregistre pas ; le texte reste possible',
        (tester) async {
      phone(tester);
      final env = await TestEnv.create(voiceConsent: false);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mic-locked')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mic-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice-accept')), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice-decline')));
      await tester.pumpAndSettle();
      expect(env.recorder.permissionRequests, 0);
      expect(env.recorder.starts, 0);
      expect(env.store.voiceConsent, isNull);

      await _ask(tester, module: 'tanora', text: 'soratra');
      expect(env.api.calls, contains('askText:tanora'));
      await _unmount(tester);
    });

    testWidgets('accord → module → enregistrement → envoi avec voice_consent', (tester) async {
      phone(tester);
      final env = await TestEnv.create(voiceConsent: false);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mic-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voice-accept')));
      await tester.pumpAndSettle();
      expect(env.store.voiceConsent, isNotNull);
      await tester.tap(find.byKey(const Key('pick-reny')));
      await tester.pumpAndSettle();
      expect(env.recorder.permissionRequests, 1);
      expect(env.recorder.recording, isTrue);
      expect(find.textContaining('J\'écoute'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mic-button')));
      await tester.pumpAndSettle();
      expect(env.api.calls, contains('askVoice:reny:true'));
      expect(find.text('Est-ce bien ce que vous avez dit ?'), findsOneWidget);
      expect(find.text('« fanontaniana am-peo »'), findsOneWidget);
      // « Oui » : on garde l'écran, les boutons disparaissent.
      await tester.tap(find.byKey(const Key('transcript-yes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('transcript-no')), findsNothing);
      expect(find.byKey(const Key('voice-check')), findsOneWidget);
      await _reveal(tester, find.byKey(const Key('follow-up')));
      expect(find.byKey(const Key('follow-up')), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('voix non transcrite : on le dit, et la question part au conseiller',
        (tester) async {
      phone(tester);
      final env = await TestEnv.create(voiceConsent: true);
      env.api.voiceTranscript = null;
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('module-tanora')));
      await tester.tap(find.byKey(const Key('mic-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mic-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('not-transcribed')), findsOneWidget);
      expect(find.text("Votre voix n'a pas été bien comprise."), findsOneWidget);
      expect(find.textContaining('transmise à un conseiller. La réponse sera dans'), findsOneWidget);
      expect(find.byKey(const Key('transcript')), findsNothing);
      expect(env.store.tickets, hasLength(1));

      // « Réessayer » : retour au micro, l'enregistrement repart.
      expect(env.recorder.starts, 1);
      await tester.tap(find.byKey(const Key('voice-retry')));
      await tester.pumpAndSettle();
      expect(env.recorder.starts, 2);
      expect(env.recorder.recording, isTrue);
      await tester.tap(find.byKey(const Key('mic-button')));
      await tester.pumpAndSettle();

      // « Écrire la question » : champ texte vide et actif.
      await tester.tap(find.byKey(const Key('voice-write')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byKey(const Key('ask-text')));
      expect(field.controller!.text, isEmpty);
      expect(field.focusNode!.hasFocus, isTrue);
      await _unmount(tester);
    });

    testWidgets('« Non, je l\'écris » : question vocale retirée, texte prérempli, renvoi écrit',
        (tester) async {
      phone(tester);
      final env = await TestEnv.create(voiceConsent: true);
      env.api.voiceTranscript = 'mandeha ra be aho';
      env.api.voiceDelay = const Duration(seconds: 3);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('module-reny')));
      await tester.tap(find.byKey(const Key('mic-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mic-button')));
      await tester.pump(const Duration(milliseconds: 200));
      // Attente de la transcription : état clair.
      expect(find.text('Nous écoutons votre question…'), findsOneWidget);
      expect(find.byKey(const Key('voice-wait')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('« mandeha ra be aho »'), findsOneWidget);
      final first = env.store.tickets.single.questionId;
      await tester.tap(find.byKey(const Key('transcript-no')));
      await tester.pumpAndSettle();
      // La version vocale est effacée (serveur et téléphone).
      expect(env.api.calls, contains('delete:$first'));
      expect(env.api.questions.containsKey(first), isFalse);
      expect(env.store.tickets, isEmpty);
      // Retour à l'accueil, champ prérempli et actif.
      final field = tester.widget<TextField>(find.byKey(const Key('ask-text')));
      expect(field.controller!.text, 'mandeha ra be aho');
      expect(field.focusNode!.hasFocus, isTrue);

      // Correction puis renvoi comme question ÉCRITE.
      await tester.enterText(find.byKey(const Key('ask-text')), 'mandeha ra aho');
      await tester.tap(find.byKey(const Key('ask-send')));
      await tester.pumpAndSettle();
      expect(env.api.calls.where((c) => c.startsWith('ask')).last, 'askText:reny');
      expect(find.byKey(const Key('urgent-block')), findsOneWidget);
      expect(find.byKey(const Key('voice-check')), findsNothing);
      expect(env.store.tickets, hasLength(1));
      expect(env.store.tickets.single.questionId, isNot(first));
      await _unmount(tester);
    });

    testWidgets('micro refusé : message, rien n\'est envoyé', (tester) async {
      phone(tester);
      final env = await TestEnv.create(voiceConsent: true);
      env.recorder.permission = false;
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mic-locked')), findsNothing);
      await tester.tap(find.byKey(const Key('module-tanora')));
      await tester.tap(find.byKey(const Key('mic-button')));
      await tester.pumpAndSettle();
      expect(find.text('Micro refusé. Vous pouvez écrire votre question.'), findsOneWidget);
      expect(env.recorder.starts, 0);
      expect(env.api.calls.where((c) => c.startsWith('ask')), isEmpty);
      await _unmount(tester);
    });
  });

  testWidgets('premier lancement : information, voix refusée, lieu passé', (tester) async {
    phone(tester);
    final env = await TestEnv.create(onboarded: false);
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    expect(find.text('Pas de compte. Ni nom, ni numéro de téléphone.'), findsOneWidget);
    expect(find.text('Votre voix n\'est jamais conservée.'), findsOneWidget);
    expect(find.byKey(const Key('info-tanora')), findsOneWidget);
    await _tapKey(tester, 'welcome-continue');
    await _reveal(tester, find.byKey(const Key('info-voice_processing')));
    await _tapKey(tester, 'voice-decline');
    expect(find.text('Où habitez-vous ?'), findsOneWidget);
    expect(find.text('CSB II Démo Bongolava A'), findsOneWidget);
    await _tapKey(tester, 'site-skip');
    expect(find.text('Bonjour !'), findsOneWidget);
    expect(env.store.onboarded, isTrue);
    expect(env.store.voiceConsent, isNull);
    expect(env.store.site, isNull);
    await _unmount(tester);
  });

  testWidgets('premier lancement : voix acceptée, CSB choisi et envoyé avec la question',
      (tester) async {
    phone(tester);
    final env = await TestEnv.create(onboarded: false);
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await _tapKey(tester, 'welcome-continue');
    await _tapKey(tester, 'voice-accept');
    await tester.tap(find.byKey(const Key('site-site-2')));
    await tester.pumpAndSettle();
    expect(env.store.voiceConsent!.version, 'demo-0.1');
    expect(env.store.site!.id, 'site-2');
    expect(find.byKey(const Key('mic-locked')), findsNothing);
    await _unmount(tester);
  });

  testWidgets('Fampahalalana : menus numérotés → contenu', (tester) async {
    phone(tester);
    final env = await TestEnv.create();
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-info')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-1')), findsOneWidget);
    expect(find.byKey(const Key('demo-banner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('info-module-tanora')));
    await tester.pumpAndSettle();
    expect(env.api.calls, contains('menus:tanora:fr'));
    await tester.tap(find.byKey(const Key('menu-2')));
    await tester.pumpAndSettle();
    expect(find.text('[DÉMO] Parler à un conseiller'), findsOneWidget);
    await _reveal(tester, find.byKey(const Key('disclaimer')));
    expect(find.byKey(const Key('disclaimer')), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('Vonjy maika : consigne générique et procédure locale [À VALIDER]',
      (tester) async {
    phone(tester);
    final env = await TestEnv.create(extra: {
      'fanilo.site.id.v1': 'site-1',
      'fanilo.site.name.v1': 'CSB II Démo Bongolava A',
    });
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('emergency-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('urgent-block')), findsOneWidget);
    expect(find.text('Votre CSB : CSB II Démo Bongolava A'), findsOneWidget);
    expect(find.text('FANILO ne peut appeler personne. Personne n\'est prévenu.'), findsOneWidget);
    expect(kLocalEmergencyProcedure, startsWith('[À VALIDER]'));
    expect(find.text(kLocalEmergencyProcedure), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('réglages : changer de langue, retirer l\'accord pour la voix', (tester) async {
    phone(tester);
    final env = await TestEnv.create(voiceConsent: true);
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Malagasy'));
    await tester.pumpAndSettle();
    expect(env.store.locale, 'mg');
    await tester.tap(find.byKey(const Key('withdraw-consent')));
    await tester.pumpAndSettle();
    expect(env.store.voiceConsent, isNull);
    await _unmount(tester);
  });
}
