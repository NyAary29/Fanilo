import 'package:fanilo_mobile/domain/enums.dart';
import 'package:fanilo_mobile/ui/screens/alerts_screen.dart';
import 'package:fanilo_mobile/ui/screens/beneficiary_detail_screen.dart';
import 'package:fanilo_mobile/ui/screens/home_screen.dart';
import 'package:fanilo_mobile/ui/screens/visit_flow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_env.dart';

const _today = '2026-11-09';

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

Future<UiEnv> _env(WidgetTester tester, {bool online = false}) async {
  final env = UiEnv(online: online, today: _today);
  env.server.offline = true;
  await env.signIn();
  await env.cacheReferences(tester, contents: true);
  await env.seed(tester, (store) async {
    // À jour : prochaine CPN dans 7 jours.
    await seedPatient(store,
        id: 'b1',
        name: 'Fictive Ajour',
        lmpDate: '2026-08-05',
        visits: [(1, '2026-10-01', 'done'), (2, '2026-11-16', 'planned')]);
    // À suivre : CPN 2 en retard.
    await seedPatient(store,
        id: 'b2',
        name: 'Fictive Retard',
        lmpDate: '2026-04-01',
        visits: [(1, '2026-09-01', 'done'), (2, '2026-11-02', 'planned'), (3, '2026-12-01', 'planned')]);
    // À suivre : alerte ouverte.
    await seedPatient(store, id: 'b3', name: 'Fictive Alerte', openAlertId: 'a-3');
    // Sans consentement RENY ni grossesse.
    await seedPatient(store,
        id: 'b4', name: 'Fictive Sansaccord', consent: false, pregnancy: false);
  });
  return env;
}

Finder _chipOf(String id, String key) =>
    find.descendant(of: find.byKey(Key('patient-$id')), matching: find.byKey(Key(key)));

