import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/enums.dart';
import '../api/api_client.dart';
import '../api/dto.dart';
import '../local/database.dart';
import '../local/entity_store.dart';
import '../reference/reference_repository.dart';

/// Délai exponentiel entre deux tentatives d'envoi d'une même entrée.
class BackoffPolicy {
  const BackoffPolicy({
    this.baseDelay = const Duration(seconds: 5),
    this.maxDelay = const Duration(minutes: 30),
  });

  final Duration baseDelay;
  final Duration maxDelay;

  Duration delayFor(int attempts) {
    final n = max(1, attempts);
    final ms = baseDelay.inMilliseconds * pow(2, min(n - 1, 20));
    return Duration(milliseconds: min(ms.toInt(), maxDelay.inMilliseconds));
  }
}

/// Codes d'erreur de synchronisation (traduits dans l'interface).
abstract final class SyncErrorCode {
  static const offline = 'offline';
  static const sessionExpired = 'session_expired';
  static const server = 'server';
}

class SyncReport {
  int applied = 0;
  int conflicts = 0;
  int rejected = 0;
  int deferred = 0;
  int pulled = 0;

  /// Code d'erreur ([SyncErrorCode]) si la synchronisation s'est interrompue.
  String? error;

  bool get ok => error == null;

  @override
  String toString() =>
      'SyncReport(applied=$applied, conflicts=$conflicts, rejected=$rejected, '
      'deferred=$deferred, pulled=$pulled, error=$error)';
}

/// Synchronisation hors ligne (contrat, section 8) : push de l'outbox par
/// lots, puis pull depuis le curseur.
///
/// - `applied`  : l'entrée quitte l'outbox, la version locale est mise à jour,
///   et les entrées suivantes pour la même entité sont « rebasées ».
/// - `conflict` : l'état serveur s'applique localement ; la modification
///   locale est conservée dans `sync_conflicts` pour revue.
/// - `rejected` : l'entrée reste dans l'outbox (statut `rejected`) avec
///   l'erreur, affichée à l'utilisateur.
/// - erreur réseau / 5xx / résultat manquant : l'entrée reste en attente, avec
///   un backoff exponentiel. Le même `change_id` est renvoyé, ce qui est sans
///   risque grâce à l'idempotence côté serveur.
class SyncService {
  SyncService({
    required this.db,
    required this.api,
    this.references,
    EntityStore? store,
    this.batchSize = 50,
    this.pullLimit = 500,
    this.backoff = const BackoffPolicy(),
    DateTime Function()? now,
    Uuid? uuid,
  })  : store = store ?? EntityStore(db),
        _now = now ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  final AppDatabase db;
  final SyncApi api;

  /// Référentiels rafraîchis après un pull réussi (facultatif).
  final ReferenceRepository? references;
  final EntityStore store;
  final int batchSize;
  final int pullLimit;
  final BackoffPolicy backoff;
  final DateTime Function() _now;
  final Uuid _uuid;

  static const _maxPushRounds = 50;
  static const _maxPullPages = 200;

  Future<SyncReport>? _running;
  final _runningCtrl = StreamController<bool>.broadcast();

  bool get isRunning => _running != null;
  Stream<bool> get runningStream => _runningCtrl.stream;

  /// Lance une synchronisation. Les appels concurrents partagent la même
  /// exécution. [force] ignore le backoff (déclenchement manuel, retour réseau).
  Future<SyncReport> sync({bool force = false}) {
    final inFlight = _running;
    if (inFlight != null) return inFlight;
    final f = _run(force: force);
    _running = f;
    _runningCtrl.add(true);
    return f.whenComplete(() {
      _running = null;
      _runningCtrl.add(false);
    });
  }

  Future<String> deviceId() async {
    final existing = await db.readState(SyncStateKeys.deviceId);
    if (existing != null) return existing;
    final id = _uuid.v4();
    await db.writeState(SyncStateKeys.deviceId, id);
    return id;
  }

