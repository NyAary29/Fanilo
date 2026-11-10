import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/enums.dart';
import '../../domain/referral_rules.dart';
import '../../domain/registration.dart';
import '../api/dto.dart';
import '../local/database.dart';
import 'outbox_repository.dart';

class NoActiveRenyConsentException implements Exception {
  const NoActiveRenyConsentException();
  @override
  String toString() =>
      'Consentement RENY actif requis avant de déclarer une grossesse.';
}

/// Dates de grossesse incohérentes (même garde-fou de saisie que le
/// serveur, non clinique) : dernières règles dans le futur ou trop
/// anciennes, terme prévu avant les dernières règles.
enum PregnancyDatesError { lmpInFuture, lmpTooOld, dueBeforeLmp }

class InvalidPregnancyDatesException implements Exception {
  const InvalidPregnancyDatesException(this.error);
  final PregnancyDatesError error;
  @override
  String toString() => 'Dates de grossesse incohérentes : ${error.name}';
}

class InvalidStateException implements Exception {
  const InvalidStateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Écritures et lectures métier sur la base locale.
///
/// Chaque écriture met à jour la table miroir **et** ajoute une entrée dans
/// l'outbox dans la même transaction : l'application reste pleinement
/// utilisable hors ligne.
class LocalRepository {
  LocalRepository(this.db, this.outbox, {Uuid? uuid, DateTime Function()? now})
      : _uuid = uuid ?? const Uuid(),
        _now = now ?? DateTime.now;

  final AppDatabase db;
  final OutboxRepository outbox;
  final Uuid _uuid;
  final DateTime Function() _now;

  String _ts() => _now().toUtc().toIso8601String();
  String _today() => _now().toIso8601String().substring(0, 10);

  // ============================================================ enregistrement

