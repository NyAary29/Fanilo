import 'dart:convert';

import 'package:fanilo_mobile/data/api/api_client.dart';
import 'package:fanilo_mobile/data/api/dto.dart';
import 'package:fanilo_mobile/data/local/database.dart';
import 'package:fanilo_mobile/data/reference/reference_repository.dart';
import 'package:fanilo_mobile/data/repositories/local_repository.dart';
import 'package:fanilo_mobile/data/repositories/outbox_repository.dart';
import 'package:fanilo_mobile/data/sync/sync_service.dart';
import 'package:fanilo_mobile/domain/enums.dart';
import 'package:fanilo_mobile/domain/reference_data.dart';
import 'package:fanilo_mobile/domain/registration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Sites tels que renvoyés par `GET /sync/pull` de l'API locale (relevé curl).
const _csbA = '6f919caa-729c-48e3-a3ba-e2b0b8a376e3';
const _zoneA1 = 'site-demo-1'; // site de testUser
const _chrr = '67ef8cfe-01f3-489d-923c-bd66bd9071c6';
const _inactive = '00000000-0000-4000-8000-0000000000aa';

void _seedSites(FakeSyncServer server) {
  server.seed('site', _chrr, 1, {
    'name': 'CHRR Démo Bongolava',
    'kind': 'reference_facility',
    'code': 'CHRR-BGL',
    'district': 'Tsiroanomandidy',
    'region': 'Bongolava',
    'parent_site_id': null,
    'is_active': true,
  });
  server.seed('site', _csbA, 1, {
    'name': 'CSB II Démo Bongolava A',
    'kind': 'csb',
    'code': 'CSB-BGL-A',
    'district': 'Tsiroanomandidy',
    'region': 'Bongolava',
    'parent_site_id': _chrr,
    'is_active': true,
  });
  server.seed('site', _zoneA1, 1, {
    'name': 'Zone communautaire Démo A1',
    'kind': 'community_zone',
    'code': 'ZC-BGL-A1',
    'district': 'Tsiroanomandidy',
    'region': 'Bongolava',
    'parent_site_id': _csbA,
    'is_active': true,
  });
  server.seed('site', _inactive, 1, {
    'name': 'Ancien CSB',
    'kind': 'csb',
    'code': 'CSB-OLD',
    'parent_site_id': null,
    'is_active': false,
  });
}

RegistrationDraft _draft() => RegistrationDraft(
      consent: const ConsentInput(
        scopes: {ConsentScope.reny},
        method: ConsentMethod.oral,
        informationVersions: {ConsentScope.reny: 'demo-0.1'},
        informationPresented: true,
      ),
      identity: const IdentityInput(displayName: 'Personne fictive'),
    );

