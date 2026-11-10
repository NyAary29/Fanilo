import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/repositories/local_repository.dart';
import '../../domain/enums.dart';
import '../../domain/follow_up.dart';
import '../labels.dart';
import '../patient_overview.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/patient_card.dart';
import 'alerts_screen.dart';
import 'referrals_screen.dart';
import 'signs_screen.dart';
import 'visit_flow_screen.dart';

/// Fiche patiente : en-tête (initiales, nom, âge, site), bandeau d'alerte,
/// grandes actions, puis trois onglets :
/// - **Suivi** : prochain rappel, grossesse et calendrier CPN (du serveur) ;
/// - **Alertes** : alertes reçues (lecture seule, sans sévérité) ;
/// - **Historique** : consentements et références.
class BeneficiaryDetailScreen extends ConsumerWidget {
  const BeneficiaryDetailScreen({super.key, required this.beneficiaryId});
  final String beneficiaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final b = ref.watch(beneficiaryProvider(beneficiaryId)).valueOrNull;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: Text(l.patientTitle)),
        bottomNavigationBar: const DisclaimerFooter(),
        body: b == null
            ? const Center(child: CircularProgressIndicator())
            : NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(child: _Header(beneficiaryId: beneficiaryId)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(TabBar(
                      tabs: [
                        Tab(
                            key: const Key('tab-follow-up'),
                            icon: const Icon(Icons.monitor_heart_outlined),
                            text: l.tabFollowUp),
                        Tab(
                            key: const Key('tab-alerts'),
                            icon: const Icon(Icons.notifications_outlined),
                            text: l.tabAlerts),
                        Tab(
                            key: const Key('tab-history'),
                            icon: const Icon(Icons.history),
                            text: l.tabHistory),
                      ],
                    )),
                  ),
                ],
                body: TabBarView(children: [
                  _FollowUpTab(beneficiaryId: beneficiaryId),
                  _AlertsTab(beneficiaryId: beneficiaryId),
                  _HistoryTab(beneficiaryId: beneficiaryId),
                ]),
              ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => 72;
  @override
  double get maxExtent => 72;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Material(color: FaniloColors.cream, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.tabBar != tabBar;
}

class _Header extends ConsumerWidget {
  const _Header({required this.beneficiaryId});
  final String beneficiaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final b = ref.watch(beneficiaryProvider(beneficiaryId)).valueOrNull;
    final identity = ref.watch(identityProvider(beneficiaryId)).valueOrNull;
    final overview = ref.watch(patientOverviewProvider(beneficiaryId));
    final sites = ref.watch(sitesByIdProvider).valueOrNull ?? const {};
    final pending = ref.watch(pendingKeysProvider).valueOrNull ?? const {};
    final today = ref.watch(todayProvider);
    final age = approxAge(b?.birthYear, int.parse(today.substring(0, 4)));
    final site = b?.siteId == null ? null : sites[b!.siteId]?.name;
    final openAlerts = overview?.openAlerts ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  PatientAvatar(
                      name: identity?.displayName ?? b?.code,
                      size: 64,
                      alert: openAlerts.isNotEmpty),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(identity?.displayName ?? b?.code ?? l.codePending,
                            key: const Key('patient-name'),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        Text(
                          [
                            if (age != null) l.ageYears(age),
                            if (site != null) site,
                          ].join(' · '),
                          style: const TextStyle(fontSize: 15, color: FaniloColors.inkSoft),
                        ),
                        if (overview != null)
                          Text(pregnancyLine(context, overview),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: FaniloColors.forest)),
                      ],
                    ),
                  ),
                  if (overview != null) StatusChip(status: overview.status),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _InfoPill(icon: Icons.badge_outlined, text: b?.code ?? l.codePending),
                  if (b != null)
                    _InfoPill(
                        icon: Icons.chat_bubble_outline,
                        text: l.channel(PreferredChannel.fromWire(b.preferredChannel))),
                  if (identity?.phone != null)
                    _InfoPill(icon: Icons.phone_outlined, text: identity!.phone!),
                  if (identity?.village != null)
                    _InfoPill(icon: Icons.home_outlined, text: identity!.village!),
                  if (pending.contains('beneficiary/$beneficiaryId')) const PendingChip(),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.lock_outline, size: 15, color: FaniloColors.inkSoft),
                  const SizedBox(width: 4),
                  Text(l.identityConfidential,
                      style: const TextStyle(fontSize: 13, color: FaniloColors.inkSoft)),
                ]),
              ],
            ),
          ),
          if (openAlerts.isNotEmpty)
            NoticeCard(
              key: const Key('patient-alert-banner'),
              tone: NoticeTone.alert,
              title: l.alertBannerTitle,
              text: '${l.alertBannerText}\n${l.alertAwaitingAck}',
              action: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('view-alert'),
                  style: FilledButton.styleFrom(backgroundColor: FaniloColors.alert),
                  onPressed: () => DefaultTabController.of(context).animateTo(1),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(l.viewAlert),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('patient-start-visit'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VisitFlowScreen(beneficiaryId: beneficiaryId))),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(l.actionTodayVisit),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('patient-alert'),
                style: FilledButton.styleFrom(backgroundColor: FaniloColors.alert),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SignsScreen(beneficiaryId: beneficiaryId))),
                icon: const Icon(Icons.campaign_rounded),
                label: Text(l.navAlert),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: FaniloColors.mint, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: FaniloColors.forest),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: FaniloColors.forestDark)),
        ]),
      );
}

