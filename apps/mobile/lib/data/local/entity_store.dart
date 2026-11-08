import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'database.dart';

/// Applique l'état serveur dans les tables miroir, et lit/écrit les versions.
///
/// Toutes les conversions JSON (contrat, `snake_case`) ↔ lignes locales sont
/// centralisées ici.
class EntityStore {
  EntityStore(this.db);
  final AppDatabase db;

  /// Insère ou remplace la ligne locale par l'état serveur.
  ///
  /// Si [deletedAt] est renseigné sans [data], seule la suppression logique
  /// est appliquée (si la ligne existe).
  Future<void> applyServer(
    SyncEntity entity,
    String id,
    int version,
    String? deletedAt,
    Map<String, dynamic>? data,
  ) async {
    if (data == null) {
      if (deletedAt != null) await markDeleted(entity, id, version, deletedAt);
      return;
    }
    final d = {...data, 'version': version, 'deleted_at': deletedAt ?? data['deleted_at']};
    switch (entity) {
      case SyncEntity.beneficiary:
        await db.into(db.beneficiaries).insertOnConflictUpdate(BeneficiariesCompanion.insert(
              id: id,
              code: Value(d['code'] as String?),
              siteId: Value(d['site_id'] as String?),
              birthYear: Value((d['birth_year'] as num?)?.toInt()),
              preferredChannel: Value(d['preferred_channel'] as String? ?? 'none'),
              version: Value(version),
              createdAt: Value(d['created_at'] as String?),
              updatedAt: Value(d['updated_at'] as String?),
              deletedAt: Value(d['deleted_at'] as String?),
            ));
      case SyncEntity.beneficiaryIdentity:
        await db.into(db.beneficiaryIdentities).insertOnConflictUpdate(
            BeneficiaryIdentitiesCompanion.insert(
              beneficiaryId: d['beneficiary_id'] as String? ?? id,
              displayName: d['display_name'] as String? ?? '',
              phone: Value(d['phone'] as String?),
              village: Value(d['village'] as String?),
              version: Value(version),
              createdAt: Value(d['created_at'] as String?),
              updatedAt: Value(d['updated_at'] as String?),
              deletedAt: Value(d['deleted_at'] as String?),
            ));
      case SyncEntity.consent:
        await db.into(db.consents).insertOnConflictUpdate(ConsentsCompanion.insert(
              id: id,
              beneficiaryId: d['beneficiary_id'] as String,
              scope: d['scope'] as String,
              method: d['method'] as String? ?? 'oral',
              informationVersion: d['information_version'] as String? ?? '',
              collectedByUserId: Value(d['collected_by_user_id'] as String?),
              collectedAt: d['collected_at'] as String? ?? '',
              withdrawnAt: Value(d['withdrawn_at'] as String?),
              withdrawnByUserId: Value(d['withdrawn_by_user_id'] as String?),
              version: Value(version),
              createdAt: Value(d['created_at'] as String?),
              updatedAt: Value(d['updated_at'] as String?),
              deletedAt: Value(d['deleted_at'] as String?),
            ));
      case SyncEntity.pregnancy:
        await db.into(db.pregnancies).insertOnConflictUpdate(PregnanciesCompanion.insert(
              id: id,
              beneficiaryId: d['beneficiary_id'] as String,
              status: Value(d['status'] as String? ?? 'active'),
              lmpDate: Value(d['lmp_date'] as String?),
              estimatedDueDate: Value(d['estimated_due_date'] as String?),
              datesConfirmedBy: Value(d['dates_confirmed_by'] as String? ?? 'ac_declared'),
              version: Value(version),
              createdAt: Value(d['created_at'] as String?),
              updatedAt: Value(d['updated_at'] as String?),
              deletedAt: Value(d['deleted_at'] as String?),
            ));
      case SyncEntity.ancVisit:
        await db.into(db.ancVisits).insertOnConflictUpdate(AncVisitsCompanion.insert(
              id: id,
              pregnancyId: d['pregnancy_id'] as String,
              sequence: (d['sequence'] as num?)?.toInt() ?? 0,
              scheduledDate: d['scheduled_date'] as String? ?? '',
              status: Value(d['status'] as String? ?? 'planned'),
              doneDate: Value(d['done_date'] as String?),
              siteId: Value(d['site_id'] as String?),
              version: Value(version),
              createdAt: Value(d['created_at'] as String?),
              updatedAt: Value(d['updated_at'] as String?),
              deletedAt: Value(d['deleted_at'] as String?),
            ));
      case SyncEntity.referral:
        await db.into(db.referrals).insertOnConflictUpdate(ReferralsCompanion.insert(
              id: id,
              beneficiaryId: d['beneficiary_id'] as String,
              alertId: Value(d['alert_id'] as String?),
              fromSiteId: Value(d['from_site_id'] as String?),
              toSiteId: d['to_site_id'] as String? ?? '',
              status: Value(d['status'] as String? ?? 'proposed'),
              reason: Value(d['reason'] as String?),
              outcomeNote: Value(d['outcome_note'] as String?),
              version: Value(version),
              createdAt: Value(d['created_at'] as String?),
              updatedAt: Value(d['updated_at'] as String?),
              deletedAt: Value(d['deleted_at'] as String?),
            ));
      case SyncEntity.alert:
        await db.into(db.alerts).insertOnConflictUpdate(AlertsCompanion.insert(
              id: id,
              beneficiaryId: Value(d['beneficiary_id'] as String?),
              interactionId: Value(d['interaction_id'] as String?),
              ruleId: Value(d['rule_id'] as String?),
              rulesetVersion: Value(d['ruleset_version']?.toString()),
              severity: Value(d['severity'] as String?),
              status: Value(d['status'] as String? ?? 'open'),
              recipientUserId: Value(d['recipient_user_id'] as String?),
              backupUserId: Value(d['backup_user_id'] as String?),
              dueAt: Value(d['due_at'] as String?),
              acknowledgedAt: Value(d['acknowledged_at'] as String?),
              resolvedAt: Value(d['resolved_at'] as String?),
              isDemo: Value(d['is_demo'] as bool? ?? true),
              createdAt: Value(d['created_at'] as String?),
              version: Value(version),
              deletedAt: Value(d['deleted_at'] as String?),
            ));
    }
  }