void main() {
  late AppDatabase db;
  late FakeSyncServer server;
  late FakeReferenceApi refApi;
  late OutboxRepository outbox;
  late LocalRepository repo;
  late ReferenceRepository references;
  late SyncService sync;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 11, 9, 10);
    db = newTestDb();
    server = FakeSyncServer();
    refApi = FakeReferenceApi();
    outbox = OutboxRepository(db, now: () => now);
    repo = LocalRepository(db, outbox, now: () => now);
    references = ReferenceRepository(db, refApi, now: () => now);
    sync = SyncService(db: db, api: server, references: references, now: () => now);
  });

  tearDown(() async {
    await sync.dispose();
    await db.close();
  });

  group('Sites (pull uniquement)', () {
    test('le pull enregistre les sites ; actifs, hors site de l\'AC, CSB d\'abord',
        () async {
      _seedSites(server);
      final report = await sync.sync();
      expect(report.ok, isTrue);

      final all = await db.select(db.sites).get();
      expect(all, hasLength(4));
      final csb = all.firstWhere((s) => s.id == _csbA);
      expect(csb.kind, 'csb');
      expect(csb.parentSiteId, _chrr);
      expect(csb.version, 1);

      final choices =
          await repo.watchReferralSites(excludeSiteId: testUser.siteId).first;
      expect(choices.map((s) => s.id).toList(), [_csbA, _chrr],
          reason: 'inactif et site de l\'AC exclus ; CSB avant la structure de référence');
    });

    test('un site ne peut pas être poussé', () {
      expect(SyncEntity.site.isWritable, isFalse);
      expect(
          () => outbox.enqueue(
              entity: SyncEntity.site,
              op: SyncOp.upsert,
              id: _csbA,
              baseVersion: 1,
              data: {}),
          throwsArgumentError);
    });
  });

  group('Création de référence', () {
    test('proposée, via l\'outbox, from_site_id = site de la bénéficiaire', () async {
      _seedSites(server);
      await sync.sync();
      final b = await repo.registerBeneficiary(_draft(), testUser);
      await sync.sync();

      final id = await repo.createReferral(
          beneficiaryId: b, toSiteId: _csbA, reason: '  Signes à vérifier ', user: testUser);

      final row = await (db.select(db.referrals)..where((r) => r.id.equals(id))).getSingle();
      expect(row.status, 'proposed');
      expect(row.fromSiteId, testUser.siteId);
      expect(row.toSiteId, _csbA);
      expect(row.reason, 'Signes à vérifier');
      expect(row.version, 0);

      final entry = (await outbox.all()).single;
      expect(entry.entity, 'referral');
      expect(entry.baseVersion, isNull);
      expect(jsonDecode(entry.data), {
        'id': id,
        'beneficiary_id': b,
        'alert_id': null,
        'from_site_id': testUser.siteId,
        'to_site_id': _csbA,
        'status': 'proposed',
        'reason': 'Signes à vérifier',
        'outcome_note': null,
      });

      final report = await sync.sync();
      expect(report.applied, 1);
      expect(server.versionOf('referral', id), 1);
      expect(await outbox.all(), isEmpty);
    });

    test('site inconnu ou inactif : refusé, rien n\'est écrit', () async {
      _seedSites(server);
      await sync.sync();
      final b = await repo.registerBeneficiary(_draft(), testUser);
      final before = (await outbox.all()).length;
      for (final site in ['inconnu', _inactive]) {
        await expectLater(
            repo.createReferral(beneficiaryId: b, toSiteId: site, user: testUser),
            throwsA(isA<InvalidStateException>()));
      }
      expect(await db.select(db.referrals).get(), isEmpty);
      expect((await outbox.all()).length, before);
    });
  });

  group('Référentiels (signes, information de consentement)', () {
    test('récupérés après la synchro puis disponibles hors ligne', () async {
      expect(await references.watchSignCatalog('reny').first, isNull);
      await sync.sync();
      expect(refApi.calls, ['sign-codes:reny', 'consent-information']);

      refApi.offline = true;
      final catalog = await references.watchSignCatalog('reny').first;
      expect(catalog!.version, '0.1.0');
      expect(catalog.showDemoBanner, isTrue);
      expect(catalog.forModule('reny').map((s) => s.code),
          ['SIGN_DEMO_01', 'SIGN_DEMO_02', 'SIGN_DEMO_05']);
      final info = await references.consentInformation();
      expect(info!.forScope(ConsentScope.reny)!.version, 'demo-0.1');
      expect(info.anyDemo, isTrue);
    });

    test('échec (hors ligne, 503, réponse malformée) : la copie locale reste', () async {
      expect(await references.refresh(), isTrue);
      now = now.add(const Duration(hours: 2));

      refApi.offline = true;
      expect(await references.refresh(), isFalse);
      refApi.offline = false;
      refApi.error = const ApiException(503, 'Référentiel des codes de signes indisponible.');
      expect(await references.refresh(), isFalse);
      refApi.error = null;
      refApi.signs = {'items': 'pas une liste'};
      expect(await references.refresh(), isFalse);

      final catalog = await references.watchSignCatalog('reny').first;
      expect(catalog!.signs, hasLength(3));
    });

    test('statut validated : plus de bandeau DÉMO', () async {
      refApi.signs = demoSignCodes(status: 'validated', isDemo: false);
      await references.refresh(force: true);
      final catalog = await references.watchSignCatalog('reny').first;
      expect(catalog!.showDemoBanner, isFalse);
    });

    test('pas de rafraîchissement non forcé avant le délai minimal', () async {
      await references.refresh();
      refApi.calls.clear();
      await references.refresh();
      expect(refApi.calls, isEmpty);
      await references.refresh(force: true);
      expect(refApi.calls, hasLength(2));
    });

    test('contenus publiés (conseils de visite) : cache séparé, copie gardée en cas d\'échec',
        () async {
      expect(await references.watchContents('reny').first, isNull);
      expect(await references.refreshContents(), isTrue);
      expect(refApi.calls, ['contents:reny']);
      final contents = await references.watchContents('reny').first;
      expect(contents!.forModule('reny').map((c) => c.code), ['MSG_DEMO_INFO_ANC']);
      expect(contents.anyDemo, isTrue);

      refApi.contents = {'pas': 'items'};
      expect(await references.refreshContents(force: true), isFalse);
      refApi.offline = true;
      expect(await references.refreshContents(force: true), isFalse);
      expect((await references.watchContents('reny').first)!.items, hasLength(3));
    });

    test('hors ligne : la synchro échoue sans appeler les référentiels', () async {
      server.offline = true;
      await sync.sync();
      expect(refApi.calls, isEmpty);
    });

    test('lecture tolérante de l\'information de consentement', () {
      final set = ConsentInformationSet.fromJson({
        'items': [
          {'scope': 'reny', 'version': 'v2', 'status': 'validated', 'summary_fr': 'x'},
          {'scope': 'inconnue', 'version': 'v1', 'status': 'validated'},
          {'scope': 'tanora', 'version': ' ', 'status': 'validated'},
        ]
      });
      expect(set.items.map((i) => i.scope), [ConsentScope.reny]);
      expect(set.anyDemo, isFalse);
    });
  });

  group('Abandon d\'une modification refusée', () {
    test('entité connue du serveur : rechargée depuis le serveur', () async {
      _seedSites(server);
      server.seed('referral', 'r-1', 3, {
        'beneficiary_id': 'b-1',
        'alert_id': null,
        'from_site_id': _zoneA1,
        'to_site_id': _csbA,
        'status': 'proposed',
        'reason': null,
        'outcome_note': null,
      });
      await sync.sync();

      server.rejectRule = (c) => c.entity == 'referral' ? 'invalid_transition' : null;
      await repo.transitionReferral('r-1', ReferralStatus.accepted);
      final report = await sync.sync();
      expect(report.rejected, 1);
      final rejected = (await outbox.all()).single;

      final local = await (db.select(db.referrals)..where((r) => r.id.equals('r-1'))).getSingle();
      expect(local.status, 'accepted', reason: 'donnée locale encore modifiée');

      final outcome = await outbox.discard(rejected.changeId);
      expect(outcome, DiscardOutcome.reloadFromServer);
      expect(await db.readState(SyncStateKeys.cursor), isNull);

      server.pullSinceCalls.clear();
      await sync.sync(force: true);
      expect(server.pullSinceCalls.first, isNull, reason: 'pull complet');
      final reloaded =
          await (db.select(db.referrals)..where((r) => r.id.equals('r-1'))).getSingle();
      expect(reloaded.status, 'proposed');
      expect(reloaded.version, 3);
      expect(await outbox.all(), isEmpty);
    });

    test('entité jamais confirmée : ligne locale supprimée', () async {
      _seedSites(server);
      await sync.sync();
      final b = await repo.registerBeneficiary(_draft(), testUser);
      await sync.sync();
      server.rejectRule = (c) => c.entity == 'referral' ? 'forbidden' : null;
      final id = await repo.createReferral(beneficiaryId: b, toSiteId: _csbA, user: testUser);
      await sync.sync();
      final rejected = (await outbox.all()).single;

      expect(await outbox.discard(rejected.changeId), DiscardOutcome.removedLocal);
      expect(await (db.select(db.referrals)..where((r) => r.id.equals(id))).get(), isEmpty);
      expect(await db.readState(SyncStateKeys.cursor), isNotNull,
          reason: 'pas de rechargement complet nécessaire');
    });

    test('autre modification en attente : donnée locale laissée', () async {
      server.seed('referral', 'r-2', 1, {
        'beneficiary_id': 'b-1',
        'to_site_id': _csbA,
        'status': 'proposed',
      });
      await sync.sync();
      server.rejectRule = (c) => 'refus';
      await repo.transitionReferral('r-2', ReferralStatus.accepted);
      await sync.sync();
      final first = (await outbox.all()).single;
      server.rejectRule = null;
      await repo.transitionReferral('r-2', ReferralStatus.arrived);
      expect(await outbox.discard(first.changeId), DiscardOutcome.none);
      expect((await outbox.all()).single.status, 'pending');
    });
  });

  test('422 sur tout le lot : entrées refusées, pas de nouvel essai automatique',
      () async {
    final b = await repo.registerBeneficiary(_draft(), testUser);
    expect(b, isNotEmpty);
    server.pushError = const ApiException(422, 'enveloppe invalide');
    final report = await sync.sync();
    expect(report.rejected, 3);
    final rows = await outbox.all();
    expect(rows.every((r) => r.status == 'rejected'), isTrue);
    expect(rows.first.lastError, contains('422'));

    server.pushCalls.clear();
    await sync.sync(force: true);
    expect(server.pushCalls, isEmpty);
  });

  test('erreur de refus {code, message} (réponse réelle) lisible', () {
    final r = PushResult.fromJson({
      'change_id': 'c-1',
      'status': 'rejected',
      'server_version': null,
      'server_data': null,
      'error': {'code': 'validation_error', 'message': 'Site destinataire introuvable.'},
    });
    expect(r.status, PushStatus.rejected);
    expect(r.error, 'Site destinataire introuvable. (validation_error)');
  });
}
