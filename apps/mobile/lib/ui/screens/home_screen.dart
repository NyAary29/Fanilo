import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo/demo_seeder.dart';
import '../labels.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'alerts_screen.dart';
import 'beneficiaries_screen.dart';
import 'beneficiary_detail_screen.dart';
import 'conflicts_screen.dart';
import 'login_screen.dart';
import 'referrals_screen.dart';
import 'registration_screen.dart';
import 'signs_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Démarre la synchronisation automatique tant que l'accueil est monté.
    ref.watch(syncSchedulerProvider);
    final l = context.l10n;
    final auth = ref.watch(authProvider);
    final conflicts = ref.watch(conflictsProvider).valueOrNull?.length ?? 0;
    final openAlerts = ref.watch(openAlertsProvider).valueOrNull?.length ?? 0;

    return FaniloScaffold(
      title: l.homeTitle,
      actions: [
        PopupMenuButton<String>(
          key: const Key('home-menu'),
          onSelected: (v) async {
            if (v == 'logout') await _logout(context, ref);
            if (v == 'demo' && context.mounted) {
              await DemoSeeder(ref.read(databaseProvider))
                  .seed(siteId: auth.user?.siteId);
              if (context.mounted) showSnack(context, l.demoDataLoaded);
            }
          },
          itemBuilder: (_) => [
            if (kDebugMode) PopupMenuItem(value: 'demo', child: Text(l.demoData)),
            PopupMenuItem(value: 'logout', child: Text(l.logout)),
          ],
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (auth.needsReauth)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.lock_clock),
                title: Text(l.reauthBanner),
                trailing: TextButton(
                  onPressed: () =>
                      _open(context, const LoginScreen(isReauth: true)),
                  child: Text(l.reauthButton),
                ),
              ),
            ),
          const SyncCard(),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              BigTile(
                  icon: Icons.person_add_alt_1,
                  label: l.menuRegister,
                  onTap: () => _open(context, const RegistrationScreen())),
              BigTile(
                  icon: Icons.people,
                  label: l.menuBeneficiaries,
                  onTap: () => _open(context, const BeneficiariesScreen())),
              BigTile(
                  icon: Icons.health_and_safety,
                  label: l.menuSigns,
                  onTap: () => _open(context, const SignsScreen())),
              BigTile(
                  icon: Icons.notifications_active,
                  label: l.menuAlerts,
                  badge: openAlerts > 0 ? '$openAlerts' : null,
                  onTap: () => _open(context, const AlertsScreen())),
              BigTile(
                  icon: Icons.local_hospital,
                  label: l.menuReferrals,
                  onTap: () => _open(context, const ReferralsScreen())),
              BigTile(
                  icon: Icons.sync_problem,
                  label: l.menuConflicts,
                  badge: conflicts > 0 ? '$conflicts' : null,
                  onTap: () => _open(context, const ConflictsScreen())),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(l.openAlerts(openAlerts)),
              onTap: () => _open(context, const AlertsScreen()),
            ),
          ),
          const UpcomingAncCard(),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final pending = ref.read(pendingCountProvider).valueOrNull ?? 0;
    final ok = await confirmDialog(
        context, pending > 0 ? l.logoutConfirmPending(pending) : l.logoutConfirm);
    if (!ok) return;
    await ref.read(databaseProvider).wipe();
    await ref.read(authProvider.notifier).logout();
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
    final scheme = Theme.of(context).colorScheme;

    return Card(
      key: const Key('sync-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(online ? Icons.wifi : Icons.wifi_off,
                  color: online ? Colors.green.shade700 : scheme.error),
              const SizedBox(width: 8),
              Text(online ? l.online : l.offline,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Icon(pending > 0 ? Icons.cloud_upload : Icons.cloud_done,
                  color: pending > 0 ? Colors.orange.shade800 : Colors.green.shade700),
            ]),
            const SizedBox(height: 8),
            Text(l.syncPending(pending),
                key: const Key('pending-count'),
                style: const TextStyle(fontSize: 16)),
            Text(lastAt == null ? l.syncNever : l.syncLast(formatDateTime(lastAt))),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(error, style: TextStyle(color: scheme.error)),
              ),
            if (rejected > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l.rejectedCount(rejected),
                    style: TextStyle(
                        color: scheme.error, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('sync-button'),
                onPressed: running
                    ? null
                    : () async {
                        final r = await ref
                            .read(syncServiceProvider)
                            .sync(force: true);
                        if (!context.mounted) return;
                        showSnack(context,
                            l.syncError(r.error) ?? l.syncDone);
                      },
                icon: running
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync),
                label: Text(running ? l.syncRunning : l.syncNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpcomingAncCard extends ConsumerWidget {
  const UpcomingAncCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final visits = ref.watch(upcomingAncProvider).valueOrNull ?? const [];
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.event),
            title: Text(l.upcomingAnc,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (visits.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(l.noUpcomingAnc),
            ),
          for (final v in visits)
            ListTile(
              title: Text(l.ancVisit(v.sequence, formatDate(v.scheduledDate))),
              subtitle: v.scheduledDate.compareTo(today) < 0
                  ? Text(l.overdue,
                      style: TextStyle(color: Theme.of(context).colorScheme.error))
                  : Text(l.ancStatus(v.status)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final bId = await ref
                    .read(localRepositoryProvider)
                    .beneficiaryIdForPregnancy(v.pregnancyId);
                if (bId != null && context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BeneficiaryDetailScreen(beneficiaryId: bId)));
                }
              },
            ),
        ],
      ),
    );
  }
}