  Future<void> markDeleted(
      SyncEntity entity, String id, int version, String deletedAt) async {
    final sql = 'UPDATE ${_table(entity)} SET deleted_at = ?, version = ? '
        'WHERE ${_idColumn(entity)} = ?';
    await db.customUpdate(sql,
        variables: [Variable(deletedAt), Variable(version), Variable(id)],
        updates: {_tableInfo(entity)});
  }

  Future<int?> currentVersion(SyncEntity entity, String id) async {
    final row = await db.customSelect(
      'SELECT version FROM ${_table(entity)} WHERE ${_idColumn(entity)} = ?',
      variables: [Variable(id)],
      readsFrom: {_tableInfo(entity)},
    ).getSingleOrNull();
    return row?.read<int>('version');
  }

  Future<void> setVersion(SyncEntity entity, String id, int version) async {
    await db.customUpdate(
      'UPDATE ${_table(entity)} SET version = ? WHERE ${_idColumn(entity)} = ?',
      variables: [Variable(version), Variable(id)],
      updates: {_tableInfo(entity)},
    );
  }

  String _table(SyncEntity e) => _tableInfo(e).actualTableName;

  String _idColumn(SyncEntity e) =>
      e == SyncEntity.beneficiaryIdentity ? 'beneficiary_id' : 'id';

  TableInfo<Table, dynamic> _tableInfo(SyncEntity e) => switch (e) {
        SyncEntity.beneficiary => db.beneficiaries,
        SyncEntity.beneficiaryIdentity => db.beneficiaryIdentities,
        SyncEntity.consent => db.consents,
        SyncEntity.pregnancy => db.pregnancies,
        SyncEntity.ancVisit => db.ancVisits,
        SyncEntity.referral => db.referrals,
        SyncEntity.alert => db.alerts,
      };
}
