import 'package:drift/drift.dart';

import 'tables.dart';

part 'database.g.dart';

/// Clés de [SyncState].
abstract final class SyncStateKeys {
  static const cursor = 'cursor';
  static const deviceId = 'device_id';
  static const lastSyncAt = 'last_sync_at';
  static const lastSyncError = 'last_sync_error';
  static const outboxSeq = 'outbox_seq';
}

@DriftDatabase(tables: [
  Beneficiaries,
  BeneficiaryIdentities,
  Consents,
  Pregnancies,
  AncVisits,
  Referrals,
  Alerts,
  Outbox,
  SyncConflicts,
  SyncState,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
              'CREATE INDEX idx_outbox_status_seq ON outbox (status, seq)');
          await customStatement(
              'CREATE INDEX idx_outbox_entity_id ON outbox (entity, id)');
          await customStatement(
              'CREATE INDEX idx_anc_visits_pregnancy ON anc_visits (pregnancy_id)');
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ------------------------------------------------------------ sync_state

  Future<String?> readState(String key) async {
    final row = await (select(syncState)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> writeState(String key, String? value) =>
      into(syncState).insertOnConflictUpdate(
          SyncStateCompanion.insert(key: key, value: Value(value)));

  Stream<String?> watchState(String key) =>
      (select(syncState)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((r) => r?.value);

  /// Numéro d'ordre monotone pour l'outbox (à appeler dans une transaction).
  Future<int> nextOutboxSeq() async {
    final current = int.tryParse(await readState(SyncStateKeys.outboxSeq) ?? '') ?? 0;
    final next = current + 1;
    await writeState(SyncStateKeys.outboxSeq, '$next');
    return next;
  }

  /// Efface toutes les données locales (déconnexion).
  Future<void> wipe() => transaction(() async {
        for (final t in allTables) {
          await delete(t).go();
        }
      });
}
