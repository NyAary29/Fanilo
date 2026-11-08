import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/repositories/local_repository.dart';
import '../../domain/enums.dart';
import '../labels.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'signs_screen.dart';

/// Fiche bénéficiaire : suivi (sans nom), identité à part, consentements,
/// grossesse et calendrier CPN.
class BeneficiaryDetailScreen extends ConsumerWidget {
  const BeneficiaryDetailScreen({super.key, required this.beneficiaryId});
  final String beneficiaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final b = ref.watch(beneficiaryProvider(beneficiaryId)).valueOrNull;
    final identity = ref.watch(identityProvider(beneficiaryId)).valueOrNull;
    final consents = ref.watch(consentsProvider(beneficiaryId)).valueOrNull ?? const [];
    final pregnancies =
        ref.watch(pregnanciesProvider(beneficiaryId)).valueOrNull ?? const [];
    final pending = ref.watch(pendingKeysProvider).valueOrNull ?? const {};
    final hasReny = consents.any((c) =>
        c.scope == ConsentScope.reny.wire && c.withdrawnAt == null);

    return FaniloScaffold(
      title: b?.code ?? l.beneficiaryTitle,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.badge),
              title: Text(b?.code ?? l.codePending,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              subtitle: Text([
                if (b?.birthYear != null) '${b!.birthYear}',
                if (b != null) l.channel(PreferredChannel.fromWire(b.preferredChannel)),
              ].join(' · ')),
              trailing: pending.contains('beneficiary/$beneficiaryId')
                  ? const Icon(Icons.cloud_upload_outlined)
                  : null,
            ),
          ),
          // Identité affichée à part, clairement marquée confidentielle.
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.lock),
              title: Text(identity?.displayName ?? '—',
                  style: const TextStyle(fontSize: 18)),
              subtitle: Text([
                l.identityConfidential,
                if (identity?.phone != null) identity!.phone!,
                if (identity?.village != null) identity!.village!,
              ].join('\n')),
            ),
          ),
          const SizedBox(height: 8),
          _SectionTitle(l.consentsTitle),
          for (final c in consents) _ConsentTile(consent: c, pending: pending),
          const SizedBox(height: 8),
          _SectionTitle(l.pregnancyTitle),
          if (pregnancies.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(hasReny ? l.noPregnancy : l.needRenyConsent),
            ),
            FilledButton.icon(
              key: const Key('declare-pregnancy'),
              onPressed: hasReny
                  ? () => _declarePregnancy(context, ref)
                  : null,
              icon: const Icon(Icons.pregnant_woman),
              label: Text(l.declarePregnancy),
            ),
          ],
          for (final p in pregnancies) _PregnancyCard(pregnancy: p),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SignsScreen(beneficiaryId: beneficiaryId))),
            icon: const Icon(Icons.health_and_safety),
            label: Text(l.menuSigns),
          ),
        ],
      ),
    );
  }

  Future<void> _declarePregnancy(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<(String?, DatesConfirmedBy)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PregnancyForm(),
    );
    if (result == null) return;
    try {
      await ref.read(localRepositoryProvider).createPregnancy(
          beneficiaryId: beneficiaryId, lmpDate: result.$1, confirmedBy: result.$2);
      ref.read(syncServiceProvider).sync();
    } on NoActiveRenyConsentException {
      if (context.mounted) showSnack(context, context.l10n.needRenyConsent);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

class _ConsentTile extends ConsumerWidget {
  const _ConsentTile({required this.consent, required this.pending});
  final ConsentRow consent;
  final Set<String> pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final active = consent.withdrawnAt == null;
    return Card(
      child: ListTile(
        leading: Icon(active ? Icons.check_circle : Icons.cancel,
            color: active ? Colors.green.shade700 : Colors.grey),
        title: Text(l.consentScope(consent.scope)),
        subtitle: Text(
            '${active ? l.consentActive : l.consentWithdrawn} · ${l.consentMethodLabel(consent.method)} · '
            '${consent.informationVersion} · ${formatDate(consent.collectedAt)}'
            '${pending.contains('consent/${consent.id}') ? '\n${l.pendingSync}' : ''}'),
        trailing: active
            ? TextButton(
                onPressed: () async {
                  final user = ref.read(authProvider).user;
                  if (user == null) return;
                  if (!await confirmDialog(context, l.withdrawConfirm)) return;
                  await ref.read(localRepositoryProvider).withdrawConsent(consent.id, user);
                  ref.read(syncServiceProvider).sync();
                },
                child: Text(l.withdraw),
              )
            : null,
      ),
    );
  }
}

