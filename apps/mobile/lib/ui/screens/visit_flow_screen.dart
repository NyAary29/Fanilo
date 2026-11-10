import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../data/repositories/local_repository.dart';
import '../../domain/enums.dart';
import '../patient_overview.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/patient_card.dart';
import 'signs_screen.dart';

/// « Visite du jour » : liste guidée pour une patiente.
///
/// 1. Enregistrement de la visite : patiente vue, consentement RENY actif.
/// 2. Signes de danger ? Oui → signalement (en ligne uniquement, mêmes règles
///    que l'onglet « Alerter ») ; Non → on continue.
/// 3. Conseils donnés : contenus publiés par le serveur (copie locale).
/// 4. Prochain RDV : CPN fixées par le serveur ; une CPN due peut être
///    marquée réalisée ou manquée (outbox, comme sur la fiche).
///
/// Le contrat d'API n'a pas d'entité « visite à domicile » : les étapes 1 à
/// 3 forment une **liste de contrôle locale**, non enregistrée ni envoyée.
/// Seules les CPN marquées et un éventuel signalement partent au serveur.
class VisitFlowScreen extends ConsumerStatefulWidget {
  const VisitFlowScreen({super.key, required this.beneficiaryId});
  final String beneficiaryId;

  @override
  ConsumerState<VisitFlowScreen> createState() => _VisitFlowScreenState();
}

class _VisitFlowScreenState extends ConsumerState<VisitFlowScreen> {
  bool _confirmed = false;
  bool? _danger;
  bool _reported = false;
  final Set<String> _advice = {};

  @override
  void initState() {
    super.initState();
    // Conseils à jour si le réseau est là ; sinon, copie locale.
    Future.microtask(() async {
      if (!mounted) return;
      if (await ref.read(networkSourceProvider).isOnline()) {
        await ref.read(referenceRepositoryProvider).refreshContents();
      }
    });
  }