  Future<SyncReport> _run({required bool force}) async {
    final report = SyncReport();
    try {
      await _push(report, force: force);
      if (report.error == null) await _pull(report);
      // Les référentiels n'influencent pas le résultat de la synchronisation :
      // en cas d'échec, la copie locale reste en vigueur.
      if (report.error == null) await references?.refresh(force: force);
    } on NetworkException {
      report.error = SyncErrorCode.offline;
    } on SessionExpiredException {
      report.error = SyncErrorCode.sessionExpired;
    } on ApiException catch (e) {
      report.error = e.isUnauthorized ? SyncErrorCode.sessionExpired : SyncErrorCode.server;
    } on Object catch (e, st) {
      // Donnée serveur inattendue (champ manquant, type invalide…) : la
      // transaction en cours est annulée, le curseur n'avance pas.
      developer.log('Échec de synchronisation', error: e, stackTrace: st, name: 'fanilo.sync');
      report.error = SyncErrorCode.server;
    }
    await db.writeState(SyncStateKeys.lastSyncError, report.error);
    if (report.error == null) {
      await db.writeState(
          SyncStateKeys.lastSyncAt, _now().toUtc().toIso8601String());
    }
    return report;
  }

  // ================================================================== push

  /// Sélectionne au plus une entrée par entité (ordre de saisie préservé) :
  /// une seconde modification de la même entité attend que la première soit
  /// confirmée, pour partir avec la bonne `base_version`.
  Future<List<OutboxRow>> _nextBatch({required bool force}) async {
    final pending = await (db.select(db.outbox)
          ..where((o) => o.status.equals(OutboxStatus.pending.wire))
          ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
        .get();
    final now = _now().toUtc();
    final seen = <String>{};
    final batch = <OutboxRow>[];
    for (final row in pending) {
      final key = '${row.entity}/${row.entityId}';
      if (!seen.add(key)) continue;
      final next = row.nextAttemptAt;
      if (!force && next != null && next.isAfter(now)) continue;
      batch.add(row);
      if (batch.length >= batchSize) break;
    }
    return batch;
  }

  Future<void> _push(SyncReport report, {required bool force}) async {
    final device = await deviceId();
    final tried = <String>{};
    for (var round = 0; round < _maxPushRounds; round++) {
      final batch = (await _nextBatch(force: force))
          .where((r) => !tried.contains(r.changeId))
          .toList();
      if (batch.isEmpty) return;
      tried.addAll(batch.map((r) => r.changeId));

      final changes = batch
          .map((r) => PushChange(
                changeId: r.changeId,
                entity: r.entity,
                op: r.op,
                id: r.entityId,
                baseVersion: r.baseVersion,
                data: (jsonDecode(r.data) as Map).cast<String, dynamic>(),
              ))
          .toList();

      List<PushResult> results;
      try {
        results = await api.push(device, changes);
      } on NetworkException catch (e) {
        await _deferAll(batch, e.message);
        report.deferred += batch.length;
        report.error = SyncErrorCode.offline;
        return;
      } on SessionExpiredException {
        report.error = SyncErrorCode.sessionExpired;
        return;
      } on ApiException catch (e) {
        if (e.isUnauthorized) {
          report.error = SyncErrorCode.sessionExpired;
          return;
        }
        if (e.statusCode == 422) {
          // Enveloppe refusée en bloc (contrat, section 8) : ne pas la
          // renvoyer telle quelle. Les entrées passent en « refusé » pour que
          // l'utilisateur les voie, les réessaie ou les abandonne.
          await db.transaction(() async {
            for (final row in batch) {
              await _onRejected(
                  row,
                  PushResult(
                      changeId: row.changeId,
                      status: PushStatus.rejected,
                      error: 'Lot refusé par le serveur (422) : ${e.detail}'));
            }
          });
          report.rejected += batch.length;
          continue;
        }
        // Lot refusé en bloc (5xx, 4xx inattendu) : nouvel essai plus tard.
        await _deferAll(batch, 'HTTP ${e.statusCode}: ${e.detail}');
        report.deferred += batch.length;
        report.error = SyncErrorCode.server;
        return;
      }

      final byId = {for (final r in results) r.changeId: r};
      await db.transaction(() async {
        for (final row in batch) {
          final result = byId[row.changeId];
          switch (result?.status) {
            case PushStatus.applied:
              await _onApplied(row, result!);
              report.applied++;
            case PushStatus.conflict:
              await _onConflict(row, result!);
              report.conflicts++;
            case PushStatus.rejected:
              await _onRejected(row, result!);
              report.rejected++;
            case PushStatus.unknown:
            case null:
              await _defer(row, 'Résultat absent pour ce changement');
              report.deferred++;
          }
        }
      });
    }
  }

  Future<void> _onApplied(OutboxRow row, PushResult r) async {
    await _deleteOutbox(row.changeId);
    final entity = SyncEntity.fromWire(row.entity);
    final v = r.serverVersion;
    if (entity == null || v == null) return;
    await store.setVersion(entity, row.entityId, v);
    // Les modifications suivantes de la même entité partent de cette version.
    await (db.update(db.outbox)
          ..where((o) =>
              o.entity.equals(row.entity) &
              o.entityId.equals(row.entityId) &
              o.status.equals(OutboxStatus.pending.wire)))
        .write(OutboxCompanion(baseVersion: Value(v)));
    // Champs attribués par le serveur (ex. `code`) si `server_data` est fourni
    // et qu'aucune autre modification locale n'est en attente.
    final data = r.serverData;
    if (data != null && !await _hasPending(row.entity, row.entityId)) {
      await store.applyServer(
          entity, row.entityId, v, data['deleted_at'] as String?, data);
    }
  }

  Future<void> _onConflict(OutboxRow row, PushResult r) async {
    await db.into(db.syncConflicts).insert(SyncConflictsCompanion.insert(
          changeId: row.changeId,
          entity: row.entity,
          entityId: row.entityId,
          op: row.op,
          baseVersion: Value(row.baseVersion),
          localData: row.data,
          serverVersion: Value(r.serverVersion),
          serverData:
              Value(r.serverData == null ? null : jsonEncode(r.serverData)),
          detectedAt: _now().toUtc(),
        ));
    await _deleteOutbox(row.changeId);
    final entity = SyncEntity.fromWire(row.entity);
    if (entity != null && r.serverVersion != null) {
      // Par défaut, la version serveur l'emporte.
      await store.applyServer(entity, row.entityId, r.serverVersion!,
          r.serverData?['deleted_at'] as String?, r.serverData);
    }
  }

  Future<void> _onRejected(OutboxRow row, PushResult r) async {
    await (db.update(db.outbox)..where((o) => o.changeId.equals(row.changeId)))
        .write(OutboxCompanion(
      status: Value(OutboxStatus.rejected.wire),
      attempts: Value(row.attempts + 1),
      lastError: Value(r.error ?? 'Refusé par le serveur'),
      nextAttemptAt: const Value(null),
    ));
  }

  Future<void> _deferAll(List<OutboxRow> rows, String error) =>
      db.transaction(() async {
        for (final r in rows) {
          await _defer(r, error);
        }
      });

  Future<void> _defer(OutboxRow row, String error) async {
    final attempts = row.attempts + 1;
    await (db.update(db.outbox)..where((o) => o.changeId.equals(row.changeId)))
        .write(OutboxCompanion(
      attempts: Value(attempts),
      lastError: Value(error),
      nextAttemptAt: Value(_now().toUtc().add(backoff.delayFor(attempts))),
    ));
  }

  /// Suppression idempotente : aucune erreur si l'entrée a déjà été retirée.
  Future<void> _deleteOutbox(String changeId) =>
      (db.delete(db.outbox)..where((o) => o.changeId.equals(changeId))).go();

  Future<bool> _hasPending(String entity, String id) async {
    final row = await (db.select(db.outbox)
          ..where((o) =>
              o.entity.equals(entity) &
              o.entityId.equals(id) &
              o.status.equals(OutboxStatus.pending.wire))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  // ================================================================== pull

  Future<void> _pull(SyncReport report) async {
    var cursor = await db.readState(SyncStateKeys.cursor);
    for (var page = 0; page < _maxPullPages; page++) {
      final resp = await api.pull(since: cursor, limit: pullLimit);
      await db.transaction(() async {
        for (final c in resp.changes) {
          final entity = SyncEntity.fromWire(c.entity);
          if (entity == null) continue; // entité inconnue : ignorée
          // Une modification locale en attente sera réconciliée par le push
          // (conflit si la version serveur a changé) : on ne l'écrase pas.
          if (entity.isWritable && await _hasPending(c.entity, c.id)) continue;
          await store.applyServer(entity, c.id, c.version, c.deletedAt, c.data);
          report.pulled++;
        }
        // Curseur enregistré dans la même transaction que les données.
        if (resp.nextCursor != null) {
          await db.writeState(SyncStateKeys.cursor, resp.nextCursor);
        }
      });
      final next = resp.nextCursor;
      if (!resp.hasMore || next == null || next == cursor) return;
      cursor = next;
    }
  }

  Future<void> dispose() => _runningCtrl.close();
}
