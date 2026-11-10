import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fanilo_mobile/data/api/api_client.dart';
import 'package:fanilo_mobile/data/api/dto.dart';
import 'package:fanilo_mobile/data/local/database.dart';
import 'package:fanilo_mobile/data/sync/sync_scheduler.dart';
import 'package:sqlite3/open.dart';

/// SQLite **système** (non chiffré) pour les tests de logique. Sur Linux,
/// seul `libsqlite3.so.0` est présent sans le paquet `-dev` : on l'accepte.
void useSystemSqliteForTests() {
  if (!Platform.isLinux) return;
  open.overrideFor(OperatingSystem.linux, () {
    try {
      return DynamicLibrary.open('libsqlite3.so');
    } on ArgumentError {
      return DynamicLibrary.open('libsqlite3.so.0');
    }
  });
}

AppDatabase newTestDb() {
  useSystemSqliteForTests();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

class _ServerEntity {
  _ServerEntity(this.version, this.data, {this.deletedAt});
  int version;
  Map<String, dynamic> data;
  String? deletedAt;
}

class _LogEntry {
  _LogEntry(this.seq, this.entity, this.id);
  final int seq;
  final String entity;
  final String id;
}

/// Serveur de synchronisation factice, fidèle au contrat (section 8) :
/// versions, conflits sur `base_version`, idempotence par `change_id`,
/// pull paginé par curseur opaque.
class FakeSyncServer implements SyncApi {
  final Map<String, _ServerEntity> _entities = {};
  final Map<String, PushResult> _processed = {};
  final List<_LogEntry> _log = [];
  int _seq = 0;

  /// Nombre d'applications effectives par clé `entity/id`.
  final Map<String, int> applyCount = {};

  /// Historique des appels.
  final List<List<PushChange>> pushCalls = [];
  final List<String?> pullSinceCalls = [];

  /// Erreur réseau avant traitement.
  bool offline = false;

  /// Erreur HTTP renvoyée pour tout le lot (ex. 422 d'enveloppe).
  ApiException? pushError;

  /// Traite le lot puis « perd » la réponse (erreur réseau).
  bool loseNextResponse = false;

  /// Règle de refus métier (renvoie le message d'erreur, ou null).
  String? Function(PushChange c)? rejectRule;

  static String _key(String entity, String id) => '$entity/$id';

  /// Pré-remplit l'état serveur (comme une modification faite ailleurs).
  void seed(String entity, String id, int version, Map<String, dynamic> data) {
    _entities[_key(entity, id)] = _ServerEntity(version, {...data, 'id': id});
    _log.add(_LogEntry(++_seq, entity, id));
  }

  int? versionOf(String entity, String id) => _entities[_key(entity, id)]?.version;
  Map<String, dynamic>? dataOf(String entity, String id) => _entities[_key(entity, id)]?.data;

  @override
  Future<List<PushResult>> push(String deviceId, List<PushChange> changes) async {
    pushCalls.add(changes);
    if (offline) throw const NetworkException('hors ligne (fake)');
    final err = pushError;
    if (err != null) throw err;
    final results = <PushResult>[];
    for (final c in changes) {
      final cached = _processed[c.changeId];
      if (cached != null) {
        results.add(cached);
        continue;
      }
      final r = _apply(c);
      _processed[c.changeId] = r;
      results.add(r);
    }
    if (loseNextResponse) {
      loseNextResponse = false;
      throw const NetworkException('réponse perdue (fake)');
    }
    return results;
  }

  PushResult _apply(PushChange c) {
    final reason = rejectRule?.call(c);
    if (reason != null) {
      return PushResult(changeId: c.changeId, status: PushStatus.rejected, error: reason);
    }
    final key = _key(c.entity, c.id);
    final current = _entities[key];
    final currentVersion = current?.version;
    if (currentVersion != c.baseVersion) {
      if (current == null) {
        return PushResult(
            changeId: c.changeId, status: PushStatus.rejected, error: 'introuvable');
      }
      return PushResult(
        changeId: c.changeId,
        status: PushStatus.conflict,
        serverVersion: current.version,
        serverData: Map.of(current.data),
      );
    }
    final next = (currentVersion ?? 0) + 1;
    final data = {...?current?.data, ...c.data, 'id': c.id};
    if (c.entity == 'beneficiary' && data['code'] == null) {
      data['code'] = 'FAN-${(100000 + _seq).toString()}';
    }
    _entities[key] = _ServerEntity(next, data,
        deletedAt: c.op == 'delete' ? '2026-11-08T00:00:00Z' : null);
    applyCount[key] = (applyCount[key] ?? 0) + 1;
    _log.add(_LogEntry(++_seq, c.entity, c.id));
    return PushResult(
        changeId: c.changeId,
        status: PushStatus.applied,
        serverVersion: next,
        serverData: Map.of(data));
  }

  @override
  Future<PullResponse> pull({String? since, int limit = 500}) async {
    pullSinceCalls.add(since);
    if (offline) throw const NetworkException('hors ligne (fake)');
    final after = int.tryParse(since ?? '0') ?? 0;
    final entries = _log.where((e) => e.seq > after).toList();
    final page = entries.take(limit).toList();
    final changes = [
      for (final e in page)
        PullChange(
          entity: e.entity,
          id: e.id,
          version: _entities[_key(e.entity, e.id)]!.version,
          deletedAt: _entities[_key(e.entity, e.id)]!.deletedAt,
          data: Map.of(_entities[_key(e.entity, e.id)]!.data),
        ),
    ];
    return PullResponse(
      changes: changes,
      nextCursor: page.isEmpty ? since : '${page.last.seq}',
      hasMore: entries.length > page.length,
    );
  }
}

class FakeNetwork implements NetworkStatusSource {
  FakeNetwork({this.online = false});
  bool online;
  final _ctrl = StreamController<bool>.broadcast();

  void set(bool value) {
    online = value;
    _ctrl.add(value);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => _ctrl.stream;
}

class FakeInteractionApi implements InteractionApi {
  final List<List<String>> calls = [];
  AskResponse? response;

  @override
  Future<AskResponse> askWithSigns(
      {required String module, String? beneficiaryId, required List<String> signCodes}) async {
    calls.add(signCodes);
    return response ??
        AskResponse.fromJson({
          'interaction_id': 'i-1',
          'outcome': 'danger_sign',
          'actions': ['refer_csb'],
          'severity': 'urgent',
          'content': {'code': 'MSG_DEMO', 'title': 'Titre démo', 'body': 'Corps démo', 'status': 'demo'},
          'alert_id': 'a-1',
          'is_demo': true,
          'disclaimer': 'FANILO ne remplace pas un professionnel de santé.',
        });
  }
}

/// Réponses réelles de l'API locale (relevées avec curl, mode démo).
Map<String, dynamic> demoSignCodes({String status = 'demo', bool isDemo = true}) => {
      'catalog_id': 'fanilo-demo-signs',
      'version': '0.1.0',
      'status': status,
      'is_demo': isDemo,
      'items': [
        {
          'code': 'SIGN_DEMO_01',
          'label_fr': '[DÉMO] Signe fictif n° 1 — libellé de démonstration',
          'label_mg': null,
          'modules': ['reny'],
        },
        {
          'code': 'SIGN_DEMO_02',
          'label_fr': '[DÉMO] Signe fictif n° 2 — libellé de démonstration',
          'label_mg': null,
          'modules': ['reny'],
        },
        {
          'code': 'SIGN_DEMO_05',
          'label_fr': '[DÉMO] Signe fictif n° 5 — libellé de démonstration',
          'label_mg': null,
          'modules': ['reny', 'tanora'],
        },
      ],
    };

Map<String, dynamic> demoConsentInformation({String status = 'demo'}) => {
      'items': [
        for (final scope in ['reny', 'tanora', 'reminders', 'voice_processing'])
          {
            'scope': scope,
            'version': 'demo-0.1',
            'status': status,
            'summary_fr': '[DÉMO] Information fictive ($scope).',
            'summary_mg': null,
          },
      ],
    };

class FakeReferenceApi implements ReferenceApi {
  bool offline = false;
  Object? error;
  Map<String, dynamic> signs = demoSignCodes();
  Map<String, dynamic> consent = demoConsentInformation();
  Map<String, dynamic> contents = demoPublishedContents();
  final List<String> calls = [];

  Future<Map<String, dynamic>> _answer(String call, Map<String, dynamic> body) async {
    calls.add(call);
    if (offline) throw const NetworkException('hors ligne (fake)');
    final e = error;
    if (e != null) throw e;
    return body;
  }

  @override
  Future<Map<String, dynamic>> signCodes(String module) =>
      _answer('sign-codes:$module', signs);

  @override
  Future<Map<String, dynamic>> consentInformation() =>
      _answer('consent-information', consent);

  @override
  Future<Map<String, dynamic>> publishedContents(String module) =>
      _answer('contents:$module', contents);
}

/// Forme réelle de `GET /contents/published` (contenus fictifs).
Map<String, dynamic> demoPublishedContents() => {
      'items': [
        {
          'id': 'c-1',
          'code': 'MSG_DEMO_INFO_ANC',
          'module': 'reny',
          'language': 'fr',
          'title': '[DÉMO] Consultations prénatales',
          'body': '[DÉMO] Contenu fictif sur les consultations.',
          'audio_url': null,
          'version': 1,
          'status': 'demo',
        },
        {
          'id': 'c-2',
          'code': 'MSG_DEMO_INFO_ANC',
          'module': 'reny',
          'language': 'mg',
          'title': '[DÉMO] Fitsaboana',
          'body': '[DÉMO] Votoatiny fictif.',
          'audio_url': null,
          'version': 1,
          'status': 'demo',
        },
        {
          'id': 'c-3',
          'code': 'MSG_DEMO_TANORA',
          'module': 'tanora',
          'language': 'fr',
          'title': '[DÉMO] Autre module',
          'body': '[DÉMO] Ne doit pas apparaître pour RENY.',
          'audio_url': null,
          'version': 1,
          'status': 'demo',
        },
      ],
      'total': 3,
    };

class FakeAuthApi implements AuthApi {
  int refreshCalls = 0;
  bool refreshRejected = false;
  bool offline = false;

  @override
  Future<TokenPair> login(String login, String password) async {
    if (offline) throw const NetworkException('hors ligne');
    if (password != 'secret') throw const ApiException(401, 'Identifiants invalides');
    return TokenPair.fromJson({
      'access_token': 'access-0',
      'refresh_token': 'refresh-0',
      'expires_in': 900,
      'refresh_expires_in': 86400,
    });
  }

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    refreshCalls++;
    if (offline) throw const NetworkException('hors ligne');
    if (refreshRejected) throw const ApiException(401, 'refresh invalide');
    return TokenPair.fromJson({
      'access_token': 'access-$refreshCalls',
      'refresh_token': 'refresh-$refreshCalls',
      'expires_in': 900,
      'refresh_expires_in': 86400,
    });
  }

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  Future<UserProfile> me(String accessToken) async => UserProfile.fromJson({
        'id': 'user-ac-1',
        'login': 'ac.demo',
        'role': 'community_agent',
        'site_id': 'site-demo-1',
        'is_active': true,
      });
}

const testUser = UserProfile(
  id: 'user-ac-1',
  login: 'ac.demo',
  role: 'community_agent',
  siteId: 'site-demo-1',
  isActive: true,
);
