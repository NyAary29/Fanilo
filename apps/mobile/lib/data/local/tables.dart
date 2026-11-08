import 'package:drift/drift.dart';

/// Tables miroir des entités synchronisables (contrat, sections 3, 4, 7, 8).
///
/// Les dates (`YYYY-MM-DD`) et horodatages (ISO 8601 UTC) sont stockés en
/// texte, tels qu'échangés avec l'API, pour éviter toute conversion de fuseau.
/// `version` = dernière version serveur connue (0 si jamais synchronisée).

mixin SyncColumns on Table {
  IntColumn get version => integer().withDefault(const Constant(0))();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();
}

@DataClassName('BeneficiaryRow')
class Beneficiaries extends Table with SyncColumns {
  TextColumn get id => text()();

  /// `FAN-XXXXXX`, attribué par le serveur (null tant que non synchronisé).
  TextColumn get code => text().nullable()();
  TextColumn get siteId => text().nullable()();
  IntColumn get birthYear => integer().nullable()();
  TextColumn get preferredChannel =>
      text().withDefault(const Constant('none'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Identité séparée du suivi. L'identifiant de synchronisation est
/// `beneficiary_id` (le contrat ne définit pas d'`id` propre).
@DataClassName('BeneficiaryIdentityRow')
class BeneficiaryIdentities extends Table with SyncColumns {
  TextColumn get beneficiaryId => text()();
  TextColumn get displayName => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get village => text().nullable()();

  @override
  Set<Column> get primaryKey => {beneficiaryId};
}

@DataClassName('ConsentRow')
class Consents extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get beneficiaryId => text()();
  TextColumn get scope => text()();
  TextColumn get method => text()();
  TextColumn get informationVersion => text()();
  TextColumn get collectedByUserId => text().nullable()();
  TextColumn get collectedAt => text()();
  TextColumn get withdrawnAt => text().nullable()();
  TextColumn get withdrawnByUserId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PregnancyRow')
class Pregnancies extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get beneficiaryId => text()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get lmpDate => text().nullable()();
  TextColumn get estimatedDueDate => text().nullable()();
  TextColumn get datesConfirmedBy =>
      text().withDefault(const Constant('ac_declared'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AncVisitRow')
class AncVisits extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get pregnancyId => text()();
  IntColumn get sequence => integer()();
  TextColumn get scheduledDate => text()();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  TextColumn get doneDate => text().nullable()();
  TextColumn get siteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReferralRow')
class Referrals extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get beneficiaryId => text()();
  TextColumn get alertId => text().nullable()();
  TextColumn get fromSiteId => text().nullable()();
  TextColumn get toSiteId => text()();
  TextColumn get status => text().withDefault(const Constant('proposed'))();
  TextColumn get reason => text().nullable()();
  TextColumn get outcomeNote => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Alertes : lecture seule (pull uniquement).
@DataClassName('AlertRow')
class Alerts extends Table {
  TextColumn get id => text()();
  TextColumn get beneficiaryId => text().nullable()();
  TextColumn get interactionId => text().nullable()();
  TextColumn get ruleId => text().nullable()();
  TextColumn get rulesetVersion => text().nullable()();
  TextColumn get severity => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get recipientUserId => text().nullable()();
  TextColumn get backupUserId => text().nullable()();
  TextColumn get dueAt => text().nullable()();
  TextColumn get acknowledgedAt => text().nullable()();
  TextColumn get resolvedAt => text().nullable()();
  BoolColumn get isDemo => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// File d'attente des modifications locales à pousser (`/sync/push`).
@DataClassName('OutboxRow')
class Outbox extends Table {
  /// UUID v4 généré côté client : clé d'idempotence côté serveur.
  TextColumn get changeId => text()();
  TextColumn get entity => text()();
  TextColumn get op => text()();

  /// Identifiant de l'entité (colonne `id` du contrat).
  TextColumn get entityId => text().named('id')();
  IntColumn get baseVersion => integer().nullable()();

  /// Charge utile JSON.
  TextColumn get data => text()();

  /// `pending` ou `rejected`.
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  /// Numéro d'ordre monotone (ordre d'envoi = ordre de saisie).
  IntColumn get seq => integer()();
  DateTimeColumn get createdAt => dateTime()();

  /// Prochaine tentative autorisée (backoff), null = immédiatement.
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {changeId};
}

/// Modifications locales écartées lors d'un conflit, conservées pour revue.
@DataClassName('SyncConflictRow')
class SyncConflicts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get changeId => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get op => text()();
  IntColumn get baseVersion => integer().nullable()();
  TextColumn get localData => text()();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get serverData => text().nullable()();
  DateTimeColumn get detectedAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  /// `reviewed` (version serveur gardée) ou `reapplied` (version locale renvoyée).
  TextColumn get resolution => text().nullable()();
}

/// État de synchronisation clé/valeur (curseur, identifiant d'appareil…).
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