// ------------------------------------------------------------------ Suivi

class _FollowUpTab extends ConsumerWidget {
  const _FollowUpTab({required this.beneficiaryId});
  final String beneficiaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final consents = ref.watch(consentsProvider(beneficiaryId)).valueOrNull ?? const [];
    final pregnancies = ref.watch(pregnanciesProvider(beneficiaryId)).valueOrNull ?? const [];
    final overview = ref.watch(patientOverviewProvider(beneficiaryId));
    final today = ref.watch(todayProvider);
    final hasReny =
        consents.any((c) => c.scope == ConsentScope.reny.wire && c.withdrawnAt == null);
    final overdue = overview?.assessment.overdue;
    final next = overview?.assessment.next;

    return ListView(
      key: const Key('follow-up-tab'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (overdue != null)
          NoticeCard(
            tone: NoticeTone.warning,
            icon: Icons.event_busy,
            title: l.ancOverdueTitle,
            text: ancWhenText(context, overdue, today),
          ),
        if (next != null) NextReminderCard(text: ancWhenText(context, next, today)),
        SectionHeader(l.pregnancyTitle, icon: Icons.pregnant_woman),
        if (pregnancies.isEmpty) ...[
          NoticeCard(text: hasReny ? l.noPregnancy : l.needRenyConsent),
          FilledButton.icon(
            key: const Key('declare-pregnancy'),
            onPressed: hasReny ? () => _declarePregnancy(context, ref) : null,
            icon: const Icon(Icons.pregnant_woman),
            label: Text(l.declarePregnancy),
          ),
        ],
        for (final p in pregnancies) _PregnancyCard(pregnancy: p),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('refer-beneficiary'),
          onPressed: () => showNewReferralSheet(context, beneficiaryId: beneficiaryId),
          icon: const Icon(Icons.local_hospital_outlined),
          label: Text(l.referralRefer),
        ),
      ],
    );
  }

  Future<void> _declarePregnancy(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<PregnancyDates>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PregnancyDatesForm(title: context.l10n.declarePregnancy),
    );
    if (result == null) return;
    try {
      await ref.read(localRepositoryProvider).createPregnancy(
          beneficiaryId: beneficiaryId,
          lmpDate: result.lmpDate,
          estimatedDueDate: result.estimatedDueDate,
          confirmedBy: result.confirmedBy);
      ref.read(syncServiceProvider).sync();
    } on NoActiveRenyConsentException {
      if (context.mounted) showSnack(context, context.l10n.needRenyConsent);
    } on InvalidPregnancyDatesException catch (e) {
      if (context.mounted) showSnack(context, datesErrorText(context, e.error));
    }
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
    final today = ref.watch(todayProvider);
    final firstPlanned = visits
        .where((v) => v.status == AncVisitStatus.planned.wire)
        .fold<AncVisitRow?>(null, (a, v) => a == null || v.sequence < a.sequence ? v : a);

    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(icon, size: 18, color: FaniloColors.inkSoft),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15.5))),
          ]),
        );

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  const BoxDecoration(color: FaniloColors.mint, shape: BoxShape.circle),
              child: const Icon(Icons.pregnant_woman, color: FaniloColors.forest),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l.pregnancyStatus(pregnancy.status),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            if (pending.contains('pregnancy/${pregnancy.id}'))
              const Flexible(child: PendingChip()),
          ]),
          const SizedBox(height: 6),
          if (pregnancy.lmpDate != null)
            line(Icons.water_drop_outlined,
                '${l.lmpDate.split(' (').first} : ${formatDateLong(pregnancy.lmpDate)}'),
          if (pregnancy.estimatedDueDate != null)
            line(Icons.child_friendly_outlined,
                '${l.dueDate.split(' (').first} : ${formatDateLong(pregnancy.estimatedDueDate)}'),
          line(Icons.verified_outlined,
              '${l.confirmedBy} : ${l.confirmedByLabel(_confirmedBy(pregnancy))}'),
          if (pregnancy.status == PregnancyStatus.active.wire)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('edit-pregnancy-dates-${pregnancy.id}'),
                onPressed: () => _editDates(context, ref),
                icon: const Icon(Icons.edit_calendar),
                label: Text(l.editPregnancyDates),
              ),
            ),
          const Divider(height: 20),
          Row(children: [
            const Icon(Icons.calendar_month, color: FaniloColors.forest),
            const SizedBox(width: 8),
            Text(l.ancCalendar,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
          if (visits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              // Le serveur ne génère le calendrier qu'avec une date de
              // référence (dernières règles ou terme estimé).
              child: Text(
                  pregnancy.version > 0 &&
                          pregnancy.lmpDate == null &&
                          pregnancy.estimatedDueDate == null
                      ? l.ancNeedsLmp
                      : l.ancWaiting,
                  style: const TextStyle(fontSize: 15.5)),
            ),
          for (final v in visits)
            _AncVisitTile(
              visit: v,
              today: today,
              canMark: v.id == firstPlanned?.id,
              pending: pending.contains('anc_visit/${v.id}'),
            ),
        ],
      ),
    );
  }

  Future<void> _editDates(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final result = await showModalBottomSheet<PregnancyDates>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PregnancyDatesForm(
        title: l.editPregnancyDates,
        initial: PregnancyDates(
          lmpDate: pregnancy.lmpDate,
          estimatedDueDate: pregnancy.estimatedDueDate,
          confirmedBy: _confirmedBy(pregnancy),
        ),
      ),
    );
    if (result == null) return;
    try {
      await ref.read(localRepositoryProvider).updatePregnancyDates(pregnancy.id,
          lmpDate: result.lmpDate,
          estimatedDueDate: result.estimatedDueDate,
          confirmedBy: result.confirmedBy);
      if (context.mounted) showSnack(context, l.datesSaved);
      ref.read(syncServiceProvider).sync();
    } on InvalidPregnancyDatesException catch (e) {
      if (context.mounted) showSnack(context, datesErrorText(context, e.error));
    } on InvalidStateException catch (e) {
      if (context.mounted) showSnack(context, e.message);
    }
  }
}

