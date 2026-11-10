import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/enums.dart';
import '../local/database.dart';
import '../local/entity_store.dart';

/// Effet de l'abandon d'une modification refusée sur la donnée locale.
enum DiscardOutcome {
  /// L'entité n'a jamais été confirmée par le serveur : la ligne locale est
  /// supprimée (elle n'existe pas côté serveur).
  removedLocal,

  /// L'entité existe côté serveur : le curseur est remis à zéro, le prochain
  /// pull recharge l'état serveur et remplace la donnée locale.
  reloadFromServer,

  /// D'autres modifications de la même entité sont encore dans l'outbox :
  /// elles la réconcilieront (rien d'autre à faire).
  none,
}

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

  /// Abandonne une modification refusée **et** remet la donnée locale dans
  /// l'état du serveur :
  /// - entité jamais confirmée (`version == 0`) : ligne locale supprimée ;
  /// - entité connue du serveur : curseur remis à zéro, le prochain pull
  ///   (à lancer par l'appelant) recharge l'état serveur.
  ///
  /// Si d'autres entrées de la même entité restent dans l'outbox, la donnée
  /// locale est laissée telle quelle : ces entrées la réconcilieront.
  Future<DiscardOutcome> discard(String changeId) => db.transaction(() async {
        final row = await (db.select(db.outbox)
              ..where((o) => o.changeId.equals(changeId)))
            .getSingleOrNull();
        await (db.delete(db.outbox)..where((o) => o.changeId.equals(changeId))).go();
        if (row == null) return DiscardOutcome.none;
        final entity = SyncEntity.fromWire(row.entity);
        if (entity == null || !entity.isWritable) return DiscardOutcome.none;
        final others = await (db.select(db.outbox)
              ..where((o) =>
                  o.entity.equals(row.entity) & o.entityId.equals(row.entityId))
              ..limit(1))
            .get();
        if (others.isNotEmpty) return DiscardOutcome.none;
        final store = EntityStore(db);
        final version = await store.currentVersion(entity, row.entityId);
        if (version == null) return DiscardOutcome.none;
        if (version == 0) {
          await store.deleteLocal(entity, row.entityId);
          return DiscardOutcome.removedLocal;
        }
        await db.resetCursor();
        return DiscardOutcome.reloadFromServer;
      });

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
