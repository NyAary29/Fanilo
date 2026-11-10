import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../domain/follow_up.dart';
import '../labels.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'beneficiary_detail_screen.dart';

/// Alertes : lecture seule (reçues par pull). L'accusé de réception se fait
/// par le destinataire désigné (dashboard / CSB), pas depuis ce téléphone.
/// Aucune sévérité n'est affichée : seulement le statut et les dates.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final alerts = ref.watch(alertsProvider).valueOrNull ?? const [];

    return FaniloScaffold(
      title: l.alertsTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          NoticeCard(text: l.alertsReadOnly),
          if (alerts.isEmpty) EmptyState(l.noAlerts, icon: Icons.notifications_none),
          for (final a in alerts) AlertTile(alert: a),
        ],
      ),
    );
  }
}

/// Carte d'alerte : statut (« en attente d'accusé de réception » tant que
/// personne ne l'a reçue), patiente, dates. Jamais de sévérité ni de
/// diagnostic, jamais de promesse de prise en charge.
class AlertTile extends ConsumerWidget {
  const AlertTile({super.key, required this.alert, this.showPatient = true});
  final AlertRow alert;
  final bool showPatient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final waiting = isAwaitingAcknowledgement(alert.status);
    final identities = ref.watch(identitiesProvider).valueOrNull ?? const {};
    final beneficiaries = ref.watch(beneficiariesProvider).valueOrNull ?? const [];
    String? who;
    if (alert.beneficiaryId != null) {
      who = identities[alert.beneficiaryId]?.displayName;
      if (who == null) {
        for (final b in beneficiaries) {
          if (b.id == alert.beneficiaryId) who = b.code;
        }
      }
    }
    return SoftCard(
      key: Key('alert-${alert.id}'),
      color: waiting ? FaniloColors.alertSoft : FaniloColors.surface,
      onTap: showPatient && alert.beneficiaryId != null
          ? () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BeneficiaryDetailScreen(beneficiaryId: alert.beneficiaryId!)))
          : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(waiting ? Icons.warning_rounded : Icons.mark_email_read_outlined,
            size: 32, color: waiting ? FaniloColors.alert : FaniloColors.ok),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(l.alertStatus(alert.status),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: waiting ? FaniloColors.alertInk : FaniloColors.forestDark)),
              ),
              if (alert.isDemo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: FaniloColors.demo, borderRadius: BorderRadius.circular(999)),
                  child: Text(l.demoTag,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
            ]),
            if (waiting)
              Text(l.alertAwaitingAck,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (showPatient && who != null)
              Text(who, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            if (alert.createdAt != null)
              Text(l.alertCreatedAt(formatDateTime(alert.createdAt)),
                  style: const TextStyle(fontSize: 14, color: FaniloColors.inkSoft)),
            if (alert.acknowledgedAt != null)
              Text(l.alertAckAt(formatDateTime(alert.acknowledgedAt)),
                  style: const TextStyle(fontSize: 14, color: FaniloColors.inkSoft)),
          ]),
        ),
      ]),
    );
  }
}
