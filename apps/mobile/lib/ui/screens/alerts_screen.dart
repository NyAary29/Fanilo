import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../labels.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// Alertes : lecture seule (reçues par pull). L'accusé de réception se fait
/// par le destinataire désigné (dashboard / CSB), pas depuis ce téléphone.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final alerts = ref.watch(alertsProvider).valueOrNull ?? const [];
    final beneficiaries = ref.watch(beneficiariesProvider).valueOrNull ?? const [];
    final identities = ref.watch(identitiesProvider).valueOrNull ?? const {};
    final codes = {for (final b in beneficiaries) b.id: b.code};

    return FaniloScaffold(
      title: l.alertsTitle,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l.alertsReadOnly,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: alerts.isEmpty
                ? EmptyState(l.noAlerts)
                : ListView.builder(
                    itemCount: alerts.length,
                    itemBuilder: (context, i) {
                      final a = alerts[i];
                      final critical = a.severity == 'critical';
                      final who = identities[a.beneficiaryId]?.displayName ??
                          codes[a.beneficiaryId] ??
                          '—';
                      return Card(
                        child: ListTile(
                          minVerticalPadding: 14,
                          leading: Icon(Icons.warning_rounded,
                              size: 32,
                              color: critical
                                  ? Theme.of(context).colorScheme.error
                                  : Colors.orange.shade800),
                          title: Text('${l.severity(a.severity)} · ${l.alertStatus(a.status)}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          subtitle: Text('$who\n${l.alertDue(formatDateTime(a.dueAt))}'),
                          isThreeLine: true,
                          trailing: a.isDemo
                              ? Chip(label: Text(l.demoTag))
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
