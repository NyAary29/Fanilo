import 'dart:convert';
import 'package:drift/drift.dart' show Value;

import 'package:fanilo_mobile/data/local/database.dart';
import 'package:fanilo_mobile/data/repositories/local_repository.dart';
import 'package:fanilo_mobile/data/repositories/outbox_repository.dart';
import 'package:fanilo_mobile/data/sync/sync_service.dart';
import 'package:fanilo_mobile/domain/enums.dart';
import 'package:fanilo_mobile/domain/registration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeSyncServer server;
  late OutboxRepository outbox;
  late LocalRepository repo;
  late SyncService sync;
  final now = DateTime(2026, 11, 9, 10);

  Future<String> pregnancy({String? lmp}) async {
    final b = await repo.registerBeneficiary(
        RegistrationDraft(
          consent: const ConsentInput(
            scopes: {ConsentScope.reny},
            method: ConsentMethod.oral,
            informationVersions: {ConsentScope.reny: 'demo-0.1'},
            informationPresented: true,
          ),
          identity: const IdentityInput(displayName: 'Personne fictive'),
        ),
        testUser);
    return repo.createPregnancy(beneficiaryId: b, lmpDate: lmp);
  }

  setUp(() {
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

  test('dates renseignées après coup : upsert pregnancy basé sur la version serveur',
      () async {
    final id = await pregnancy();
    await sync.sync();
    expect(server.versionOf('pregnancy', id), 1);

    await repo.updatePregnancyDates(id,
        lmpDate: '2026-09-01',
        estimatedDueDate: null,
        confirmedBy: DatesConfirmedBy.healthWorker);

    final row = await (db.select(db.pregnancies)..where((p) => p.id.equals(id))).getSingle();
    expect(row.lmpDate, '2026-09-01');
    expect(row.estimatedDueDate, isNull, reason: 'jamais calculée par l\'application');
    expect(row.datesConfirmedBy, 'health_worker');
    final entry = (await outbox.all()).single;
    expect(entry.entity, 'pregnancy');
    expect(entry.baseVersion, 1);
    expect(jsonDecode(entry.data), containsPair('lmp_date', '2026-09-01'));

    // Le serveur génère le calendrier (simulé ici) ; le pull l'apporte.
    await sync.sync();
    expect(server.dataOf('pregnancy', id)!['lmp_date'], '2026-09-01');
    server.seed('anc_visit', 'v-1', 1, {
      'pregnancy_id': id,
      'sequence': 1,
      'scheduled_date': '2026-11-23',
      'status': 'planned',
    });
    await sync.sync();
    expect((await repo.watchAncVisits(id).first).single.sequence, 1);
  });

  test('avant tout envoi : fusion avec la création (une seule entrée)', () async {
    final id = await pregnancy();
    await repo.updatePregnancyDates(id,
        lmpDate: '2026-10-01',
        estimatedDueDate: '2027-07-08',
        confirmedBy: DatesConfirmedBy.ultrasound);
    final entries = (await outbox.all()).where((e) => e.entity == 'pregnancy').toList();
    expect(entries, hasLength(1));
    expect(entries.single.baseVersion, isNull);
    final data = jsonDecode(entries.single.data);
    expect(data['estimated_due_date'], '2027-07-08');
    expect(data['dates_confirmed_by'], 'ultrasound');
  });

  test('garde-fous de saisie identiques au serveur, rien n\'est écrit', () async {
    final id = await pregnancy();
    final before = (await outbox.all()).length;
    Future<void> expectError(String? lmp, String? due, PregnancyDatesError e) =>
        expectLater(
            repo.updatePregnancyDates(id,
                lmpDate: lmp, estimatedDueDate: due, confirmedBy: DatesConfirmedBy.acDeclared),
            throwsA(isA<InvalidPregnancyDatesException>()
                .having((x) => x.error, 'error', e)));
    await expectError('2026-11-10', null, PregnancyDatesError.lmpInFuture);
    await expectError('2025-12-01', null, PregnancyDatesError.lmpTooOld);
    await expectError('2026-09-01', '2026-09-01', PregnancyDatesError.dueBeforeLmp);
    expect((await outbox.all()).length, before);
    final row = await (db.select(db.pregnancies)..where((p) => p.id.equals(id))).getSingle();
    expect(row.lmpDate, isNull);
  });

  test('grossesse non active : modification refusée', () async {
    final id = await pregnancy();
    await (db.update(db.pregnancies)..where((p) => p.id.equals(id)))
        .write(const PregnanciesCompanion(status: Value('delivered')));
    await expectLater(
        repo.updatePregnancyDates(id,
            lmpDate: '2026-09-01',
            estimatedDueDate: null,
            confirmedBy: DatesConfirmedBy.acDeclared),
        throwsA(isA<InvalidStateException>()));
  });
}
