import 'package:flutter/material.dart';

import '../../domain/follow_up.dart';
import '../labels.dart';
import '../patient_overview.dart';
import '../theme.dart';
import 'common.dart';

/// Ligne courte décrivant pourquoi une patiente est « À suivre ».
String? followUpReasonText(BuildContext context, PatientOverview p) {
  final l = context.l10n;
  final a = p.assessment;
  if (a.reasons.contains(FollowUpReason.openAlert)) return l.reasonOpenAlert;
  if (a.overdue != null) {
    return l.reasonOverdue(a.overdue!.sequence, formatDateLong(a.overdue!.scheduledDate));
  }
  if (a.reasons.contains(FollowUpReason.missedAnc)) return l.reasonMissed;
  return null;
}

/// « CPN 4 : dans 7 jours (12 nov. 2026) ». La date vient du serveur ; seul
/// l'écart avec aujourd'hui est affiché.
String ancWhenText(BuildContext context, AncSlot slot, String today) {
  final l = context.l10n;
  final d = daysFrom(today, slot.scheduledDate) ?? 0;
  final when = d == 0
      ? l.whenToday
      : d == 1
          ? l.whenTomorrow
          : d > 1
              ? l.whenInDays(d)
              : l.whenLate(-d);
  return l.nextAnc(slot.sequence, when, formatDateLong(slot.scheduledDate));
}

/// Libellé de grossesse (« Grossesse · 3 mois »).
String pregnancyLine(BuildContext context, PatientOverview p) {
  final l = context.l10n;
  final preg = p.pregnancy;
  if (preg == null) return l.noPregnancyShort;
  if (preg.status != 'active') return l.pregnancyStatus(preg.status);
  return p.months == null ? l.pregnancyNoDate : l.pregnancyMonths(p.months!);
}

/// Carte d'une patiente : initiales, nom, grossesse, pastille de suivi.
class PatientCard extends StatelessWidget {
  const PatientCard({
    super.key,
    required this.patient,
    required this.onTap,
    this.detail,
    this.action,
  });

  final PatientOverview patient;
  final VoidCallback onTap;

  /// Ligne d'information supplémentaire (sinon : raison du suivi).
  final String? detail;

  /// Bouton affiché sous la carte (ex. « Commencer la visite »).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reason = detail ?? followUpReasonText(context, patient);
    final hasAlert = patient.openAlerts.isNotEmpty;
    return SoftCard(
      key: Key('patient-${patient.id}'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: onTap,
      borderColor: hasAlert ? FaniloColors.alert.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            PatientAvatar(name: patient.name ?? patient.beneficiary.code, alert: hasAlert),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name ?? patient.beneficiary.code ?? l.codePending,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Row(children: [
                    const Icon(Icons.pregnant_woman, size: 16, color: FaniloColors.inkSoft),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(pregnancyLine(context, patient),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5, color: FaniloColors.inkSoft)),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(status: patient.status),
          ]),
          if (reason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 2),
              child: Row(children: [
                Icon(
                    detail != null
                        ? Icons.event_available
                        : hasAlert
                            ? Icons.warning_rounded
                            : Icons.event_busy,
                    size: 18,
                    color: detail != null
                        ? FaniloColors.leaf
                        : hasAlert
                            ? FaniloColors.alert
                            : FaniloColors.follow),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(reason,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: detail != null
                              ? FaniloColors.forestDark
                              : hasAlert
                                  ? FaniloColors.alertInk
                                  : FaniloColors.followInk)),
                ),
              ]),
            ),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    );
  }
}