void main() {
  testWidgets('accueil : pastilles « À jour » / « À suivre » et raison du suivi',
      (tester) async {
    _tallView(tester);
    final env = await _env(tester);
    await tester.pumpWidget(env.wrap(const HomeScreen()));
    await env.settle(tester);

    expect(_chipOf('b1', 'chip-up-to-date'), findsOneWidget);
    expect(_chipOf('b2', 'chip-to-follow'), findsOneWidget);
    expect(_chipOf('b3', 'chip-to-follow'), findsOneWidget);
    expect(_chipOf('b4', 'chip-up-to-date'), findsOneWidget);
    expect(find.text('CPN 2 en retard (2 nov. 2026)'), findsOneWidget);
    expect(find.text('Alerte en attente d\'accusé de réception'), findsOneWidget);
    expect(find.text('Grossesse · 3 mois'), findsOneWidget);
    expect(find.text('Pas de grossesse déclarée'), findsOneWidget);
    expect(find.text('2 patientes à suivre'), findsOneWidget);

    // Recherche.
    await tester.enterText(find.byKey(const Key('patient-search')), 'retard');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('patient-b2')), findsOneWidget);
    expect(find.byKey(const Key('patient-b1')), findsNothing);

    // « Visite du jour » ouvre l'onglet « Mes visites ».
    await tester.tap(find.byKey(const Key('action-today-visit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('visits-list')), findsOneWidget);
    expect(find.byKey(const Key('start-visit-b2')), findsOneWidget);
    expect(find.byKey(const Key('start-visit-b3')), findsOneWidget);
    expect(find.textContaining('CPN 2 : dans 7 jours (16 nov. 2026)'), findsOneWidget);
    await env.dispose(tester);
  });

  testWidgets('visite du jour : étapes, CPN en retard marquée réalisée (outbox)',
      (tester) async {
    _tallView(tester);
    final env = await _env(tester);
    await tester.pumpWidget(env.wrap(const HomeScreen()));
    await env.settle(tester);
    await tester.tap(find.byKey(const Key('nav-visits')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-visit-b2')));
    await env.settle(tester);
    expect(find.byKey(const Key('visit-flow')), findsOneWidget);

    // Rien n'est possible avant l'étape 1.
    FilledButton done() => tester.widget<FilledButton>(find.byKey(const Key('visit-anc-done')));
    expect(done().onPressed, isNull);
    await tester.tap(find.byKey(const Key('visit-save')));
    await tester.pump();
    expect(find.text('Terminez les étapes 1 et 2.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('visit-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('danger-no')));
    await tester.pumpAndSettle();

    // Conseils : contenus publiés du module (français), DÉMO signalé.
    expect(find.byKey(const Key('advice-MSG_DEMO_INFO_ANC')), findsOneWidget);
    expect(find.text('[DÉMO] Consultations prénatales'), findsOneWidget);
    expect(find.textContaining('Ne doit pas apparaître'), findsNothing);
    expect(find.byKey(const Key('demo-banner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('advice-MSG_DEMO_INFO_ANC')));
    await tester.pumpAndSettle();

    // Prochain RDV : CPN du serveur, en retard.
    expect(find.text('CPN 2 : en retard de 7 jours (2 nov. 2026)'), findsOneWidget);
    expect(find.text('CPN 3 : dans 22 jours (1 déc. 2026)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('visit-anc-done')));
    await env.settle(tester);

    final visit = await tester.runAsync(() => (env.db.select(env.db.ancVisits)
          ..where((v) => v.id.equals('v-b2-2')))
        .getSingle());
    expect(visit!.status, AncVisitStatus.done.wire);
    final out = await tester.runAsync(() => env.db.select(env.db.outbox).get());
    expect(out!.single.entity, 'anc_visit');
    expect(out.single.entityId, 'v-b2-2');
    // Plus de CPN en retard : la suivante devient le prochain rappel.
    expect(find.byKey(const Key('visit-anc-due')), findsNothing);
    expect(find.text('CPN 3 : dans 22 jours (1 déc. 2026)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('visit-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('visit-flow')), findsNothing);
    expect(find.textContaining('Visite terminée'), findsOneWidget);
    // Seule la CPN part au serveur : la liste de contrôle reste locale.
    final after = await tester.runAsync(() => env.db.select(env.db.outbox).get());
    expect(after!.map((o) => o.entity), ['anc_visit']);
    await env.dispose(tester);
  });

  testWidgets('visite du jour : sans consentement RENY, rien n\'est saisi', (tester) async {
    _tallView(tester);
    final env = await _env(tester);
    await tester.pumpWidget(env.wrap(const VisitFlowScreen(beneficiaryId: 'b4')));
    await env.settle(tester);

    expect(find.byKey(const Key('visit-no-consent')), findsOneWidget);
    expect(find.byKey(const Key('visit-confirm')), findsNothing);
    expect(find.text('Pas de grossesse en cours : pas de calendrier CPN.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('danger-no')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('visit-save')));
    await tester.pump();
    expect(find.text('Terminez les étapes 1 et 2.'), findsOneWidget);
    // Alerter le CSB reste toujours possible.
    expect(
        tester.widget<FilledButton>(find.byKey(const Key('visit-alert'))).onPressed, isNotNull);
    expect(await tester.runAsync(() => env.db.select(env.db.outbox).get()), isEmpty);
    await env.dispose(tester);
  });

  testWidgets('visite du jour : « Oui » ouvre le signalement ; hors ligne, appeler le CSB',
      (tester) async {
    _tallView(tester);
    final env = await _env(tester);
    await tester.pumpWidget(env.wrap(const VisitFlowScreen(beneficiaryId: 'b1')));
    await env.settle(tester);
    await tester.tap(find.byKey(const Key('visit-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('danger-yes')));
    await env.settle(tester);
    expect(find.byKey(const Key('signs-offline')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sign-SIGN_DEMO_01')));
    await tester.tap(find.byKey(const Key('signs-send')));
    await tester.pumpAndSettle();
    expect(env.interactions.calls, isEmpty, reason: 'jamais d\'envoi différé');
    Navigator.of(tester.element(find.byKey(const Key('signs-list')))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('visit-danger-status')), findsOneWidget);
    await env.dispose(tester);
  });

  testWidgets('visite du jour : signalement en ligne, orientation sans sévérité',
      (tester) async {
    _tallView(tester);
    final env = await _env(tester, online: true);
    await tester.pumpWidget(env.wrap(const VisitFlowScreen(beneficiaryId: 'b1')));
    await env.settle(tester);
    await tester.tap(find.byKey(const Key('visit-alert')));
    await env.settle(tester);
    await tester.tap(find.byKey(const Key('sign-SIGN_DEMO_01')));
    await tester.tap(find.byKey(const Key('signs-send')));
    await env.settle(tester);
    expect(env.interactions.calls, [
      ['SIGN_DEMO_01']
    ]);
    expect(find.text('Alerte transmise. En attente d\'accusé de réception.'), findsOneWidget);
    expect(find.text('Urgente'), findsNothing);
    Navigator.of(tester.element(find.byKey(const Key('signs-list')))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Signalement envoyé.'), findsOneWidget);
    await env.dispose(tester);
  });

  testWidgets('fiche : bandeau d\'alerte, prochain rappel, onglets ; jamais de sévérité',
      (tester) async {
    _tallView(tester);
    final env = await _env(tester);
    await tester.pumpWidget(env.wrap(const BeneficiaryDetailScreen(beneficiaryId: 'b3')));
    await env.settle(tester);
    expect(find.byKey(const Key('patient-alert-banner')), findsOneWidget);
    expect(find.textContaining('En attente d\'accusé de réception'), findsWidgets);
    await tester.tap(find.byKey(const Key('view-alert')));
    await env.settle(tester);
    expect(find.byKey(const Key('alert-a-3')), findsOneWidget);
    expect(find.text('Urgente'), findsNothing);
    expect(find.textContaining('urgent'), findsNothing);
    await tester.tap(find.byKey(const Key('tab-history')));
    await env.settle(tester);
    expect(find.text('Suivi de grossesse (RENY)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(env.wrap(const BeneficiaryDetailScreen(beneficiaryId: 'b1')));
    await env.settle(tester);
    expect(find.byKey(const Key('patient-alert-banner')), findsNothing);
    expect(find.text('CPN 2 : dans 7 jours (16 nov. 2026)'), findsOneWidget);
    expect(find.byKey(const Key('next-reminder')), findsOneWidget);
    await env.dispose(tester);
  });

  testWidgets('liste des alertes : statut et attente d\'accusé, sans sévérité', (tester) async {
    _tallView(tester);
    final env = await _env(tester);
    await tester.pumpWidget(env.wrap(const AlertsScreen()));
    await env.settle(tester);
    expect(find.text('Ouverte'), findsOneWidget);
    expect(find.text('En attente d\'accusé de réception.'), findsOneWidget);
    expect(find.text('Fictive Alerte'), findsOneWidget);
    expect(find.text('Urgente'), findsNothing);
    await env.dispose(tester);
  });
}
