import 'dart:convert';

import 'package:fanilo_mobile/data/local/database.dart';
import 'package:fanilo_mobile/data/local/entity_store.dart';
import 'package:fanilo_mobile/data/repositories/local_repository.dart';
import 'package:fanilo_mobile/data/repositories/outbox_repository.dart';
import 'package:fanilo_mobile/data/sync/sync_service.dart';
import 'package:fanilo_mobile/domain/enums.dart';
import 'package:fanilo_mobile/domain/registration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

RegistrationDraft _draft() => RegistrationDraft(
      consent: const ConsentInput(
        scopes: {ConsentScope.reny},
        method: ConsentMethod.oral,
        informationVersion: 'INFO-DEMO-0.1',
        informationPresented: true,
      ),
      identity: const IdentityInput(displayName: 'Personne fictive'),
      beneficiary: const BeneficiaryInput(
          birthYear: 2000, preferredChannel: PreferredChannel.sms),
    );

void main() {
  late AppDatabase db;
  late FakeSyncServer server;
  late OutboxRepository outbox;
  late LocalRepository repo;
  late SyncService sync;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 11, 8, 10);
    db = newTestDb();
    server = FakeSyncServer();
    outbox = OutboxRepository(db, now: () => now);
    repo = LocalRepository(db, outbox, now: () => now);
    sync = SyncService(db: db, api: server, now: () => now);
  });

  tearDown(() async {
    await sync.dispose();
    await db.close();
  });

  /// Référence connue des deux côtés en version [version].
  Future<String> seedReferral({int version = 1, String status = 'proposed'}) async {
    const id = '11111111-1111-4111-8111-111111111111';
    final data = {
      'beneficiary_id': 'b-1',
      'to_site_id': 'site-csb',
      'status': status,
    };
    server.seed('referral', id, version, data);
    await EntityStore(db).applyServer(SyncEntity.referral, id, version, null, data);
    return id;
  }

  group('push applied', () {
    test('vide l\'outbox, met à jour les versions et reçoit le code serveur', () async {
      final bId = await repo.registerBeneficiary(_draft(), testUser);
      expect((await outbox.all()).length, 3);

      final report = await sync.sync();

      expect(report.ok, isTrue, reason: report.toString());
      expect(report.applied, 3);
      expect(await outbox.all(), isEmpty);
      final b = await (db.select(db.beneficiaries)..where((t) => t.id.equals(bId))).getSingle();
      expect(b.version, 1);
      expect(b.code, startsWith('FAN-'));
      final c = await db.select(db.consents).getSingle();
      expect(c.version, 1);
      expect(server.versionOf('beneficiary_identity', bId), 1);
      // Ordre d'envoi : bénéficiaire, consentement, identité.
      expect(server.pushCalls.first.map((c) => c.entity).toList(),
          ['beneficiary', 'consent', 'beneficiary_identity']);
      expect(server.pushCalls.first.first.baseVersion, isNull);
      expect(await db.readState(SyncStateKeys.lastSyncAt), isNotNull);
    });

    test('deux modifications de la même entité : la seconde est rebasée', () async {
      final id = await seedReferral();
      await repo.transitionReferral(id, ReferralStatus.accepted);
      server.offline = true;
      await sync.sync();
      server.offline = false;
      // La première entrée a été tentée : la seconde ne fusionne pas.
      await repo.transitionReferral(id, ReferralStatus.arrived);
      expect((await outbox.all()).length, 2);

      final report = await sync.sync(force: true);

      expect(report.ok, isTrue, reason: report.toString());
      expect(report.conflicts, 0);
      expect(server.versionOf('referral', id), 3);
      expect(server.dataOf('referral', id)!['status'], 'arrived');
      expect(await outbox.all(), isEmpty);
      final local = await db.select(db.referrals).getSingle();
      expect(local.version, 3);
    });
  });

  group('push conflict', () {
    test('la version serveur s\'applique, la modification locale est conservée', () async {
      final id = await seedReferral(version: 2);
      // Quelqu'un d'autre a modifié la référence côté serveur (v3).
      server.seed('referral', id, 3,
          {'beneficiary_id': 'b-1', 'to_site_id': 'site-csb', 'status': 'accepted'});
      await repo.transitionReferral(id, ReferralStatus.notCompleted,
          reason: 'Motif fictif');

      final report = await sync.sync();

      expect(report.conflicts, 1);
      expect(await outbox.all(), isEmpty);
      final local = await db.select(db.referrals).getSingle();
      expect(local.status, 'accepted');
      expect(local.version, 3);
      final conflicts = await db.select(db.syncConflicts).get();
      expect(conflicts, hasLength(1));
      final kept = jsonDecode(conflicts.single.localData) as Map;
      expect(kept['status'], 'not_completed');
      expect(kept['reason'], 'Motif fictif');
      expect(conflicts.single.serverVersion, 3);
      expect(conflicts.single.resolvedAt, isNull);
    });

    test('renvoyer ma version : nouvelle entrée basée sur la version serveur', () async {
      final id = await seedReferral(version: 2);
      server.seed('referral', id, 3,
          {'beneficiary_id': 'b-1', 'to_site_id': 'site-csb', 'status': 'proposed'});
      await repo.transitionReferral(id, ReferralStatus.accepted);
      await sync.sync();
      final conflict = await db.select(db.syncConflicts).getSingle();

      await repo.reapplyLocal(conflict.id);
      final entry = (await outbox.all()).single;
      expect(entry.baseVersion, 3);
      final report = await sync.sync();

      expect(report.applied, 1);
      expect(server.dataOf('referral', id)!['status'], 'accepted');
      final resolved = await db.select(db.syncConflicts).getSingle();
      expect(resolved.resolution, 'reapplied');
    });
  });

  group('push rejected', () {
    test('l\'entrée reste avec l\'erreur, les autres passent', () async {
      server.rejectRule = (c) => c.entity == 'consent' ? 'information_version inconnue' : null;
      await repo.registerBeneficiary(_draft(), testUser);

      final report = await sync.sync();

      expect(report.applied, 2);
      expect(report.rejected, 1);
      final rows = await outbox.all();
      expect(rows, hasLength(1));
      expect(rows.single.status, OutboxStatus.rejected.wire);
      expect(rows.single.lastError, 'information_version inconnue');
      // Une entrée refusée n'est pas renvoyée automatiquement.
      server.pushCalls.clear();
      await sync.sync(force: true);
      expect(server.pushCalls, isEmpty);
    });

    test('réessayer attribue un nouveau change_id', () async {
      server.rejectRule = (c) => 'refus temporaire';
      final id = await seedReferral();
      await repo.transitionReferral(id, ReferralStatus.accepted);
      await sync.sync();
      final rejected = (await outbox.all()).single;

      server.rejectRule = null;
      final newId = await outbox.retry(rejected.changeId);
      expect(newId, isNot(rejected.changeId));
      final report = await sync.sync();
      expect(report.applied, 1);
      expect(await outbox.all(), isEmpty);
    });
  });

  group('idempotence et backoff', () {
    test('réponse perdue : le même change_id est renvoyé sans double application', () async {
      final id = await seedReferral();
      await repo.transitionReferral(id, ReferralStatus.accepted);
      final changeId = (await outbox.all()).single.changeId;

      server.loseNextResponse = true;
      final first = await sync.sync();
      expect(first.error, SyncErrorCode.offline);
      final pending = (await outbox.all()).single;
      expect(pending.changeId, changeId);
      expect(pending.attempts, 1);
      expect(server.applyCount['referral/$id'], 1);

      final second = await sync.sync(force: true);

      expect(second.ok, isTrue, reason: second.toString());
      expect(second.applied, 1);
      expect(server.pushCalls.last.single.changeId, changeId);
      expect(server.applyCount['referral/$id'], 1, reason: 'jamais appliqué deux fois');
      expect(server.versionOf('referral', id), 2);
      expect(await outbox.all(), isEmpty);
      expect(await db.select(db.syncConflicts).get(), isEmpty);
    });

    test('backoff exponentiel respecté hors déclenchement forcé', () async {
      final id = await seedReferral();
      await repo.transitionReferral(id, ReferralStatus.accepted);
      server.offline = true;

      await sync.sync();
      var row = (await outbox.all()).single;
      expect(row.attempts, 1);
      expect(row.nextAttemptAt!.toUtc(), now.add(const Duration(seconds: 5)));
      expect(row.lastError, contains('hors ligne'));

      await sync.sync(force: true);
      row = (await outbox.all()).single;
      expect(row.attempts, 2);
      expect(row.nextAttemptAt!.toUtc(), now.add(const Duration(seconds: 10)));

      server.offline = false;
      server.pushCalls.clear();
      await sync.sync(); // automatique : encore en attente de backoff
      expect(server.pushCalls, isEmpty);
      expect((await outbox.all()), hasLength(1));

      now = now.add(const Duration(seconds: 11));
      await sync.sync();
      expect(server.pushCalls, hasLength(1));
      expect(await outbox.all(), isEmpty);
    });

    test('BackoffPolicy plafonne le délai', () {
      const p = BackoffPolicy();
      expect(p.delayFor(1), const Duration(seconds: 5));
      expect(p.delayFor(3), const Duration(seconds: 20));
      expect(p.delayFor(50), const Duration(minutes: 30));
    });

    test('appels concurrents : une seule exécution', () async {
      await repo.registerBeneficiary(_draft(), testUser);
      final results = await Future.wait([sync.sync(), sync.sync()]);
      expect(identical(results[0], results[1]), isTrue);
      expect(server.pushCalls, hasLength(1));
    });
  });

  group('pull et curseur', () {
    test('pagine, enregistre le curseur et reprend depuis celui-ci', () async {
      server.seed('beneficiary', 'b-1', 1, {'code': 'FAN-000001', 'preferred_channel': 'sms'});
      server.seed('pregnancy', 'p-1', 1, {'beneficiary_id': 'b-1', 'status': 'active'});
      server.seed('anc_visit', 'v-1', 1, {
        'pregnancy_id': 'p-1',
        'sequence': 1,
        'scheduled_date': '2026-11-10',
        'status': 'planned'
      });
      server.seed('alert', 'a-1', 1, {
        'beneficiary_id': 'b-1',
        'severity': 'urgent',
        'status': 'open',
        'is_demo': true
      });
      server.seed('entite_inconnue', 'x-1', 1, {'foo': 'bar'});
      final paged = SyncService(db: db, api: server, pullLimit: 2, now: () => now);

      final report = await paged.sync();

      expect(report.ok, isTrue, reason: report.toString());
      expect(server.pullSinceCalls, [null, '2', '4']);
      expect(await db.readState(SyncStateKeys.cursor), '5');
      expect(report.pulled, 4, reason: 'l\'entité inconnue est ignorée');
      expect((await db.select(db.ancVisits).getSingle()).scheduledDate, '2026-11-10');
      expect((await db.select(db.alerts).getSingle()).severity, 'urgent');

      server.pullSinceCalls.clear();
      await paged.sync();
      expect(server.pullSinceCalls, ['5']);
      await paged.dispose();
    });

    test('suppression logique reçue par pull', () async {
      server.seed('beneficiary', 'b-1', 1, {'code': 'FAN-000001'});
      await sync.sync();
      server.seed('beneficiary', 'b-1', 2, {'code': 'FAN-000001', 'deleted_at': '2026-11-08T09:00:00Z'});
      await sync.sync();
      final b = await db.select(db.beneficiaries).getSingle();
      expect(b.version, 2);
      expect(b.deletedAt, isNotNull);
    });

    test('un pull n\'écrase pas une modification locale en attente', () async {
      final id = await seedReferral();
      await repo.transitionReferral(id, ReferralStatus.accepted);
      server.offline = true;
      await sync.sync();
      server.offline = false;
      // Le push échoue de nouveau (backoff) mais le pull passe.
      server.seed('referral', id, 2,
          {'beneficiary_id': 'b-1', 'to_site_id': 'site-csb', 'status': 'not_completed'});
      final pullOnly = SyncService(db: db, api: server, now: () => now);
      await pullOnly.sync(); // backoff : pas de push, mais pull
      final local = await db.select(db.referrals).getSingle();
      expect(local.status, 'accepted', reason: 'la modification locale reste visible');
      await pullOnly.dispose();

      // Au push suivant : conflit, la version serveur gagne, la locale est gardée.
      final r = await sync.sync(force: true);
      expect(r.conflicts, 1);
      expect((await db.select(db.referrals).getSingle()).status, 'not_completed');
    });
  });

  test('donnée serveur malformée : erreur server, curseur inchangé', () async {
    server.seed('consent', 'c-1', 1, {'scope': 'reny'}); // beneficiary_id manquant
    final report = await sync.sync();
    expect(report.error, SyncErrorCode.server);
    expect(await db.readState(SyncStateKeys.cursor), isNull);
    expect(await db.select(db.consents).get(), isEmpty);
  });

  test('hors ligne : rapport offline, aucun curseur, données locales intactes', () async {
    server.offline = true;
    await repo.registerBeneficiary(_draft(), testUser);
    final report = await sync.sync();
    expect(report.error, SyncErrorCode.offline);
    expect(await db.readState(SyncStateKeys.cursor), isNull);
    expect(await db.readState(SyncStateKeys.lastSyncError), SyncErrorCode.offline);
    expect(await db.select(db.beneficiaries).get(), hasLength(1));
    expect(await outbox.all(), hasLength(3));
  });
}
