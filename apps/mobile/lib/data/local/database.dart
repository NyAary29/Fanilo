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
  Sites,
  ReferenceCache,
  Outbox,
  SyncConflicts,
  SyncState,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

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
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(sites);
            await m.createTable(referenceCache);
            // Les sites étaient ignorés par les versions précédentes : on
            // repart d'un curseur vide pour les recevoir (le pull est
            // idempotent et n'écrase pas les modifications en attente).
            await (delete(syncState)
                  ..where((t) => t.key.equals(SyncStateKeys.cursor)))
                .go();
          }
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

  /// Oublie le curseur : le prochain pull recharge tout l'état serveur du
  /// périmètre (utilisé après l'abandon d'une modification refusée).
  Future<void> resetCursor() => (delete(syncState)
        ..where((t) => t.key.equals(SyncStateKeys.cursor)))
      .go();

  /// Efface toutes les données locales (déconnexion).
  Future<void> wipe() => transaction(() async {
        for (final t in allTables) {
          await delete(t).go();
        }
      });
}
