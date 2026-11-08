import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/enums.dart';
import '../local/database.dart';

/// File d'attente locale des modifications à pousser.
///
/// Règles :
/// - chaque entrée porte un `change_id` UUID v4 généré côté client ;
/// - une entrée **jamais envoyée** (`attempts == 0`) pour la même entité est
///   fusionnée (on garde son `change_id` et sa `base_version`, on remplace
///   les données par l'état complet le plus récent) ;
/// - une entrée déjà envoyée au moins une fois n'est **jamais modifiée** : le
///   serveur a pu l'appliquer (réponse perdue) et renverrait le même résultat
///   pour ce `change_id` sans tenir compte de nouvelles données. Une nouvelle
///   entrée est alors créée.
class OutboxRepository {
  OutboxRepository(this.db, {Uuid? uuid, DateTime Function()? now})
      : _uuid = uuid ?? const Uuid(),
        _now = now ?? DateTime.now;

  final AppDatabase db;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// À appeler dans la même transaction que l'écriture locale.
  Future<String> enqueue({
    required SyncEntity entity,
    required SyncOp op,
    required String id,
    required int? baseVersion,
    required Map<String, dynamic> data,
  }) async {
    if (!entity.isWritable) {
      throw ArgumentError('Entité en lecture seule : ${entity.wire}');
    }
    return db.transaction(() async {
      final mergeable = await (db.select(db.outbox)
            ..where((o) =>
                o.entity.equals(entity.wire) &
                o.entityId.equals(id) &
                o.status.equals(OutboxStatus.pending.wire) &
                o.attempts.equals(0))
            ..orderBy([(o) => OrderingTerm.desc(o.seq)])
            ..limit(1))
          .getSingleOrNull();

      if (mergeable != null) {
        await (db.update(db.outbox)
              ..where((o) => o.changeId.equals(mergeable.changeId)))
            .write(OutboxCompanion(
          op: Value(op == SyncOp.delete ? SyncOp.delete.wire : mergeable.op),
          data: Value(jsonEncode(data)),
        ));
        return mergeable.changeId;
      }

      final changeId = _uuid.v4();
      await db.into(db.outbox).insert(OutboxCompanion.insert(
            changeId: changeId,
            entity: entity.wire,
            op: op.wire,
            entityId: id,
            baseVersion: Value(baseVersion),
            data: jsonEncode(data),
            seq: await db.nextOutboxSeq(),
            createdAt: _now().toUtc(),
          ));
      return changeId;
    });
  }

  Future<List<OutboxRow>> all() =>
      (db.select(db.outbox)..orderBy([(o) => OrderingTerm.asc(o.seq)])).get();

  Stream<int> watchPendingCount() {
    final c = db.outbox.changeId.count();
    return (db.selectOnly(db.outbox)
          ..addColumns([c])
          ..where(db.outbox.status.equals(OutboxStatus.pending.wire)))
        .map((r) => r.read(c) ?? 0)
        .watchSingle();
  }

  Stream<List<OutboxRow>> watchRejected() => (db.select(db.outbox)
        ..where((o) => o.status.equals(OutboxStatus.rejected.wire))
        ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
      .watch();

  /// Abandonne une modification refusée. La donnée locale sera corrigée par
  /// le prochain pull si le serveur la modifie ; voir README (limites).
  Future<void> discard(String changeId) =>
      (db.delete(db.outbox)..where((o) => o.changeId.equals(changeId))).go();

  /// Renvoie une modification refusée (après correction côté serveur, par ex.).
  ///
  /// Un **nouveau** `change_id` est attribué : le serveur mémorise le résultat
  /// d'un `change_id` (idempotence) et renverrait sinon le même refus. C'est
  /// sans risque car un changement `rejected` n'a pas été appliqué.
  Future<String> retry(String changeId) async {
    final newId = _uuid.v4();
    await (db.update(db.outbox)..where((o) => o.changeId.equals(changeId)))
        .write(OutboxCompanion(
      changeId: Value(newId),
      status: const Value('pending'),
      attempts: const Value(0),
      nextAttemptAt: const Value(null),
      lastError: const Value(null),
    ));
    return newId;
  }
}
