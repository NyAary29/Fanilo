import 'package:fanilo_mobile/data/local/database.dart';
import 'package:fanilo_mobile/data/local/entity_store.dart';
import 'package:fanilo_mobile/domain/enums.dart';
import 'package:fanilo_mobile/ui/screens/beneficiary_detail_screen.dart';
import 'package:fanilo_mobile/ui/screens/home_screen.dart';
import 'package:fanilo_mobile/ui/screens/referrals_screen.dart';
import 'package:fanilo_mobile/ui/screens/registration_screen.dart';
import 'package:fanilo_mobile/ui/screens/signs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_env.dart';

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('enregistrement : identité inaccessible tant que le consentement est incomplet',
      (tester) async {
    _tallView(tester);
    final env = UiEnv();
    await env.signIn();
    await env.cacheReferences(tester);
    await tester.pumpWidget(env.wrap(const RegistrationScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('consent-step')), findsOneWidget);
    // Information servie par l'API (copie locale) : résumé, version, DÉMO.
    expect(find.byKey(const Key('demo-banner')), findsOneWidget);
    expect(find.textContaining('[DÉMO] Information fictive (reny).'), findsOneWidget);
    expect(find.textContaining('Information version demo-0.1'), findsNWidgets(4));
    expect(find.byKey(const Key('name-field')), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const Key('consent-next')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consent-required')), findsOneWidget);
    FilledButton next() =>
        tester.widget<FilledButton>(find.byKey(const Key('consent-next')));
    expect(next().onPressed, isNull);

    await tester.tap(find.text('Orale'));
    await tester.pump();
    expect(next().onPressed, isNull, reason: 'information non confirmée');

    await tester.tap(find.byKey(const Key('info-presented')));
    await tester.pump();
    expect(next().onPressed, isNotNull);
    expect(find.byKey(const Key('consent-required')), findsNothing);

    await tester.tap(find.byKey(const Key('consent-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('identity-step')), findsOneWidget);
    expect(find.text('Identité (confidentielle)'), findsOneWidget);
    expect(find.byKey(const Key('disclaimer')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('name-field')), 'Personne fictive');
    await tester.tap(find.byKey(const Key('save-registration')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    final rows = await tester.runAsync(() => env.db.select(env.db.beneficiaryIdentities).get());
    expect(rows!.single.displayName, 'Personne fictive');
    final consents = await tester.runAsync(() => env.db.select(env.db.consents).get());
    expect(consents!.single.method, 'oral');
    expect(consents.single.informationVersion, 'demo-0.1');

    await env.dispose(tester);
  });

  testWidgets('signes hors ligne : bandeau DÉMO, message CSB, aucun envoi', (tester) async {
    _tallView(tester);
    final env = UiEnv(online: false);
    await env.signIn();
    await env.cacheReferences(tester);
    env.references.offline = true;
    await tester.pumpWidget(env.wrap(const SignsScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo-banner')), findsOneWidget);
    expect(find.textContaining('Signe fictif n° 1'), findsOneWidget,
        reason: 'liste servie par l\'API, lue depuis la copie locale');
    expect(find.byKey(const Key('signs-offline')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign-SIGN_DEMO_01')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('signs-send')));
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byKey(const Key('signs-message')),
            matching: find.textContaining('Contactez directement le CSB'),
            matchRoot: true),
        findsOneWidget);
    expect(env.interactions.calls, isEmpty);
    await env.dispose(tester);
  });

  testWidgets('signes en ligne : orientation affichée, jamais de diagnostic', (tester) async {
    _tallView(tester);
    final env = UiEnv(online: true);
    await env.signIn();
    await tester.pumpWidget(env.wrap(const SignsScreen()));
    // En ligne : le référentiel est récupéré à l'ouverture de l'écran.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(env.references.calls, contains('sign-codes:reny'));

    await tester.tap(find.byKey(const Key('signs-send')));
    await tester.pump();
    expect(find.text('Cochez au moins un signe.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign-SIGN_DEMO_02')));
    await tester.tap(find.byKey(const Key('sign-SIGN_DEMO_01')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('signs-send')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(env.interactions.calls, [
      ['SIGN_DEMO_01', 'SIGN_DEMO_02']
    ]);
    expect(find.byKey(const Key('signs-result')), findsOneWidget);
    expect(find.text('Orienter vers le CSB'), findsOneWidget);
    expect(find.text('Alerte transmise. En attente d\'accusé de réception.'), findsOneWidget);
    expect(find.text('Urgente'), findsNothing, reason: 'pas de sévérité ni de diagnostic');
    await env.dispose(tester);
  });

  testWidgets('accueil : indicateur de synchro, éléments en attente, mention permanente',
      (tester) async {
    _tallView(tester);
    final env = UiEnv(online: false);
    await env.signIn();
    await tester.runAsync(() => env.db.into(env.db.outbox).insert(OutboxCompanion.insert(
          changeId: '00000000-0000-4000-8000-000000000001',
          entity: 'referral',
          op: 'upsert',
          entityId: 'r-1',
          data: '{}',
          seq: 1,
          createdAt: DateTime.utc(2026, 11, 8),
        )));

    await tester.pumpWidget(env.wrap(const HomeScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.text('Hors ligne'), findsOneWidget);
    expect(find.text('1 modification en attente'), findsOneWidget);
    expect(find.text('Jamais synchronisé'), findsOneWidget);
    expect(find.byKey(const Key('sync-button')), findsOneWidget);
    expect(find.text('FANILO ne remplace pas un professionnel de santé.'), findsOneWidget);
    expect(env.server.pushCalls, isEmpty, reason: 'hors ligne : pas de synchro auto');

    await env.dispose(tester);
  });

  testWidgets('signes : sans copie du référentiel, aucune liste inventée', (tester) async {
    _tallView(tester);
    final env = UiEnv(online: false);
    await env.signIn();
    await tester.pumpWidget(env.wrap(const SignsScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('signs-catalog-missing')), findsOneWidget);
    expect(find.byKey(const Key('signs-send')), findsNothing);
    await env.dispose(tester);
  });

  testWidgets('enregistrement : sans information de consentement, rien n\'est possible',
      (tester) async {
    _tallView(tester);
    final env = UiEnv(online: false);
    await env.signIn();
    await tester.pumpWidget(env.wrap(const RegistrationScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('consent-info-missing')), findsOneWidget);
    expect(find.byKey(const Key('consent-next')), findsNothing);
    await env.dispose(tester);
  });

  testWidgets('nouvelle référence vers un site synchronisé', (tester) async {
    _tallView(tester);
    final env = UiEnv(online: false);
    await env.signIn();
    await tester.runAsync(() async {
      final store = EntityStore(env.db);
      await store.applyServer(SyncEntity.site, 'site-csb', 1, null, {
        'name': 'CSB II Démo Bongolava A',
        'kind': 'csb',
        'is_active': true,
      });
      await store.applyServer(SyncEntity.beneficiary, 'b-1', 1, null, {
        'code': 'FAN-000001',
        'site_id': 'site-demo-1',
        'preferred_channel': 'none',
      });
    });
    await tester.pumpWidget(env.wrap(const ReferralsScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-referral')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-referral')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('referral-error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('referral-beneficiary')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FAN-000001').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('referral-site')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSB II Démo Bongolava A · CSB').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-referral')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final rows = await tester.runAsync(() => env.db.select(env.db.referrals).get());
    final err = find.byKey(const Key('referral-error'));
    expect(err, findsNothing,
        reason: err.evaluate().isEmpty ? '' : tester.widget<Text>(err).data);
    expect(rows!.single.toSiteId, 'site-csb');
    expect(rows.single.status, 'proposed');
    expect(find.textContaining('Vers : CSB II Démo Bongolava A'), findsOneWidget);
    // Envoyée par l'outbox (le serveur factice est joignable ici).
    expect(env.server.versionOf('referral', rows.single.id), 1);
    expect(env.server.dataOf('referral', rows.single.id)!['status'], 'proposed');
    await env.dispose(tester);
  });

  testWidgets('grossesse sans dernières règles : message, puis saisie des dates', (tester) async {
    _tallView(tester);
    final env = UiEnv(online: false);
    env.server.offline = true;
    await env.signIn();
    await tester.runAsync(() async {
      final store = EntityStore(env.db);
      await store.applyServer(SyncEntity.beneficiary, 'b-1', 1, null,
          {'code': 'FAN-000001', 'site_id': 'site-demo-1', 'preferred_channel': 'none'});
      await store.applyServer(SyncEntity.consent, 'c-1', 1, null, {
        'beneficiary_id': 'b-1',
        'scope': 'reny',
        'method': 'oral',
        'information_version': 'demo-0.1',
        'collected_at': '2026-11-01T00:00:00Z',
      });
      await store.applyServer(SyncEntity.pregnancy, 'p-1', 2, null, {
        'beneficiary_id': 'b-1',
        'status': 'active',
        'lmp_date': null,
        'estimated_due_date': null,
        'dates_confirmed_by': 'ac_declared',
      });
    });
    await tester.pumpWidget(env.wrap(const BeneficiaryDetailScreen(beneficiaryId: 'b-1')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pas de calendrier CPN'), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit-pregnancy-dates-p-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lmp-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-pregnancy-dates')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    final p = await tester.runAsync(() => env.db.select(env.db.pregnancies).getSingle());
    final today = DateTime.now().toIso8601String().substring(0, 10);
    expect(p!.lmpDate, today);
    expect(p.estimatedDueDate, isNull);
    final out = await tester.runAsync(() => env.db.select(env.db.outbox).get());
    expect(out!.single.entity, 'pregnancy');
    expect(out.single.baseVersion, 2);
    expect(find.textContaining('Le calendrier arrivera'), findsOneWidget);
    await env.dispose(tester);
  });
}