  /// Enregistre un bénéficiaire. Le consentement est vérifié **avant** toute
  /// écriture ([ConsentRequiredException] sinon).
  ///
  /// Ordre dans l'outbox : bénéficiaire, consentement(s), identité.
  Future<String> registerBeneficiary(
      RegistrationDraft draft, UserProfile user) async {
    draft.validate();
    final consent = draft.consent!;
    final identity = draft.identity!;
    final ben = draft.beneficiary ??
        const BeneficiaryInput(preferredChannel: PreferredChannel.none);
    final beneficiaryId = _uuid.v4();
    final now = _ts();

    await db.transaction(() async {
      final b = BeneficiariesCompanion.insert(
        id: beneficiaryId,
        siteId: Value(user.siteId),
        birthYear: Value(ben.birthYear),
        preferredChannel: Value(ben.preferredChannel.wire),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      await db.into(db.beneficiaries).insert(b);
      await outbox.enqueue(
        entity: SyncEntity.beneficiary,
        op: SyncOp.upsert,
        id: beneficiaryId,
        baseVersion: null,
        data: {
          'id': beneficiaryId,
          'site_id': user.siteId,
          'birth_year': ben.birthYear,
          'preferred_channel': ben.preferredChannel.wire,
        },
      );

      final scopes = consent.scopes.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      for (final scope in scopes) {
        final consentId = _uuid.v4();
        final row = ConsentRow(
          id: consentId,
          beneficiaryId: beneficiaryId,
          scope: scope.wire,
          method: consent.method!.wire,
          informationVersion: consent.versionFor(scope)!,
          collectedByUserId: user.id,
          collectedAt: now,
          withdrawnAt: null,
          withdrawnByUserId: null,
          version: 0,
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
        );
        await db.into(db.consents).insert(row);
        await outbox.enqueue(
          entity: SyncEntity.consent,
          op: SyncOp.upsert,
          id: consentId,
          baseVersion: null,
          data: consentJson(row),
        );
      }

      final idRow = BeneficiaryIdentityRow(
        beneficiaryId: beneficiaryId,
        displayName: identity.displayName.trim(),
        phone: _blankToNull(identity.phone),
        village: _blankToNull(identity.village),
        version: 0,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );
      await db.into(db.beneficiaryIdentities).insert(idRow);
      await outbox.enqueue(
        entity: SyncEntity.beneficiaryIdentity,
        op: SyncOp.upsert,
        id: beneficiaryId,
        baseVersion: null,
        data: identityJson(idRow),
      );
    });
    return beneficiaryId;
  }

  Future<void> withdrawConsent(String consentId, UserProfile user) async {
    await db.transaction(() async {
      final row = await (db.select(db.consents)
            ..where((c) => c.id.equals(consentId)))
          .getSingle();
      if (row.withdrawnAt != null) return;
      final updated =
          row.copyWith(withdrawnAt: Value(_ts()), withdrawnByUserId: Value(user.id), updatedAt: Value(_ts()));
      await db.update(db.consents).replace(updated);
      await outbox.enqueue(
        entity: SyncEntity.consent,
        op: SyncOp.upsert,
        id: consentId,
        baseVersion: _base(row.version),
        data: consentJson(updated),
      );
    });
  }

  // ============================================================ grossesse / CPN

  Future<bool> hasActiveRenyConsent(String beneficiaryId) async {
    final rows = await (db.select(db.consents)
          ..where((c) =>
              c.beneficiaryId.equals(beneficiaryId) &
              c.scope.equals(ConsentScope.reny.wire) &
              c.withdrawnAt.isNull() &
              c.deletedAt.isNull()))
        .get();
    return rows.isNotEmpty;
  }

  /// Déclare une grossesse. Le calendrier CPN est généré par le serveur
  /// (calendrier configuré) et arrivera au prochain pull.
  Future<String> createPregnancy({
    required String beneficiaryId,
    String? lmpDate,
    String? estimatedDueDate,
    DatesConfirmedBy confirmedBy = DatesConfirmedBy.acDeclared,
  }) async {
    if (!await hasActiveRenyConsent(beneficiaryId)) {
      throw const NoActiveRenyConsentException();
    }
    checkPregnancyDates(lmpDate, estimatedDueDate);
    final id = _uuid.v4();
    final now = _ts();
    await db.transaction(() async {
      final row = PregnancyRow(
        id: id,
        beneficiaryId: beneficiaryId,
        status: PregnancyStatus.active.wire,
        lmpDate: lmpDate,
        estimatedDueDate: estimatedDueDate,
        datesConfirmedBy: confirmedBy.wire,
        version: 0,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );
      await db.into(db.pregnancies).insert(row);
      await outbox.enqueue(
        entity: SyncEntity.pregnancy,
        op: SyncOp.upsert,
        id: id,
        baseVersion: null,
        data: pregnancyJson(row),
      );
    });
    return id;
  }

  /// Garde-fou de saisie identique à celui du serveur (`_check_dates`) :
  /// évite un refus prévisible. Ne calcule rien.
  void checkPregnancyDates(String? lmpDate, String? estimatedDueDate) {
    final today = DateTime.parse(_today());
    final lmp = lmpDate == null ? null : DateTime.parse(lmpDate);
    final due = estimatedDueDate == null ? null : DateTime.parse(estimatedDueDate);
    if (lmp != null && lmp.isAfter(today)) {
      throw const InvalidPregnancyDatesException(PregnancyDatesError.lmpInFuture);
    }
    if (lmp != null && lmp.isBefore(today.subtract(const Duration(days: 320)))) {
      throw const InvalidPregnancyDatesException(PregnancyDatesError.lmpTooOld);
    }
    if (lmp != null && due != null && !due.isAfter(lmp)) {
      throw const InvalidPregnancyDatesException(PregnancyDatesError.dueBeforeLmp);
    }
  }

  /// Renseigne ou corrige les dates d'une grossesse **active** (dernières
  /// règles, terme prévu saisi par l'AC, source des dates). Part par l'outbox
  /// (upsert `pregnancy`). Si la grossesse n'a pas encore de visites, le
  /// serveur génère alors le calendrier CPN, reçu au pull suivant :
  /// l'application ne calcule ni le calendrier ni le terme.
  Future<void> updatePregnancyDates(
    String pregnancyId, {
    required String? lmpDate,
    required String? estimatedDueDate,
    required DatesConfirmedBy confirmedBy,
  }) async {
    checkPregnancyDates(lmpDate, estimatedDueDate);
    await db.transaction(() async {
      final row = await (db.select(db.pregnancies)
            ..where((p) => p.id.equals(pregnancyId)))
          .getSingle();
      if (row.status != PregnancyStatus.active.wire || row.deletedAt != null) {
        throw const InvalidStateException('Seule une grossesse en cours peut être modifiée.');
      }
      final updated = row.copyWith(
        lmpDate: Value(lmpDate),
        estimatedDueDate: Value(estimatedDueDate),
        datesConfirmedBy: confirmedBy.wire,
        updatedAt: Value(_ts()),
      );
      await db.update(db.pregnancies).replace(updated);
      await outbox.enqueue(
        entity: SyncEntity.pregnancy,
        op: SyncOp.upsert,
        id: pregnancyId,
        baseVersion: _base(row.version),
        data: pregnancyJson(updated),
      );
    });
  }

  /// Marque une CPN réalisée ou manquée (seulement depuis `planned`).
  Future<void> markAncVisit(String visitId, AncVisitStatus to) async {
    if (to != AncVisitStatus.done && to != AncVisitStatus.missed) {
      throw ArgumentError('Seuls « réalisée » et « manquée » sont permis');
    }
    await db.transaction(() async {
      final row = await (db.select(db.ancVisits)
            ..where((v) => v.id.equals(visitId)))
          .getSingle();
      if (row.status != AncVisitStatus.planned.wire) {
        throw const InvalidStateException('Cette visite n\'est plus planifiée.');
      }
      final updated = row.copyWith(
        status: to.wire,
        doneDate: Value(to == AncVisitStatus.done ? _today() : null),
        updatedAt: Value(_ts()),
      );
      await db.update(db.ancVisits).replace(updated);
      await outbox.enqueue(
        entity: SyncEntity.ancVisit,
        op: SyncOp.upsert,
        id: visitId,
        baseVersion: _base(row.version),
        data: ancVisitJson(updated),
      );
    });
  }

  // ============================================================ références

  Future<void> transitionReferral(
    String referralId,
    ReferralStatus to, {
    String? reason,
    String? outcomeNote,
  }) async {
    await db.transaction(() async {
      final row = await (db.select(db.referrals)
            ..where((r) => r.id.equals(referralId)))
          .getSingle();
      final from = ReferralStatus.fromWire(row.status);
      if (from == null) {
        throw InvalidStateException('Statut inconnu : ${row.status}');
      }
      ReferralRules.validate(from, to, reason: reason);
      final updated = row.copyWith(
        status: to.wire,
        reason: reason != null ? Value(reason.trim()) : const Value.absent(),
        outcomeNote:
            outcomeNote != null ? Value(outcomeNote.trim()) : const Value.absent(),
        updatedAt: Value(_ts()),
      );
      await db.update(db.referrals).replace(updated);
      await outbox.enqueue(
        entity: SyncEntity.referral,
        op: SyncOp.upsert,
        id: referralId,
        baseVersion: _base(row.version),
        data: referralJson(updated),
      );
    });
  }

  /// Crée une référence (statut `proposed`, contrat section 7) vers un site
  /// synchronisé. `from_site_id` = site de la bénéficiaire, à défaut celui de
  /// l'utilisateur. Envoyée par l'outbox comme les autres entités.
  Future<String> createReferral({
    required String beneficiaryId,
    required String toSiteId,
    String? reason,
    String? alertId,
    required UserProfile user,
  }) async {
    final id = _uuid.v4();
    final now = _ts();
    await db.transaction(() async {
      final ben = await (db.select(db.beneficiaries)
            ..where((b) => b.id.equals(beneficiaryId)))
          .getSingleOrNull();
      if (ben == null || ben.deletedAt != null) {
        throw const InvalidStateException('Bénéficiaire introuvable.');
      }
      final site = await (db.select(db.sites)..where((s) => s.id.equals(toSiteId)))
          .getSingleOrNull();
      if (site == null || site.deletedAt != null || !site.isActive) {
        throw const InvalidStateException('Site destinataire inconnu ou inactif.');
      }
      final row = ReferralRow(
        id: id,
        beneficiaryId: beneficiaryId,
        alertId: alertId,
        fromSiteId: ben.siteId ?? user.siteId,
        toSiteId: toSiteId,
        status: ReferralStatus.proposed.wire,
        reason: _blankToNull(reason),
        outcomeNote: null,
        version: 0,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );
      await db.into(db.referrals).insert(row);
      await outbox.enqueue(
        entity: SyncEntity.referral,
        op: SyncOp.upsert,
        id: id,
        baseVersion: null,
        data: referralJson(row),
      );
    });
    return id;
  }

  /// Sites actifs pouvant recevoir une référence : CSB et structures de
  /// référence d'abord, puis zones communautaires, par nom.
  Stream<List<SiteRow>> watchReferralSites({String? excludeSiteId}) =>
      (db.select(db.sites)
            ..where((s) => s.isActive.equals(true) & s.deletedAt.isNull()))
          .watch()
          .map((rows) {
        final list = rows.where((s) => s.id != excludeSiteId).toList();
        int rank(SiteRow s) => switch (SiteKind.fromWire(s.kind)) {
              SiteKind.csb => 0,
              SiteKind.referenceFacility => 1,
              SiteKind.communityZone => 2,
              null => 3,
            };
        list.sort((a, b) {
          final r = rank(a).compareTo(rank(b));
          return r != 0 ? r : a.name.compareTo(b.name);
        });
        return list;
      });

  Stream<Map<String, SiteRow>> watchSitesById() =>
      db.select(db.sites).watch().map((rows) => {for (final r in rows) r.id: r});

  // ============================================================ conflits

  Stream<List<SyncConflictRow>> watchOpenConflicts() => (db.select(db.syncConflicts)
        ..where((c) => c.resolvedAt.isNull())
        ..orderBy([(c) => OrderingTerm.desc(c.detectedAt)]))
      .watch();

  /// Garde la version serveur (déjà appliquée localement).
  Future<void> markConflictReviewed(int conflictId) =>
      (db.update(db.syncConflicts)..where((c) => c.id.equals(conflictId))).write(
          SyncConflictsCompanion(
              resolvedAt: Value(_now().toUtc()),
              resolution: const Value('reviewed')));

  /// Renvoie la version locale, en se basant sur la version serveur actuelle.
  /// Le serveur reste juge (nouveau conflit si l'état a encore changé).
  Future<void> reapplyLocal(int conflictId) async {
    await db.transaction(() async {
      final c = await (db.select(db.syncConflicts)
            ..where((t) => t.id.equals(conflictId)))
          .getSingle();
      final entity = SyncEntity.fromWire(c.entity);
      if (entity == null || !entity.isWritable) {
        throw InvalidStateException('Entité non modifiable : ${c.entity}');
      }
      final data = (jsonDecode(c.localData) as Map).cast<String, dynamic>();
      await outbox.enqueue(
        entity: entity,
        op: SyncOp.fromWire(c.op),
        id: c.entityId,
        baseVersion: c.serverVersion,
        data: data,
      );
      await (db.update(db.syncConflicts)..where((t) => t.id.equals(conflictId)))
          .write(SyncConflictsCompanion(
              resolvedAt: Value(_now().toUtc()),
              resolution: const Value('reapplied')));
    });
  }

  // ============================================================ lectures

  Stream<List<BeneficiaryRow>> watchBeneficiaries() => (db.select(db.beneficiaries)
        ..where((b) => b.deletedAt.isNull())
        ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
      .watch();

  Stream<Map<String, BeneficiaryIdentityRow>> watchIdentities() =>
      (db.select(db.beneficiaryIdentities)..where((i) => i.deletedAt.isNull()))
          .watch()
          .map((rows) => {for (final r in rows) r.beneficiaryId: r});

  Stream<BeneficiaryRow?> watchBeneficiary(String id) =>
      (db.select(db.beneficiaries)..where((b) => b.id.equals(id)))
          .watchSingleOrNull();

  Stream<BeneficiaryIdentityRow?> watchIdentity(String beneficiaryId) =>
      (db.select(db.beneficiaryIdentities)
            ..where((i) => i.beneficiaryId.equals(beneficiaryId)))
          .watchSingleOrNull();

  Stream<List<ConsentRow>> watchConsents(String beneficiaryId) =>
      (db.select(db.consents)
            ..where((c) => c.beneficiaryId.equals(beneficiaryId) & c.deletedAt.isNull()))
          .watch();

  Stream<List<PregnancyRow>> watchPregnancies(String beneficiaryId) =>
      (db.select(db.pregnancies)
            ..where((p) => p.beneficiaryId.equals(beneficiaryId) & p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
          .watch();

  Stream<List<AncVisitRow>> watchAncVisits(String pregnancyId) =>
      (db.select(db.ancVisits)
            ..where((v) => v.pregnancyId.equals(pregnancyId) & v.deletedAt.isNull())
            ..orderBy([(v) => OrderingTerm.asc(v.sequence)]))
          .watch();

  /// Toutes les grossesses (vue d'ensemble « Mes patientes »).
  Stream<List<PregnancyRow>> watchAllPregnancies() => (db.select(db.pregnancies)
        ..where((p) => p.deletedAt.isNull())
        ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
      .watch();

  /// Toutes les CPN reçues du serveur (vue d'ensemble « Mes patientes »).
  Stream<List<AncVisitRow>> watchAllAncVisits() => (db.select(db.ancVisits)
        ..where((v) => v.deletedAt.isNull())
        ..orderBy([(v) => OrderingTerm.asc(v.sequence)]))
      .watch();

  /// CPN planifiées jusqu'à [days] jours (en retard incluses).
  Stream<List<AncVisitRow>> watchUpcomingAnc({int days = 7}) {
    final limit = _now().add(Duration(days: days)).toIso8601String().substring(0, 10);
    return (db.select(db.ancVisits)
          ..where((v) =>
              v.status.equals(AncVisitStatus.planned.wire) &
              v.deletedAt.isNull() &
              v.scheduledDate.isSmallerOrEqualValue(limit))
          ..orderBy([(v) => OrderingTerm.asc(v.scheduledDate)]))
        .watch();
  }

  /// Bénéficiaire d'une grossesse (pour l'affichage des CPN à venir).
  Future<String?> beneficiaryIdForPregnancy(String pregnancyId) async {
    final p = await (db.select(db.pregnancies)..where((t) => t.id.equals(pregnancyId)))
        .getSingleOrNull();
    return p?.beneficiaryId;
  }

  Stream<List<ReferralRow>> watchReferrals() => (db.select(db.referrals)
        ..where((r) => r.deletedAt.isNull())
        ..orderBy([(r) => OrderingTerm.desc(r.updatedAt)]))
      .watch();

  Stream<List<AlertRow>> watchAlerts({bool openOnly = false}) {
    final q = db.select(db.alerts)..where((a) => a.deletedAt.isNull());
    if (openOnly) {
      q.where((a) => a.status.isIn(['open', 'escalated']));
    }
    q.orderBy([(a) => OrderingTerm.desc(a.createdAt)]);
    return q.watch();
  }

  // ============================================================ JSON (contrat)

  static Map<String, dynamic> consentJson(ConsentRow r) => {
        'id': r.id,
        'beneficiary_id': r.beneficiaryId,
        'scope': r.scope,
        'method': r.method,
        'information_version': r.informationVersion,
        'collected_by_user_id': r.collectedByUserId,
        'collected_at': r.collectedAt,
        'withdrawn_at': r.withdrawnAt,
        'withdrawn_by_user_id': r.withdrawnByUserId,
      };

  static Map<String, dynamic> identityJson(BeneficiaryIdentityRow r) => {
        'beneficiary_id': r.beneficiaryId,
        'display_name': r.displayName,
        'phone': r.phone,
        'village': r.village,
      };

  static Map<String, dynamic> pregnancyJson(PregnancyRow r) => {
        'id': r.id,
        'beneficiary_id': r.beneficiaryId,
        'status': r.status,
        'lmp_date': r.lmpDate,
        'estimated_due_date': r.estimatedDueDate,
        'dates_confirmed_by': r.datesConfirmedBy,
      };

  static Map<String, dynamic> ancVisitJson(AncVisitRow r) => {
        'id': r.id,
        'pregnancy_id': r.pregnancyId,
        'sequence': r.sequence,
        'scheduled_date': r.scheduledDate,
        'status': r.status,
        'done_date': r.doneDate,
        'site_id': r.siteId,
      };

  static Map<String, dynamic> referralJson(ReferralRow r) => {
        'id': r.id,
        'beneficiary_id': r.beneficiaryId,
        'alert_id': r.alertId,
        'from_site_id': r.fromSiteId,
        'to_site_id': r.toSiteId,
        'status': r.status,
        'reason': r.reason,
        'outcome_note': r.outcomeNote,
      };

  /// Version de base : null si l'entité n'a jamais été confirmée par le serveur.
  static int? _base(int version) => version > 0 ? version : null;

  static String? _blankToNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
}
