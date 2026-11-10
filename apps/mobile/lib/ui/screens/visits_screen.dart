import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/follow_up.dart';
import '../patient_overview.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/patient_card.dart';
import 'visit_flow_screen.dart';

/// Onglet « Mes visites » : les patientes à voir, « À suivre » d'abord, puis
/// celles dont une CPN (date fixée par le serveur) arrive dans les 7 jours.
/// Toucher une patiente ouvre la « Visite du jour ».
class VisitsTab extends ConsumerWidget {
  const VisitsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final patients = ref.watch(patientOverviewsProvider);
    final today = ref.watch(todayProvider);

    bool soon(PatientOverview p) {
      final next = p.assessment.next;
      if (next == null) return false;
      final d = daysFrom(today, next.scheduledDate);
      return d != null && d <= 7;
    }

    final priority = patients.where((p) => p.status == FollowUpStatus.toFollow).toList();
    final week = patients.where((p) => p.status == FollowUpStatus.upToDate && soon(p)).toList();
    final others = patients
        .where((p) => !priority.contains(p) && !week.contains(p))
        .toList();

    void start(PatientOverview p) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VisitFlowScreen(beneficiaryId: p.id)));

    Widget startButton(PatientOverview p) => FilledButton.icon(
          key: Key('start-visit-${p.id}'),
          onPressed: () => start(p),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(l.startVisit),
        );

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.event_note, color: FaniloColors.forest),
          const SizedBox(width: 10),
          Text(l.visitsTitle),
        ]),
      ),
      body: ListView(
        key: const Key('visits-list'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(l.visitsToday(formatDateLong(today)),
              style: const TextStyle(fontSize: 16, color: FaniloColors.inkSoft)),
          if (patients.isEmpty) EmptyState(l.noBeneficiaries, icon: Icons.person_search_outlined),
          if (patients.isNotEmpty && priority.isEmpty && week.isEmpty)
            NoticeCard(tone: NoticeTone.ok, text: l.visitsNone),
          if (priority.isNotEmpty) ...[
            SectionHeader(l.visitsPriority, icon: Icons.priority_high_rounded),
            for (final p in priority)
              PatientCard(patient: p, onTap: () => start(p), action: startButton(p)),
          ],
          if (week.isNotEmpty) ...[
            SectionHeader(l.visitsThisWeek, icon: Icons.event_available),
            for (final p in week)
              PatientCard(
                patient: p,
                onTap: () => start(p),
                detail: ancWhenText(context, p.assessment.next!, today),
                action: startButton(p),
              ),
          ],
          if (others.isNotEmpty) ...[
            SectionHeader(l.visitsOthers, icon: Icons.groups_2_outlined),
            for (final p in others) PatientCard(patient: p, onTap: () => start(p)),
          ],
        ],
      ),
    );
  }
}