  Future<void> _openSigns() async {
    setState(() => _danger = true);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SignsScreen(
        beneficiaryId: widget.beneficiaryId,
        onSent: () {
          if (mounted) setState(() => _reported = true);
        },
      ),
    ));
  }

  Future<void> _mark(String visitId, AncVisitStatus to) async {
    try {
      await ref.read(localRepositoryProvider).markAncVisit(visitId, to);
      ref.read(syncServiceProvider).sync();
    } on InvalidStateException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  void _save() {
    final l = context.l10n;
    if (!_confirmed || _danger == null) {
      showSnack(context, l.visitIncomplete);
      return;
    }
    ref.read(syncServiceProvider).sync();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.visitSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final patient = ref.watch(patientOverviewProvider(widget.beneficiaryId));
    final consents = ref.watch(consentsProvider(widget.beneficiaryId)).valueOrNull ?? const [];
    final today = ref.watch(todayProvider);
    final hasReny =
        consents.any((c) => c.scope == ConsentScope.reny.wire && c.withdrawnAt == null);
    final unlocked = _confirmed && hasReny;

    return FaniloScaffold(
      title: l.visitTitle,
      bottom: _BottomActions(
        canSave: _confirmed && _danger != null,
        onSave: _save,
        onAlert: _openSigns,
      ),
      body: patient == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              key: const Key('visit-flow'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                _PatientHeader(patient: patient),
                if (patient.openAlerts.isNotEmpty)
                  NoticeCard(
                    tone: NoticeTone.alert,
                    title: l.alertBannerTitle,
                    text: l.alertAwaitingAck,
                  ),
                _StepCard(
                  key: const Key('visit-step-1'),
                  number: 1,
                  icon: Icons.how_to_reg_outlined,
                  title: l.visitStep1,
                  done: unlocked,
                  enabled: true,
                  child: hasReny
                      ? _BigCheck(
                          key: const Key('visit-confirm'),
                          value: _confirmed,
                          label: l.visitConsentConfirm,
                          onChanged: (v) => setState(() => _confirmed = v),
                        )
                      : NoticeCard(
                          key: const Key('visit-no-consent'),
                          tone: NoticeTone.alert,
                          icon: Icons.lock_outline,
                          text: l.visitNoConsent),
                ),
                _StepCard(
                  key: const Key('visit-step-2'),
                  number: 2,
                  icon: Icons.health_and_safety_outlined,
                  title: l.visitStep2,
                  done: _danger != null,
                  enabled: unlocked,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                          child: _ChoiceButton(
                            key: const Key('danger-yes'),
                            label: l.yes,
                            icon: Icons.warning_amber_rounded,
                            selected: _danger == true,
                            color: FaniloColors.alert,
                            onTap: unlocked ? _openSigns : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ChoiceButton(
                            key: const Key('danger-no'),
                            label: l.no,
                            icon: Icons.check_circle_outline,
                            selected: _danger == false,
                            color: FaniloColors.ok,
                            onTap: unlocked ? () => setState(() => _danger = false) : null,
                          ),
                        ),
                      ]),
                      if (_danger == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _reported ? l.visitSignsReported : l.visitSignsYesHint,
                            key: const Key('visit-danger-status'),
                            style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: FaniloColors.alertInk),
                          ),
                        ),
                    ],
                  ),
                ),
                _StepCard(
                  key: const Key('visit-step-3'),
                  number: 3,
                  icon: Icons.record_voice_over_outlined,
                  title: l.visitStep3,
                  done: _advice.isNotEmpty,
                  enabled: unlocked,
                  child: _AdviceList(
                    selected: _advice,
                    enabled: unlocked,
                    onToggle: (code, v) =>
                        setState(() => v ? _advice.add(code) : _advice.remove(code)),
                  ),
                ),
                _StepCard(
                  key: const Key('visit-step-4'),
                  number: 4,
                  icon: Icons.event_available_outlined,
                  title: l.visitStep4,
                  done: patient.assessment.dueOn(today) == null,
                  enabled: unlocked,
                  child: _NextAppointment(
                    patient: patient,
                    today: today,
                    enabled: unlocked,
                    onMark: _mark,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    const Icon(Icons.phone_android, size: 18, color: FaniloColors.inkSoft),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(l.visitLocalNote,
                          style: const TextStyle(fontSize: 13.5, color: FaniloColors.inkSoft)),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.patient});
  final PatientOverview patient;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SoftCard(
      child: Row(children: [
        PatientAvatar(
            name: patient.name ?? patient.beneficiary.code,
            size: 56,
            alert: patient.openAlerts.isNotEmpty),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patient.name ?? patient.beneficiary.code ?? l.codePending,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            Text(pregnancyLine(context, patient),
                style: const TextStyle(fontSize: 15, color: FaniloColors.inkSoft)),
          ]),
        ),
        StatusChip(status: patient.status),
      ]),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.number,
    required this.icon,
    required this.title,
    required this.done,
    required this.enabled,
    required this.child,
  });

  final int number;
  final IconData icon;
  final String title;
  final bool done;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final marker = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done
            ? FaniloColors.ok
            : enabled
                ? FaniloColors.forest
                : FaniloColors.line,
        shape: BoxShape.circle,
      ),
      child: done
          ? const Icon(Icons.check, color: Colors.white, size: 22)
          : Text('$number',
              style: TextStyle(
                  color: enabled ? Colors.white : FaniloColors.inkSoft,
                  fontWeight: FontWeight.w900,
                  fontSize: 17)),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              marker,
              const SizedBox(width: 12),
              Icon(icon, color: FaniloColors.forest),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Grande case à cocher (toute la ligne est cliquable).
class _BigCheck extends StatelessWidget {
  const _BigCheck({super.key, required this.value, required this.label, this.onChanged});
  final bool value;
  final String label;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value ? FaniloColors.okSoft : FaniloColors.mint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(value ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 32, color: FaniloColors.forest),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kRadius);
    return Material(
      color: selected ? color : Colors.white,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: color, width: 2),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: selected ? Colors.white : color, size: 28),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : color)),
          ]),
        ),
      ),
    );
  }
}

