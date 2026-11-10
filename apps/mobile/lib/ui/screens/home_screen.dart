import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo/demo_seeder.dart';
import '../../domain/follow_up.dart';
import '../labels.dart';
import '../patient_overview.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import '../widgets/patient_card.dart';
import 'alerts_screen.dart';
import 'beneficiary_detail_screen.dart';
import 'conflicts_screen.dart';
import 'login_screen.dart';
import 'referrals_screen.dart';
import 'registration_screen.dart';
import 'signs_screen.dart';
import 'visits_screen.dart';

void openScreen(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

/// Écran principal de l'agent connecté : trois onglets en bas
/// (Accueil · Mes visites · Alerter) et la mention permanente.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Démarre la synchronisation automatique tant que l'écran est monté.
    ref.watch(syncSchedulerProvider);
    // Conseils de visite : copie locale rafraîchie après chaque synchro.
    ref.listen(lastSyncAtProvider, (_, next) {
      if (next.valueOrNull != null) {
        ref.read(referenceRepositoryProvider).refreshContents();
      }
    });
    final l = context.l10n;
    final tab = ref.watch(homeTabProvider);
    final toFollow =
        ref
            .watch(patientOverviewsProvider)
            .where((p) => p.status == FollowUpStatus.toFollow)
            .length;

    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [HomeTab(), VisitsTab(), SignsScreen(embedded: true)],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DisclaimerFooter(safeArea: false),
          NavigationBar(
            key: const Key('main-nav'),
            selectedIndex: tab,
            onDestinationSelected: (i) => ref.read(homeTabProvider.notifier).state = i,
            destinations: [
              NavigationDestination(
                key: const Key('nav-home'),
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: l.navHome,
              ),
              NavigationDestination(
                key: const Key('nav-visits'),
                icon: Badge(
                  isLabelVisible: toFollow > 0,
                  backgroundColor: FaniloColors.follow,
                  label: Text('$toFollow'),
                  child: const Icon(Icons.event_note_outlined),
                ),
                selectedIcon: const Icon(Icons.event_note),
                label: l.navVisits,
              ),
              NavigationDestination(
                key: const Key('nav-alert'),
                icon: const Icon(Icons.campaign_outlined, color: FaniloColors.alert),
                selectedIcon: const Icon(Icons.campaign, color: FaniloColors.alert),
                label: l.navAlert,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Onglet « Accueil » : salutation, synchro, grandes actions, patientes.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = ref.watch(authProvider);
    final conflicts =
        (ref.watch(conflictsProvider).valueOrNull?.length ?? 0) +
        (ref.watch(rejectedProvider).valueOrNull?.length ?? 0);
    final openAlerts = ref.watch(openAlertsProvider).valueOrNull?.length ?? 0;
    final patients = ref.watch(patientOverviewsProvider);
    final toFollow = patients.where((p) => p.status == FollowUpStatus.toFollow).length;
    final q = _query.trim().toLowerCase();
    final filtered =
        q.isEmpty
            ? patients
            : patients
                .where(
                  (p) =>
                      (p.name?.toLowerCase().contains(q) ?? false) ||
                      (p.beneficiary.code?.toLowerCase().contains(q) ?? false),
                )
                .toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: const Key('home-list'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [const FaniloLogo(size: 40), const Spacer(), _HomeMenu(onLogout: _logout)],
            ),
            const SizedBox(height: 16),
            Text(
              l.greeting(auth.user?.login ?? ''),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: FaniloColors.forestDark),
            ),
            Text(l.greetingSub, style: const TextStyle(fontSize: 16, color: FaniloColors.inkSoft)),
            const SizedBox(height: 12),
            if (auth.needsReauth)
              NoticeCard(
                tone: NoticeTone.alert,
                icon: Icons.lock_clock,
                text: l.reauthBanner,
                action: FilledButton.icon(
                  onPressed: () => openScreen(context, const LoginScreen(isReauth: true)),
                  icon: const Icon(Icons.login),
                  label: Text(l.reauthButton),
                ),
              ),
            const SyncCard(),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ActionCard(
                      key: const Key('action-new-patient'),
                      icon: Icons.person_add_alt_1,
                      label: l.actionNewPatient,
                      subtitle: l.actionNewPatientSub,
                      onTap: () => openScreen(context, const RegistrationScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionCard(
                      key: const Key('action-today-visit'),
                      icon: Icons.fact_check_outlined,
                      label: l.actionTodayVisit,
                      subtitle: l.toSeeCount(toFollow),
                      background: FaniloColors.mintStrong,
                      foreground: FaniloColors.forestDark,
                      onTap: () => ref.read(homeTabProvider.notifier).state = 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ShortcutTile(
                    key: const Key('shortcut-alerts'),
                    icon: Icons.notifications_active_outlined,
                    label: l.menuAlerts,
                    badge: openAlerts,
                    color: FaniloColors.alert,
                    onTap: () => openScreen(context, const AlertsScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShortcutTile(
                    key: const Key('shortcut-referrals'),
                    icon: Icons.local_hospital_outlined,
                    label: l.menuReferrals,
                    onTap: () => openScreen(context, const ReferralsScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShortcutTile(
                    key: const Key('shortcut-conflicts'),
                    icon: Icons.sync_problem_outlined,
                    label: l.menuConflicts,
                    badge: conflicts,
                    color: conflicts > 0 ? FaniloColors.follow : FaniloColors.forest,
                    onTap: () => openScreen(context, const ConflictsScreen()),
                  ),
                ),
              ],
            ),
            SectionHeader(
              l.myPatients,
              icon: Icons.groups_2_outlined,
              trailing: Text(
                '${patients.length}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: FaniloColors.inkSoft,
                ),
              ),
            ),
            TextField(
              key: const Key('patient-search'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.searchPatient,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 6),
            if (filtered.isEmpty)
              EmptyState(
                patients.isEmpty ? l.noBeneficiaries : l.noSearchResult,
                icon: Icons.person_search_outlined,
              ),
            for (final p in filtered)
              PatientCard(
                patient: p,
                onTap: () => openScreen(context, BeneficiaryDetailScreen(beneficiaryId: p.id)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final l = context.l10n;
    final pending = ref.read(pendingCountProvider).valueOrNull ?? 0;
    final ok = await confirmDialog(
      context,
      pending > 0 ? l.logoutConfirmPending(pending) : l.logoutConfirm,
    );
    if (!ok) return;
    ref.read(homeTabProvider.notifier).state = 0;
    await ref.read(databaseProvider).wipe();
    await ref.read(authProvider.notifier).logout();
  }
}

class _HomeMenu extends ConsumerWidget {
  const _HomeMenu({required this.onLogout});
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    PopupMenuItem<String> item(String value, IconData icon, String text) => PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: FaniloColors.forest),
          const SizedBox(width: 12),
          Flexible(child: Text(text)),
        ],
      ),
    );
    return PopupMenuButton<String>(
      key: const Key('home-menu'),
      icon: const Icon(Icons.more_vert, size: 28, color: FaniloColors.forest),
      onSelected: (v) async {
        switch (v) {
          case 'logout':
            await onLogout();
          case 'referrals':
            openScreen(context, const ReferralsScreen());
          case 'conflicts':
            openScreen(context, const ConflictsScreen());
          case 'demo':
            await DemoSeeder(
              ref.read(databaseProvider),
            ).seed(siteId: ref.read(authProvider).user?.siteId);
            if (context.mounted) showSnack(context, l.demoDataLoaded);
        }
      },
      itemBuilder:
          (_) => [
            item('referrals', Icons.local_hospital_outlined, l.menuReferrals),
            item('conflicts', Icons.sync_problem_outlined, l.menuConflicts),
            if (kDebugMode) item('demo', Icons.science_outlined, l.demoData),
            item('logout', Icons.logout, l.logout),
          ],
    );
  }
}

/// Indicateur de synchronisation : réseau, dernière synchro, éléments en
/// attente, refus, et bouton manuel.
class SyncCard extends ConsumerWidget {
  const SyncCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final online = ref.watch(onlineProvider).valueOrNull ?? false;
    final running = ref.watch(syncRunningProvider).valueOrNull ?? false;
    final pending = ref.watch(pendingCountProvider).valueOrNull ?? 0;
    final rejected = ref.watch(rejectedProvider).valueOrNull?.length ?? 0;
    final lastAt = ref.watch(lastSyncAtProvider).valueOrNull;
    final error = l.syncError(ref.watch(lastSyncErrorProvider).valueOrNull);
    final today = ref.watch(todayProvider);

    final upToDate = pending == 0 && lastAt != null && rejected == 0 && error == null;
    final (icon, color, bg) =
        pending > 0 || rejected > 0
            ? (Icons.cloud_upload_rounded, FaniloColors.follow, FaniloColors.followSoft)
            : upToDate
            ? (Icons.check_circle_rounded, FaniloColors.ok, FaniloColors.okSoft)
            : (Icons.cloud_off_rounded, FaniloColors.inkSoft, FaniloColors.mint);

    return SoftCard(
      key: const Key('sync-card'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      upToDate ? l.syncUpToDate : l.syncPending(pending),
                      key: const Key('pending-count'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      lastAt == null ? l.syncNever : l.syncLast(formatSyncTime(lastAt, today)),
                      style: const TextStyle(fontSize: 14.5, color: FaniloColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error,
                style: const TextStyle(color: FaniloColors.alertInk, fontSize: 14.5),
              ),
            ),
          if (rejected > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.rejectedCount(rejected),
                style: const TextStyle(color: FaniloColors.alertInk, fontWeight: FontWeight.w800),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              _OnlinePill(online: online),
              TextButton.icon(
                key: const Key('sync-button'),
                style: TextButton.styleFrom(minimumSize: const Size(48, kTouch)),
                onPressed:
                    running
                        ? null
                        : () async {
                          final r = await ref.read(syncServiceProvider).sync(force: true);
                          ref.read(referenceRepositoryProvider).refreshContents(force: true);
                          if (!context.mounted) return;
                          showSnack(context, l.syncError(r.error) ?? l.syncDone);
                        },
                icon:
                    running
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.sync),
                label: Text(running ? l.syncRunning : l.syncNow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnlinePill extends StatelessWidget {
  const _OnlinePill({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: online ? FaniloColors.okSoft : FaniloColors.alertSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            online ? Icons.wifi : Icons.wifi_off,
            size: 18,
            color: online ? FaniloColors.ok : FaniloColors.alertInk,
          ),
          const SizedBox(width: 6),
          Text(
            online ? l.online : l.offline,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: online ? FaniloColors.forestDark : FaniloColors.alertInk,
            ),
          ),
        ],
      ),
    );
  }
}