DatesConfirmedBy _confirmedBy(PregnancyRow p) => DatesConfirmedBy.values.firstWhere(
    (c) => c.wire == p.datesConfirmedBy,
    orElse: () => DatesConfirmedBy.acDeclared);

String datesErrorText(BuildContext context, PregnancyDatesError e) {
  final l = context.l10n;
  return switch (e) {
    PregnancyDatesError.lmpInFuture => l.datesLmpInFuture,
    PregnancyDatesError.lmpTooOld => l.datesLmpTooOld,
    PregnancyDatesError.dueBeforeLmp => l.datesDueBeforeLmp,
  };
}

/// Une CPN du calendrier (date du serveur). Seule la première CPN prévue
/// peut être marquée réalisée ou manquée.
class _AncVisitTile extends ConsumerWidget {
  const _AncVisitTile({
    required this.visit,
    required this.today,
    required this.canMark,
    required this.pending,
  });
  final AncVisitRow visit;
  final String today;
  final bool canMark;
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
    final status = AncVisitStatus.fromWire(visit.status);
    final late = status == AncVisitStatus.planned && visit.scheduledDate.compareTo(today) < 0;
    final (icon, color) = switch (status) {
      AncVisitStatus.done => (Icons.check_circle, FaniloColors.ok),
      AncVisitStatus.missed => (Icons.cancel, FaniloColors.alert),
      AncVisitStatus.cancelled => (Icons.remove_circle_outline, FaniloColors.inkSoft),
      AncVisitStatus.planned =>
        late ? (Icons.error_outline, FaniloColors.follow) : (Icons.radio_button_unchecked, FaniloColors.forest),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l.ancVisit(visit.sequence, formatDate(visit.scheduledDate)),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Text(late ? l.overdue : l.ancStatus(visit.status),
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: color)),
            if (pending)
              const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.cloud_upload_outlined, size: 18, color: FaniloColors.follow)),
          ]),
          if (canMark)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 36),
              child: Row(children: [
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
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Alertes

class _AlertsTab extends ConsumerWidget {
  const _AlertsTab({required this.beneficiaryId});
  final String beneficiaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final alerts = (ref.watch(alertsProvider).valueOrNull ?? const [])
        .where((a) => a.beneficiaryId == beneficiaryId)
        .toList();
    return ListView(
      key: const Key('alerts-tab'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        NoticeCard(text: l.alertsReadOnly),
        if (alerts.isEmpty)
          EmptyState(l.noAlertsForPatient, icon: Icons.notifications_none),
        for (final a in alerts) AlertTile(alert: a, showPatient: false),
      ],
    );
  }
}

// ------------------------------------------------------------- Historique

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.beneficiaryId});
  final String beneficiaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final consents = ref.watch(consentsProvider(beneficiaryId)).valueOrNull ?? const [];
    final pending = ref.watch(pendingKeysProvider).valueOrNull ?? const {};
    final referrals = (ref.watch(referralsProvider).valueOrNull ?? const [])
        .where((r) => r.beneficiaryId == beneficiaryId)
        .toList();
    final sites = ref.watch(sitesByIdProvider).valueOrNull ?? const {};
    return ListView(
      key: const Key('history-tab'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        SectionHeader(l.consentsTitle, icon: Icons.verified_user_outlined),
        for (final c in consents) _ConsentTile(consent: c, pending: pending),
        SectionHeader(l.referralsTitle, icon: Icons.local_hospital_outlined),
        if (referrals.isEmpty) NoticeCard(text: l.noReferrals),
        for (final r in referrals)
          SoftCard(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => ReferralTransitionSheet(referral: r),
            ),
            child: Row(children: [
              const Icon(Icons.local_hospital, color: FaniloColors.forest, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.referralTo(sites[r.toSiteId]?.name ?? '—'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                      [
                        l.referralStatus(r.status),
                        if (r.reason != null) r.reason!,
                        if (pending.contains('referral/${r.id}')) l.pendingSync,
                      ].join(' · '),
                      style: const TextStyle(color: FaniloColors.inkSoft)),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
      ],
    );
  }
}

class _ConsentTile extends ConsumerWidget {
  const _ConsentTile({required this.consent, required this.pending});
  final ConsentRow consent;
  final Set<String> pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final active = consent.withdrawnAt == null;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(children: [
        Icon(active ? Icons.check_circle : Icons.cancel,
            size: 28, color: active ? FaniloColors.ok : FaniloColors.inkSoft),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.consentScope(consent.scope),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(
                '${active ? l.consentActive : l.consentWithdrawn} · ${l.consentMethodLabel(consent.method)} · '
                '${consent.informationVersion} · ${formatDate(consent.collectedAt)}'
                '${pending.contains('consent/${consent.id}') ? '\n${l.pendingSync}' : ''}',
                style: const TextStyle(fontSize: 14, color: FaniloColors.inkSoft)),
          ]),
        ),
        if (active)
          TextButton(
            onPressed: () async {
              final user = ref.read(authProvider).user;
              if (user == null) return;
              if (!await confirmDialog(context, l.withdrawConfirm)) return;
              await ref.read(localRepositoryProvider).withdrawConsent(consent.id, user);
              ref.read(syncServiceProvider).sync();
            },
            child: Text(l.withdraw),
          ),
      ]),
    );
  }
}

