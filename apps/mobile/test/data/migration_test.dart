import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fanilo_mobile/data/local/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  setUpAll(useSystemSqliteForTests);

  test('migration 1 → 2 : tables sites et référentiels, curseur oublié', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = await Directory.systemTemp.createTemp('fanilo_mig');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    // Base au format v1 : sans `sites` ni `reference_cache`, curseur avancé.
    final v1 = AppDatabase(NativeDatabase(file));
    await v1.writeState(SyncStateKeys.cursor, 'eyJzIjo3fQ');
    await v1.writeState(SyncStateKeys.deviceId, 'device-1');
    await v1.customStatement('DROP TABLE sites');
    await v1.customStatement('DROP TABLE reference_cache');
    await v1.customStatement('PRAGMA user_version = 1');
    await v1.close();

    final v2 = AppDatabase(NativeDatabase(file));
    addTearDown(v2.close);
    expect(await v2.select(v2.sites).get(), isEmpty);
    expect(await v2.select(v2.referenceCache).get(), isEmpty);
    expect(await v2.readState(SyncStateKeys.cursor), isNull,
        reason: 'pull complet pour recevoir les sites ignorés jusque-là');
    expect(await v2.readState(SyncStateKeys.deviceId), 'device-1');
  });
}
