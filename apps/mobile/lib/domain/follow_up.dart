/// Suivi d'une patiente vu par l'agent communautaire : « À jour » ou
/// « À suivre ».
///
/// Règles d'affichage seulement, sans aucune décision clinique :
/// - les dates de CPN viennent **toujours du serveur** (calendrier configuré) ;
///   ici, on les compare seulement à la date du jour ;
/// - une alerte ouverte (ou escaladée) est reçue du serveur ;
/// - aucune sévérité, aucun diagnostic.
library;

import 'enums.dart';

/// CPN telle que reçue du serveur.
class AncSlot {
  const AncSlot({
    required this.id,
    required this.sequence,
    required this.scheduledDate,
    required this.status,
  });

  final String id;
  final int sequence;

  /// `YYYY-MM-DD`, fixée par le serveur.
  final String scheduledDate;
  final String status;

  bool get isPlanned => status == AncVisitStatus.planned.wire;
}

enum FollowUpStatus { upToDate, toFollow }

enum FollowUpReason {
  /// Alerte ouverte ou escaladée (en attente d'accusé de réception).
  openAlert,

  /// CPN prévue dont la date est passée, pas encore marquée.
  overdueAnc,

  /// CPN marquée manquée, sans CPN réalisée après elle.
  missedAnc,
}

class FollowUpAssessment {
  const FollowUpAssessment({
    required this.reasons,
    this.overdue,
    this.next,
  });

  final Set<FollowUpReason> reasons;

  /// Plus ancienne CPN prévue dont la date est passée.
  final AncSlot? overdue;

  /// Prochaine CPN prévue (aujourd'hui ou plus tard).
  final AncSlot? next;

  FollowUpStatus get status =>
      reasons.isEmpty ? FollowUpStatus.upToDate : FollowUpStatus.toFollow;

  /// CPN à traiter pendant une visite : en retard d'abord, sinon celle du
  /// jour.
  AncSlot? dueOn(String today) =>
      overdue ?? (next != null && next!.scheduledDate == today ? next : null);
}

/// Statuts d'alerte qui attendent encore un accusé de réception.
bool isAwaitingAcknowledgement(String alertStatus) =>
    alertStatus == 'open' || alertStatus == 'escalated';

FollowUpAssessment assessFollowUp({
  required List<AncSlot> visits,
  required bool hasOpenAlert,
  required String today,
}) {
  final sorted = [...visits]..sort((a, b) => a.sequence.compareTo(b.sequence));
  AncSlot? overdue;
  AncSlot? next;
  for (final v in sorted.where((v) => v.isPlanned)) {
    if (v.scheduledDate.compareTo(today) < 0) {
      overdue ??= v;
    } else if (next == null || v.scheduledDate.compareTo(next.scheduledDate) < 0) {
      next = v;
    }
  }
  var missed = false;
  for (final v in sorted) {
    if (v.status == AncVisitStatus.missed.wire) {
      missed = !sorted.any((d) =>
          d.sequence > v.sequence && d.status == AncVisitStatus.done.wire);
      if (missed) break;
    }
  }
  return FollowUpAssessment(
    reasons: {
      if (hasOpenAlert) FollowUpReason.openAlert,
      if (overdue != null) FollowUpReason.overdueAnc,
      if (missed) FollowUpReason.missedAnc,
    },
    overdue: overdue,
    next: next,
  );
}

DateTime? _day(String? iso) {
  if (iso == null || iso.length < 10) return null;
  final d = DateTime.tryParse(iso.substring(0, 10));
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

/// Nombre de jours entre [today] et [date] (négatif si [date] est passée).
int? daysFrom(String today, String date) {
  final a = _day(today);
  final b = _day(date);
  if (a == null || b == null) return null;
  return b.difference(a).inDays;
}

/// Mois écoulés depuis la date des dernières règles **saisie par l'AC**,
/// pour l'affichage « Grossesse · 3 mois » uniquement. Approximation
/// (jours / 30,4), jamais utilisée pour une date ou un calendrier. Null si la
/// date est inconnue ou incohérente.
int? approxPregnancyMonths(String? lmpDate, String today) {
  final lmp = _day(lmpDate);
  final now = _day(today);
  if (lmp == null || now == null) return null;
  final days = now.difference(lmp).inDays;
  if (days < 0 || days > 320) return null;
  return (days / 30.4).floor();
}

/// Âge approximatif à partir de l'année de naissance.
int? approxAge(int? birthYear, int currentYear) {
  if (birthYear == null || birthYear <= 1900 || birthYear > currentYear) return null;
  return currentYear - birthYear;
}

/// Initiales pour l'avatar (« Rasoarivelo Marie » → « RM »).
String initialsOf(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty && RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(p[0]))
      .toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final second = parts.length > 1 ? parts[1][0] : '';
  return (first + second).toUpperCase();
}
