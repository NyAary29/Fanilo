import 'dart:convert';

import 'package:fanilo_mobile/data/auth/auth_repository.dart';
import 'package:fanilo_mobile/data/local/database.dart';
import 'package:fanilo_mobile/data/local/entity_store.dart';
import 'package:fanilo_mobile/data/reference/reference_repository.dart';
import 'package:fanilo_mobile/data/secure/secure_store.dart';
import 'package:fanilo_mobile/domain/enums.dart';
import 'package:fanilo_mobile/l10n/gen/app_localizations.dart';
import 'package:fanilo_mobile/ui/app.dart';
import 'package:fanilo_mobile/ui/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Environnement d'interface pour les tests de widgets : base en mémoire,
/// serveur et API factices, session restaurée.
class UiEnv {
  UiEnv({bool online = false, this.today})
      : db = newTestDb(),
        store = InMemorySecureStore(),
        network = FakeNetwork(online: online),
        server = FakeSyncServer(),
        interactions = FakeInteractionApi(),
        references = FakeReferenceApi(),
        authApi = FakeAuthApi();

  final AppDatabase db;
  final InMemorySecureStore store;
  final FakeNetwork network;
  final FakeSyncServer server;
  final FakeInteractionApi interactions;
  final FakeReferenceApi references;
  final FakeAuthApi authApi;

  /// Date du jour imposée (`YYYY-MM-DD`), sinon la vraie.
  final String? today;
  late final AuthRepository auth = AuthRepository(authApi, store);

  /// Session « déjà connectée » (restaurée depuis le stockage sécurisé).
  Future<void> signIn() async {
    store.values[AuthRepository.kUser] = jsonEncode(testUser.toJson());
    store.values[AuthRepository.kRefresh] = 'refresh-0';
    await auth.restore();
  }

  /// Copie locale des référentiels, comme après une première synchro.
  Future<void> cacheReferences(WidgetTester tester, {bool contents = false}) async {
    await tester.runAsync(() async {
      final repo = ReferenceRepository(db, references);
      await repo.refresh(force: true);
      if (contents) await repo.refreshContents(force: true);
    });
  }

  Future<void> seed(WidgetTester tester, Future<void> Function(EntityStore store) body) =>
      tester.runAsync(() => body(EntityStore(db)));

  Widget wrap(Widget child, {Key? boundaryKey}) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureStoreProvider.overrideWithValue(store),
          networkSourceProvider.overrideWithValue(network),
          syncApiProvider.overrideWithValue(server),
          interactionApiProvider.overrideWithValue(interactions),
          referenceApiProvider.overrideWithValue(references),
          authProvider.overrideWith((ref) => auth),
          if (today != null) todayProvider.overrideWithValue(today!),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
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
        ),
      );

  /// Laisse les flux drift se propager.
  Future<void> settle(WidgetTester tester, {int ms = 50}) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await db.close();
  }
}

/// Patiente fictive (comme reçue du serveur) : bénéficiaire, identité,
/// consentement RENY, et éventuellement grossesse et CPN.
Future<void> seedPatient(
  EntityStore store, {
  required String id,
  required String name,
  String? code,
  int? birthYear,
  String? siteId = 'site-demo-1',
  bool consent = true,
  String? lmpDate,
  bool pregnancy = true,
  List<(int, String, String)> visits = const [],
  String? openAlertId,
}) async {
  await store.applyServer(SyncEntity.beneficiary, id, 1, null, {
    'code': code ?? 'FAN-${id.toUpperCase().padLeft(6, '0')}',
    'site_id': siteId,
    'birth_year': birthYear,
    'preferred_channel': 'ac_visit',
  });
  await store.applyServer(SyncEntity.beneficiaryIdentity, id, 1, null, {
    'beneficiary_id': id,
    'display_name': name,
    'phone': null,
    'village': 'Village fictif',
  });
  if (consent) {
    await store.applyServer(SyncEntity.consent, 'c-$id', 1, null, {
      'beneficiary_id': id,
      'scope': 'reny',
      'method': 'oral',
      'information_version': 'demo-0.1',
      'collected_at': '2026-09-01T08:00:00Z',
    });
  }
  if (pregnancy) {
    await store.applyServer(SyncEntity.pregnancy, 'p-$id', 1, null, {
      'beneficiary_id': id,
      'status': 'active',
      'lmp_date': lmpDate,
      'estimated_due_date': null,
      'dates_confirmed_by': 'ac_declared',
      'created_at': '2026-09-01T08:00:00Z',
    });
    for (final (seq, date, status) in visits) {
      await store.applyServer(SyncEntity.ancVisit, 'v-$id-$seq', 1, null, {
        'pregnancy_id': 'p-$id',
        'sequence': seq,
        'scheduled_date': date,
        'status': status,
        'done_date': status == 'done' ? date : null,
        'site_id': siteId,
      });
    }
  }
  if (openAlertId != null) {
    await store.applyServer(SyncEntity.alert, openAlertId, 1, null, {
      'beneficiary_id': id,
      'rule_id': 'DEMO_RULE_01',
      'ruleset_version': '0.1.0',
      'severity': 'urgent',
      'status': 'open',
      'due_at': '2026-11-09T12:00:00Z',
      'is_demo': true,
      'created_at': '2026-11-09T07:45:00Z',
    });
  }
}