/// Dates saisies par l'AC (jamais calculées par l'application).
class PregnancyDates {
  const PregnancyDates({this.lmpDate, this.estimatedDueDate, required this.confirmedBy});
  final String? lmpDate;
  final String? estimatedDueDate;
  final DatesConfirmedBy confirmedBy;
}

/// Saisie des dates d'une grossesse : dernières règles et terme prévu
/// (facultatifs, chacun effaçable), source des dates.
class PregnancyDatesForm extends StatefulWidget {
  const PregnancyDatesForm({super.key, required this.title, this.initial});
  final String title;
  final PregnancyDates? initial;

  @override
  State<PregnancyDatesForm> createState() => _PregnancyDatesFormState();
}

class _PregnancyDatesFormState extends State<PregnancyDatesForm> {
  DateTime? _lmp;
  DateTime? _due;
  DatesConfirmedBy _by = DatesConfirmedBy.acDeclared;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _lmp = i.lmpDate == null ? null : DateTime.tryParse(i.lmpDate!);
      _due = i.estimatedDueDate == null ? null : DateTime.tryParse(i.estimatedDueDate!);
      _by = i.confirmedBy;
    }
  }

  static String? _wire(DateTime? d) => d?.toIso8601String().substring(0, 10);

  Widget _dateRow({
    required Key key,
    required String label,
    required DateTime? value,
    required DateTime first,
    required DateTime last,
    required ValueChanged<DateTime?> onChanged,
  }) =>
      Row(children: [
        Expanded(
          child: OutlinedButton(
            key: key,
            child: Row(children: [
              const Icon(Icons.calendar_month),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    value == null
                        ? label
                        : '${label.split(' (').first} : ${formatDate(_wire(value))}',
                    softWrap: true),
              ),
            ]),
            onPressed: () async {
              final now = DateTime.now();
              final initial = value ?? (now.isAfter(last) ? last : now);
              final d = await showDatePicker(
                context: context,
                firstDate: first,
                lastDate: last,
                initialDate: initial.isBefore(first) ? first : initial,
              );
              if (d != null) onChanged(d);
            },
          ),
        ),
        if (value != null)
          IconButton(
            tooltip: context.l10n.clearDate,
            icon: const Icon(Icons.clear),
            onPressed: () => onChanged(null),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = DateTime.now();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _dateRow(
            key: const Key('lmp-date'),
            label: l.lmpDate,
            value: _lmp,
            first: now.subtract(const Duration(days: 320)),
            last: now,
            onChanged: (d) => setState(() => _lmp = d),
          ),
          const SizedBox(height: 8),
          _dateRow(
            key: const Key('due-date'),
            label: l.dueDate,
            value: _due,
            first: now.subtract(const Duration(days: 60)),
            last: now.add(const Duration(days: 320)),
            onChanged: (d) => setState(() => _due = d),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DatesConfirmedBy>(
            initialValue: _by,
            decoration: InputDecoration(labelText: l.confirmedBy),
            items: [
              for (final c in DatesConfirmedBy.values)
                DropdownMenuItem(value: c, child: Text(l.confirmedByLabel(c))),
            ],
            onChanged: (v) => setState(() => _by = v ?? DatesConfirmedBy.acDeclared),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('save-pregnancy-dates'),
            onPressed: () => Navigator.pop(
                context,
                PregnancyDates(
                    lmpDate: _wire(_lmp), estimatedDueDate: _wire(_due), confirmedBy: _by)),
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}
