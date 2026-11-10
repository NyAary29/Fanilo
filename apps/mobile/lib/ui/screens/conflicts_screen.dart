import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/repositories/outbox_repository.dart';
import '../labels.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// Conflits de synchronisation (version serveur gardée, modification locale
/// conservée pour revue) et envois refusés par le serveur.
class ConflictsScreen extends ConsumerWidget {
  const ConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final conflicts = ref.watch(conflictsProvider).valueOrNull ?? const [];
    final rejected = ref.watch(rejectedProvider).valueOrNull ?? const [];

    return FaniloScaffold(
      title: l.conflictsTitle,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (rejected.isNotEmpty) ...[
            Text(l.rejectedTitle, style: Theme.of(context).textTheme.titleLarge),
            for (final r in rejected) _RejectedCard(row: r),
            const SizedBox(height: 16),
          ],
          if (conflicts.isEmpty && rejected.isEmpty) EmptyState(l.noConflicts),
          if (conflicts.isNotEmpty) ...[
            Text(l.conflictExplain, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            for (final c in conflicts) _ConflictCard(conflict: c),
          ],
        ],
      ),
    );
  }
}

String _pretty(String? json) {
  if (json == null) return '—';
  try {
    final m = (jsonDecode(json) as Map).cast<String, dynamic>();
    return m.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key} : ${e.value}')
        .join('\n');
  } on Object {
    return json;
  }
}

class _ConflictCard extends ConsumerWidget {
  const _ConflictCard({required this.conflict});
  final SyncConflictRow conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l.entity(conflict.entity)} · ${formatDateTime(conflict.detectedAt.toIso8601String())}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(l.conflictLocal, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(_pretty(conflict.localData)),
            const SizedBox(height: 8),
            Text(l.conflictServer, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(_pretty(conflict.serverData)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => ref
                      .read(localRepositoryProvider)
                      .markConflictReviewed(conflict.id),
                  child: Text(l.keepServer, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await ref.read(localRepositoryProvider).reapplyLocal(conflict.id);
                    ref.read(syncServiceProvider).sync(force: true);
                  },
                  child: Text(l.reapplyLocal, textAlign: TextAlign.center),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _RejectedCard extends ConsumerWidget {
  const _RejectedCard({required this.row});
  final OutboxRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.entity(row.entity),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(row.lastError ?? '—', key: Key('rejected-error-${row.changeId}')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    if (!await confirmDialog(context, '${l.discard} ?')) return;
                    final outcome =
                        await ref.read(outboxRepositoryProvider).discard(row.changeId);
                    if (!context.mounted) return;
                    switch (outcome) {
                      case DiscardOutcome.reloadFromServer:
                        showSnack(context, l.discardedReload);
                        // Recharge l'état serveur (curseur remis à zéro).
                        ref.read(syncServiceProvider).sync(force: true);
                      case DiscardOutcome.removedLocal:
                        showSnack(context, l.discardedLocal);
                      case DiscardOutcome.none:
                        break;
                    }
                  },
                  child: Text(l.discard),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await ref.read(outboxRepositoryProvider).retry(row.changeId);
                    ref.read(syncServiceProvider).sync(force: true);
                  },
                  child: Text(l.retry),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
