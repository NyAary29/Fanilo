import 'dart:convert';

import 'package:fanilo_mobile/data/auth/auth_repository.dart';
import 'package:fanilo_mobile/data/local/database.dart';
import 'package:fanilo_mobile/data/secure/secure_store.dart';
import 'package:fanilo_mobile/l10n/gen/app_localizations.dart';
import 'package:fanilo_mobile/ui/app.dart';
import 'package:fanilo_mobile/ui/providers.dart';
import 'package:fanilo_mobile/ui/screens/home_screen.dart';
import 'package:fanilo_mobile/ui/screens/registration_screen.dart';
import 'package:fanilo_mobile/ui/screens/signs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

class _Env {
  _Env({bool online = false})
      : db = newTestDb(),
        store = InMemorySecureStore(),
        network = FakeNetwork(online: online),
        server = FakeSyncServer(),
        interactions = FakeInteractionApi(),
        authApi = FakeAuthApi();

  final AppDatabase db;
  final InMemorySecureStore store;
  final FakeNetwork network;
  final FakeSyncServer server;
  final FakeInteractionApi interactions;
  final FakeAuthApi authApi;
  late final AuthRepository auth = AuthRepository(authApi, store);

  /// Session « déjà connectée » (restaurée depuis le stockage sécurisé).
  Future<void> signIn() async {
    store.values[AuthRepository.kUser] = jsonEncode(testUser.toJson());
    store.values[AuthRepository.kRefresh] = 'refresh-0';
    await auth.restore();
  }

  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureStoreProvider.overrideWithValue(store),
          networkSourceProvider.overrideWithValue(network),
          syncApiProvider.overrideWithValue(server),
          interactionApiProvider.overrideWithValue(interactions),
          authProvider.overrideWith((ref) => auth),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: child,
        ),
      );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await db.close();
  }
}

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('enregistrement : identité inaccessible tant que le consentement est incomplet',
      (tester) async {
    _tallView(tester);
    final env = _Env();
    await env.signIn();
    await tester.pumpWidget(env.wrap(const RegistrationScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('consent-step')), findsOneWidget);
    expect(find.byKey(const Key('name-field')), findsNothing);
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
    expect(consents.single.informationVersion, 'INFO-DEMO-0.1');

    await env.dispose(tester);
  });

  testWidgets('signes hors ligne : bandeau DÉMO, message CSB, aucun envoi', (tester) async {
    _tallView(tester);
    final env = _Env(online: false);
    await env.signIn();
    await tester.pumpWidget(env.wrap(const SignsScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo-banner')), findsOneWidget);
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
    final env = _Env(online: true);
    await env.signIn();
    await tester.pumpWidget(env.wrap(const SignsScreen()));
    await tester.pumpAndSettle();

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
    final env = _Env(online: false);
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
}