/// Conseils : contenus publiés par le serveur (copie locale), à cocher.
class _AdviceList extends ConsumerWidget {
  const _AdviceList({required this.selected, required this.enabled, required this.onToggle});
  final Set<String> selected;
  final bool enabled;
  final void Function(String code, bool value) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final contents = ref.watch(publishedContentsProvider).valueOrNull;
    final items = contents?.forModule(AppConfig.askModule) ?? const [];
    if (items.isEmpty) {
      return NoticeCard(
          key: const Key('visit-advice-none'), text: l.visitAdviceNone);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.any((c) => c.isDemo)) DemoBanner(text: l.demoContent),
        Text(l.visitAdviceHint,
            style: const TextStyle(fontSize: 15, color: FaniloColors.inkSoft)),
        const SizedBox(height: 6),
        for (final c in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected.contains(c.code) ? FaniloColors.okSoft : FaniloColors.mint,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: Key('advice-${c.code}'),
                borderRadius: BorderRadius.circular(12),
                onTap: enabled ? () => onToggle(c.code, !selected.contains(c.code)) : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(
                        selected.contains(c.code)
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 30,
                        color: FaniloColors.forest),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(c.body, style: const TextStyle(fontSize: 15)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Prochain rendez-vous : CPN fixées par le serveur, jamais calculées ici.
class _NextAppointment extends ConsumerWidget {
  const _NextAppointment({
    required this.patient,
    required this.today,
    required this.enabled,
    required this.onMark,
  });

  final PatientOverview patient;
  final String today;
  final bool enabled;
  final Future<void> Function(String visitId, AncVisitStatus to) onMark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final pregnancy = patient.pregnancy;
    final pending = ref.watch(pendingKeysProvider).valueOrNull ?? const {};
    if (pregnancy == null || pregnancy.status != PregnancyStatus.active.wire) {
      return NoticeCard(text: l.noPregnancyVisit);
    }
    if (patient.visits.isEmpty) {
      return NoticeCard(
          text: pregnancy.version > 0 &&
                  pregnancy.lmpDate == null &&
                  pregnancy.estimatedDueDate == null
              ? l.ancNeedsLmp
              : l.ancWaiting);
    }
    final due = patient.assessment.dueOn(today);
    final next = patient.assessment.next;
    final upcoming = next != null && next.id != due?.id ? next : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (due != null) ...[
          NoticeCard(
            key: const Key('visit-anc-due'),
            tone: NoticeTone.warning,
            icon: Icons.event_busy,
            title: ancWhenText(context, due, today),
            text: l.visitAncDueQuestion,
          ),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('visit-anc-done'),
                onPressed: enabled ? () => onMark(due.id, AncVisitStatus.done) : null,
                icon: const Icon(Icons.check),
                label: Text(l.markDone),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('visit-anc-missed'),
                onPressed: enabled ? () => onMark(due.id, AncVisitStatus.missed) : null,
                icon: const Icon(Icons.close),
                label: Text(l.markMissed),
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ],
        if (upcoming != null)
          NextReminderCard(text: ancWhenText(context, upcoming, today))
        else if (due == null)
          NoticeCard(text: l.noUpcomingAnc),
        if (patient.visits.any((v) => pending.contains('anc_visit/${v.id}')))
          const Align(alignment: Alignment.centerLeft, child: PendingChip()),
      ],
    );
  }
}

/// Carte « Prochain rappel » (maquette) : calendrier et date du serveur.
class NextReminderCard extends StatelessWidget {
  const NextReminderCard({super.key, required this.text, this.title});
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('next-reminder'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FaniloColors.mint,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.calendar_month, color: FaniloColors.forest, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title ?? context.l10n.nextReminder,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: FaniloColors.inkSoft)),
            Text(text,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: FaniloColors.forestDark)),
          ]),
        ),
      ]),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.canSave, required this.onSave, required this.onAlert});
  final bool canSave;
  final VoidCallback onSave;
  final VoidCallback onAlert;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      color: FaniloColors.cream,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              key: const Key('visit-save'),
              style: FilledButton.styleFrom(
                backgroundColor: canSave ? FaniloColors.forest : FaniloColors.leafLight,
              ),
              onPressed: onSave,
              icon: const Icon(Icons.save_alt_rounded),
              label: Text(l.visitSave),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('visit-alert'),
              style: FilledButton.styleFrom(backgroundColor: FaniloColors.alert),
              onPressed: onAlert,
              icon: const Icon(Icons.campaign_rounded),
              label: Text(l.visitAlertCsb),
            ),
          ],
        ),
      ),
    );
  }
}
