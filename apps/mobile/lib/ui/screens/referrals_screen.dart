import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../domain/enums.dart';
import '../../domain/referral_rules.dart';
import '../labels.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// Références : seules les transitions autorisées par le contrat sont
/// proposées ; « non aboutie » exige un motif.
class ReferralsScreen extends ConsumerWidget {
  const ReferralsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final referrals = ref.watch(referralsProvider).valueOrNull ?? const [];
    final beneficiaries = ref.watch(beneficiariesProvider).valueOrNull ?? const [];
    final identities = ref.watch(identitiesProvider).valueOrNull ?? const {};
    final pending = ref.watch(pendingKeysProvider).valueOrNull ?? const {};
    final codes = {for (final b in beneficiaries) b.id: b.code};

    return FaniloScaffold(
      title: l.referralsTitle,
      body: referrals.isEmpty
          ? EmptyState(l.noReferrals)
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: referrals.length,
              itemBuilder: (context, i) {
                final r = referrals[i];
                final name = identities[r.beneficiaryId]?.displayName;
                return Card(
                  child: ListTile(
                    minVerticalPadding: 14,
                    leading: const Icon(Icons.local_hospital, size: 32),
                    title: Text(name ?? codes[r.beneficiaryId] ?? l.codePending,
                        style: const TextStyle(fontSize: 18)),
                    subtitle: Text([
                      l.referralStatus(r.status),
                      if (r.reason != null) r.reason!,
                      if (pending.contains('referral/${r.id}')) l.pendingSync,
                    ].join(' · ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ReferralTransitionSheet(referral: r),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class ReferralTransitionSheet extends ConsumerStatefulWidget {
  const ReferralTransitionSheet({super.key, required this.referral});
  final ReferralRow referral;

  @override
  ConsumerState<ReferralTransitionSheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<ReferralTransitionSheet> {
  ReferralStatus? _target;
  final _reason = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final to = _target;
    if (to == null) return;
    try {
      await ref.read(localRepositoryProvider).transitionReferral(
            widget.referral.id,
            to,
            reason: _reason.text.trim().isEmpty ? null : _reason.text,
            outcomeNote: _note.text.trim().isEmpty ? null : _note.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ref.read(syncServiceProvider).sync();
    } on ReferralTransitionException {
      setState(() => _error = context.l10n.reasonRequired);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final from = ReferralStatus.fromWire(widget.referral.status);
    final allowed = from == null ? <ReferralStatus>{} : ReferralRules.allowedFrom(from);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${l.changeStatus} (${l.referralStatus(widget.referral.status)})',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (allowed.isEmpty) Text(l.noTransition),
          for (final s in ReferralStatus.values.where(allowed.contains))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChoiceChip(
                key: Key('transition-${s.wire}'),
                label: SizedBox(
                    width: double.infinity,
                    child: Text(l.referralStatus(s.wire),
                        style: const TextStyle(fontSize: 17))),
                selected: _target == s,
                onSelected: (_) => setState(() {
                  _target = s;
                  _error = null;
                }),
              ),
            ),
          if (_target != null && ReferralRules.requiresReason(_target!))
            TextField(
              key: const Key('reason-field'),
              controller: _reason,
              decoration: InputDecoration(labelText: l.reasonRequired),
            ),
          if (_target != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l.outcomeNote),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 12),
          if (allowed.isNotEmpty)
            FilledButton(
              key: const Key('apply-transition'),
              onPressed: _target == null ? null : _apply,
              child: Text(l.save),
            ),
        ],
      ),
    );
  }
}
