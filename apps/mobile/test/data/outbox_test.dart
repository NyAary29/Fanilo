import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fanilo_mobile/data/local/database.dart';
import 'package:fanilo_mobile/data/repositories/outbox_repository.dart';
import 'package:fanilo_mobile/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;

  setUp(() {
    db = newTestDb();
    outbox = OutboxRepository(db);
  });
  tearDown(() => db.close());

  Future<String> enqueue(String status, {int? base = 1}) => outbox.enqueue(
        entity: SyncEntity.referral,
        op: SyncOp.upsert,
        id: 'r-1',
        baseVersion: base,
        data: {'status': status},
      );

  test('change_id UUID v4 généré côté client, ordre de saisie conservé', () async {
    final a = await outbox.enqueue(
        entity: SyncEntity.beneficiary, op: SyncOp.upsert, id: 'b-1', baseVersion: null, data: {});
    final b = await outbox.enqueue(
        entity: SyncEntity.consent, op: SyncOp.upsert, id: 'c-1', baseVersion: null, data: {});
    final uuidV4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    expect(a, matches(uuidV4));
    expect(b, matches(uuidV4));
    final rows = await outbox.all();
    expect(rows.map((r) => r.changeId), [a, b]);
    expect(rows.first.seq, lessThan(rows.last.seq));
    expect(rows.first.status, 'pending');
    expect(rows.first.attempts, 0);
  });

  test('fusion d\'une entrée jamais envoyée : même change_id, données récentes', () async {
    final first = await enqueue('accepted');
    final second = await enqueue('arrived', base: 99);
    expect(second, first);
    final row = (await outbox.all()).single;
    expect(jsonDecode(row.data), {'status': 'arrived'});
    expect(row.baseVersion, 1, reason: 'la base_version d\'origine est gardée');
  });

  test('pas de fusion après une tentative d\'envoi (réponse possiblement perdue)', () async {
    final first = await enqueue('accepted');
    await (db.update(db.outbox)..where((o) => o.changeId.equals(first)))
        .write(const OutboxCompanion(attempts: Value(1)));
    final second = await enqueue('arrived');
    expect(second, isNot(first));
    final rows = await outbox.all();
    expect(rows, hasLength(2));
    expect(jsonDecode(rows.first.data), {'status': 'accepted'}, reason: 'jamais modifiée');
  });

  test('les alertes sont en lecture seule', () async {
    expect(
      () => outbox.enqueue(
          entity: SyncEntity.alert, op: SyncOp.upsert, id: 'a-1', baseVersion: 1, data: {}),
      throwsArgumentError,
    );
  });

  test('compteur d\'attente et abandon d\'une entrée refusée', () async {
    final id = await enqueue('accepted');
    expect(await outbox.watchPendingCount().first, 1);
    await (db.update(db.outbox)..where((o) => o.changeId.equals(id)))
        .write(const OutboxCompanion(status: Value('rejected'), lastError: Value('x')));
    expect(await outbox.watchPendingCount().first, 0);
    expect(await outbox.watchRejected().first, hasLength(1));
    await outbox.discard(id);
    await outbox.discard(id); // idempotent
    expect(await outbox.all(), isEmpty);
  });
}
