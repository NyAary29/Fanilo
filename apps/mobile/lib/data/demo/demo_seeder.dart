import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../domain/enums.dart';
import '../local/database.dart';
import '../local/entity_store.dart';
import '../reference/reference_repository.dart';

/// Données de démonstration **fictives**, comme si elles venaient du serveur
/// (version 1, aucune entrée d'outbox). Réservé au mode debug, pour montrer
/// les écrans sans backend. Aucune personne réelle.
class DemoSeeder {
  DemoSeeder(this.db, {DateTime Function()? now, Uuid? uuid})
      : _now = now ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  final AppDatabase db;
  final DateTime Function() _now;
  final Uuid _uuid;

  String _date(int offsetDays) =>
      _now().add(Duration(days: offsetDays)).toIso8601String().substring(0, 10);

  Future<void> seed({String? siteId}) async {
    final store = EntityStore(db);
    final ts = _now().toUtc().toIso8601String();
    await db.transaction(() async {
      await store.applyServer(SyncEntity.site, 'site-demo-csb', 1, null, {
        'name': 'CSB fictif (DÉMO)',
        'kind': 'csb',
        'code': 'CSB-DEMO',
        'parent_site_id': null,
        'is_active': true,
      });
      await _seedReferenceIfMissing();
      for (var i = 1; i <= 2; i++) {
        final b = _uuid.v4();
        await store.applyServer(SyncEntity.beneficiary, b, 1, null, {
          'code': 'FAN-DEMO0$i',
          'site_id': siteId,
          'birth_year': 1998 + i,
          'preferred_channel': 'ac_visit',
          'created_at': ts,
          'updated_at': ts,
        });
        await store.applyServer(SyncEntity.beneficiaryIdentity, b, 1, null, {
          'beneficiary_id': b,
          'display_name': 'Personne fictive $i (DÉMO)',
          'phone': null,
          'village': 'Village fictif',
        });
        await store.applyServer(SyncEntity.consent, _uuid.v4(), 1, null, {
          'beneficiary_id': b,
          'scope': 'reny',
          'method': 'oral',
          'information_version': 'demo-0.1',
          'collected_at': ts,
        });
        final p = _uuid.v4();
        await store.applyServer(SyncEntity.pregnancy, p, 1, null, {
          'beneficiary_id': b,
          'status': 'active',
          'lmp_date': _date(-90 * i),
          'estimated_due_date': null,
          'dates_confirmed_by': 'ac_declared',
          'created_at': ts,
        });
        // Calendrier FICTIF : en production, il vient du serveur (calendrier
        // configuré et validé), jamais de l'application.
        for (var s = 1; s <= 3; s++) {
          await store.applyServer(SyncEntity.ancVisit, _uuid.v4(), 1, null, {
            'pregnancy_id': p,
            'sequence': s,
            'scheduled_date': _date((s - 2) * 3 + i),
            'status': s == 1 ? 'done' : 'planned',
            'done_date': s == 1 ? _date(-5) : null,
            'site_id': siteId,
          });
        }
        await store.applyServer(SyncEntity.referral, _uuid.v4(), 1, null, {
          'beneficiary_id': b,
          'alert_id': null,
          'from_site_id': siteId,
          'to_site_id': 'site-demo-csb',
          'status': i == 1 ? 'proposed' : 'accepted',
          'reason': null,
          'outcome_note': null,
          'updated_at': ts,
        });
        if (i == 1) {
          await store.applyServer(SyncEntity.alert, _uuid.v4(), 1, null, {
            'beneficiary_id': b,
            'rule_id': 'DEMO_RULE_01',
            'ruleset_version': '0.1.0',
            'severity': 'urgent',
            'status': 'open',
            'due_at': _now().toUtc().add(const Duration(hours: 4)).toIso8601String(),
            'is_demo': true,
            'created_at': ts,
          });
        }
      }
    });
  }

  /// Référentiels fictifs, seulement si aucune copie serveur n'existe
  /// (marqués `is_demo` / `status: demo` : le bandeau DÉMO reste affiché).
  Future<void> _seedReferenceIfMissing() async {
    Future<void> put(String key, Map<String, dynamic> json) async {
      final existing = await (db.select(db.referenceCache)
            ..where((r) => r.key.equals(key)))
          .getSingleOrNull();
      if (existing != null) return;
      await db.into(db.referenceCache).insert(ReferenceCacheCompanion.insert(
          key: key, json: jsonEncode(json), fetchedAt: DateTime.utc(2000)));
    }

    await put(ReferenceRepository.signCodesKey('reny'), {
      'catalog_id': 'fanilo-demo-signs',
      'version': '0.0.0-local',
      'status': 'demo',
      'is_demo': true,
      'items': [
        for (var n = 1; n <= 3; n++)
          {
            'code': 'SIGN_DEMO_0$n',
            'label_fr': '[DÉMO] Signe fictif n° $n',
            'label_mg': null,
            'modules': ['reny'],
          },
      ],
    });
    await put(ReferenceRepository.consentInformationKey, {
      'items': [
        {
          'scope': 'reny',
          'version': 'demo-0.1',
          'status': 'demo',
          'summary_fr': '[DÉMO] Information fictive de démonstration.',
          'summary_mg': null,
        },
      ],
    });
  }
}
