/// Énumérations du contrat d'API (docs/api-contrat.md), sérialisées en
/// `snake_case` comme côté serveur.
library;

/// Entités synchronisables (section 8). `alert` et `site` sont en lecture
/// seule (pull uniquement).
enum SyncEntity {
  beneficiary('beneficiary'),
  beneficiaryIdentity('beneficiary_identity'),
  consent('consent'),
  pregnancy('pregnancy'),
  ancVisit('anc_visit'),
  referral('referral'),
  alert('alert'),
  site('site');

  const SyncEntity(this.wire);
  final String wire;

  /// Seules ces entités peuvent être poussées par le client.
  bool get isWritable => this != SyncEntity.alert && this != SyncEntity.site;

  static SyncEntity? fromWire(String value) {
    for (final e in values) {
      if (e.wire == value) return e;
    }
    return null;
  }
}

enum SyncOp {
  upsert('upsert'),
  delete('delete');

  const SyncOp(this.wire);
  final String wire;

  static SyncOp fromWire(String v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => SyncOp.upsert);
}

enum ConsentScope {
  reny('reny'),
  tanora('tanora'),
  reminders('reminders'),
  voiceProcessing('voice_processing');

  const ConsentScope(this.wire);
  final String wire;

  static ConsentScope? fromWire(String? v) {
    for (final e in values) {
      if (e.wire == v) return e;
    }
    return null;
  }
}

enum ConsentMethod {
  oral('oral'),
  written('written');

  const ConsentMethod(this.wire);
  final String wire;
}

enum PreferredChannel {
  sms('sms'),
  ivr('ivr'),
  acVisit('ac_visit'),
  none('none');

  const PreferredChannel(this.wire);
  final String wire;

  static PreferredChannel fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => PreferredChannel.none);
}

enum PregnancyStatus {
  active('active'),
  delivered('delivered'),
  ended('ended'),
  transferred('transferred');

  const PregnancyStatus(this.wire);
  final String wire;
}

enum DatesConfirmedBy {
  acDeclared('ac_declared'),
  healthWorker('health_worker'),
  ultrasound('ultrasound');

  const DatesConfirmedBy(this.wire);
  final String wire;
}

enum AncVisitStatus {
  planned('planned'),
  done('done'),
  missed('missed'),
  cancelled('cancelled');

  const AncVisitStatus(this.wire);
  final String wire;

  static AncVisitStatus fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => AncVisitStatus.planned);
}

enum ReferralStatus {
  proposed('proposed'),
  accepted('accepted'),
  arrived('arrived'),
  transferred('transferred'),
  notCompleted('not_completed');

  const ReferralStatus(this.wire);
  final String wire;

  static ReferralStatus? fromWire(String? v) {
    for (final e in values) {
      if (e.wire == v) return e;
    }
    return null;
  }
}

/// Types de site (contrat, section 2).
enum SiteKind {
  csb('csb'),
  referenceFacility('reference_facility'),
  communityZone('community_zone');

  const SiteKind(this.wire);
  final String wire;

  static SiteKind? fromWire(String? v) {
    for (final e in values) {
      if (e.wire == v) return e;
    }
    return null;
  }
}

/// Statuts d'une entrée d'outbox (propre au client).
enum OutboxStatus {
  /// À envoyer (éventuellement après un délai de backoff).
  pending('pending'),

  /// Refusée par le serveur : nécessite une action de l'utilisateur.
  rejected('rejected');

  const OutboxStatus(this.wire);
  final String wire;
}