class _PregnancyCard extends ConsumerWidget {
  const _PregnancyCard({required this.pregnancy});
  final PregnancyRow pregnancy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final visits = ref.watch(ancVisitsProvider(pregnancy.id)).valueOrNull ?? const [];
    final pending = ref.watch(pendingKeysProvider).valueOrNull ?? const {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.pregnant_woman),
              const SizedBox(width: 8),
              Text(l.pregnancyStatus(pregnancy.status),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (pending.contains('pregnancy/${pregnancy.id}')) const PendingChip(),
            ]),
            if (pregnancy.lmpDate != null)
              Text('${l.lmpDate.split(' (').first} : ${formatDate(pregnancy.lmpDate)}'),
            const Divider(),
            Text(l.ancCalendar, style: Theme.of(context).textTheme.titleMedium),
            if (visits.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l.ancWaiting),
              ),
            for (final v in visits)
              _AncVisitTile(visit: v, pending: pending.contains('anc_visit/${v.id}')),
          ],
        ),
      ),
    );
  }
}

class _AncVisitTile extends ConsumerWidget {
  const _AncVisitTile({required this.visit, required this.pending});
  final AncVisitRow visit;
  final bool pending;

  Future<void> _mark(BuildContext context, WidgetRef ref, AncVisitStatus to) async {
    try {
      await ref.read(localRepositoryProvider).markAncVisit(visit.id, to);
      ref.read(syncServiceProvider).sync();
    } on InvalidStateException catch (e) {
      if (context.mounted) showSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final planned = visit.status == AncVisitStatus.planned.wire;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(l.ancVisit(visit.sequence, formatDate(visit.scheduledDate)),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Text(l.ancStatus(visit.status)),
            if (pending) const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.cloud_upload_outlined, size: 18)),
          ]),
          if (planned)
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  key: Key('anc-done-${visit.sequence}'),
                  onPressed: () => _mark(context, ref, AncVisitStatus.done),
                  icon: const Icon(Icons.check),
                  label: Text(l.markDone),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('anc-missed-${visit.sequence}'),
                  onPressed: () => _mark(context, ref, AncVisitStatus.missed),
                  icon: const Icon(Icons.close),
                  label: Text(l.markMissed),
                ),
              ),
            ]),
        ],
      ),
    );
  }
}

class _PregnancyForm extends StatefulWidget {
  const _PregnancyForm();
  @override
  State<_PregnancyForm> createState() => _PregnancyFormState();
}

class _PregnancyFormState extends State<_PregnancyForm> {
  DateTime? _lmp;
  DatesConfirmedBy _by = DatesConfirmedBy.acDeclared;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.declarePregnancy, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text(_lmp == null
                ? l.lmpDate
                : formatDate(_lmp!.toIso8601String())),
            onPressed: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                firstDate: now.subtract(const Duration(days: 320)),
                lastDate: now,
                initialDate: _lmp ?? now,
              );
              if (d != null) setState(() => _lmp = d);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DatesConfirmedBy>(
            value: _by,
            decoration: InputDecoration(labelText: l.confirmedBy),
            items: [
              for (final c in DatesConfirmedBy.values)
                DropdownMenuItem(value: c, child: Text(l.confirmedByLabel(c))),
            ],
            onChanged: (v) => setState(() => _by = v ?? DatesConfirmedBy.acDeclared),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(
                context, (_lmp?.toIso8601String().substring(0, 10), _by)),
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}
