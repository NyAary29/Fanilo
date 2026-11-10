import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import '../domain/enums.dart';
import '../domain/follow_up.dart';
import 'providers.dart';

/// Vue d'ensemble d'une patiente, assemblée à partir des tables locales
/// (miroir du serveur). Aucune donnée n'est calculée ou inventée : les CPN et
/// les alertes viennent du serveur.
class PatientOverview {
  const PatientOverview({
    required this.beneficiary,
    required this.identity,
    required this.pregnancy,
    required this.visits,
    required this.openAlerts,
    required this.assessment,
    required this.months,
  });

  final BeneficiaryRow beneficiary;
  final BeneficiaryIdentityRow? identity;

  /// Grossesse en cours (la plus récente), si déclarée.
  final PregnancyRow? pregnancy;

  /// CPN de la grossesse en cours, par numéro.
  final List<AncVisitRow> visits;

  /// Alertes en attente d'accusé de réception.
  final List<AlertRow> openAlerts;
  final FollowUpAssessment assessment;

  /// Mois approximatifs depuis les dernières règles (affichage seulement).
  final int? months;

  String get id => beneficiary.id;
  String? get name => identity?.displayName;
  FollowUpStatus get status => assessment.status;

  AncVisitRow? visitFor(AncSlot? slot) {
    if (slot == null) return null;
    for (final v in visits) {
      if (v.id == slot.id) return v;
    }
    return null;
  }
}

AncSlot ancSlotOf(AncVisitRow v) => AncSlot(
    id: v.id, sequence: v.sequence, scheduledDate: v.scheduledDate, status: v.status);

/// Toutes les patientes, « À suivre » d'abord, puis par nom.
final patientOverviewsProvider = Provider<List<PatientOverview>>((ref) {
  final beneficiaries = ref.watch(beneficiariesProvider).valueOrNull ?? const [];
  final identities = ref.watch(identitiesProvider).valueOrNull ?? const {};
  final pregnancies = ref.watch(allPregnanciesProvider).valueOrNull ?? const [];
  final visits = ref.watch(allAncVisitsProvider).valueOrNull ?? const [];
  final alerts = ref.watch(alertsProvider).valueOrNull ?? const [];
  final today = ref.watch(todayProvider);

  final pregnancyByBeneficiary = <String, PregnancyRow>{};
  for (final p in pregnancies) {
    final current = pregnancyByBeneficiary[p.beneficiaryId];
    final isActive = p.status == PregnancyStatus.active.wire;
    if (current == null ||
        (isActive && current.status != PregnancyStatus.active.wire)) {
      pregnancyByBeneficiary[p.beneficiaryId] = p;
    }
  }
  final visitsByPregnancy = <String, List<AncVisitRow>>{};
  for (final v in visits) {
    visitsByPregnancy.putIfAbsent(v.pregnancyId, () => []).add(v);
  }
  final alertsByBeneficiary = <String, List<AlertRow>>{};
  for (final a in alerts) {
    if (a.beneficiaryId == null || !isAwaitingAcknowledgement(a.status)) continue;
    alertsByBeneficiary.putIfAbsent(a.beneficiaryId!, () => []).add(a);
  }

  final result = [
    for (final b in beneficiaries)
      () {
        final p = pregnancyByBeneficiary[b.id];
        final pv = p == null ? const <AncVisitRow>[] : (visitsByPregnancy[p.id] ?? const []);
        final open = alertsByBeneficiary[b.id] ?? const [];
        final active = p != null && p.status == PregnancyStatus.active.wire;
        return PatientOverview(
          beneficiary: b,
          identity: identities[b.id],
          pregnancy: p,
          visits: pv,
          openAlerts: open,
          assessment: assessFollowUp(
            visits: active ? [for (final v in pv) ancSlotOf(v)] : const [],
            hasOpenAlert: open.isNotEmpty,
            today: today,
          ),
          months: active ? approxPregnancyMonths(p.lmpDate, today) : null,
        );
      }(),
  ];
  result.sort((a, b) {
    int rank(PatientOverview p) => p.openAlerts.isNotEmpty
        ? 0
        : p.assessment.overdue != null
            ? 1
            : p.status == FollowUpStatus.toFollow
                ? 2
                : 3;
    final s = rank(a).compareTo(rank(b));
    if (s != 0) return s;
    return (a.name ?? a.beneficiary.code ?? '')
        .toLowerCase()
        .compareTo((b.name ?? b.beneficiary.code ?? '').toLowerCase());
  });
  return result;
});

final patientOverviewProvider = Provider.family<PatientOverview?, String>((ref, id) {
  for (final p in ref.watch(patientOverviewsProvider)) {
    if (p.id == id) return p;
  }
  return null;
});
