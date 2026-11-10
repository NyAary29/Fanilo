import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../ticket_status.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'home_tab.dart';
import 'info_tab.dart';
import 'my_questions_tab.dart';
import 'settings_sheet.dart';

/// Coque : barre (logo, réglages, « Vonjy maika ») et navigation du bas
/// « Trano · Fampahalalana · Ny fanontaniako ».
class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    // Badge : nombre de NOUVELLES réponses (non lues).
    final unread = ref.watch(ticketStatusProvider).unreadCount(ref.watch(ticketsProvider));
    final l = context.l;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: FaniloLogo(size: 38)),
        actions: [
          IconButton(
            key: const Key('settings-button'),
            tooltip: l.settings,
            iconSize: 28,
            onPressed: () => showSettingsSheet(context),
            icon: const Icon(Icons.tune, color: FaniloColors.forest),
          ),
          const EmergencyAction(),
        ],
      ),
      body: SafeArea(
        child: TicketStatusPoller(
          child: IndexedStack(
          index: tab,
          // Onglets cachés : animations coupées (TickerMode).
          children: [
            TickerMode(enabled: tab == 0, child: const HomeTab()),
            TickerMode(enabled: tab == 1, child: const InfoTab()),
            TickerMode(enabled: tab == 2, child: const MyQuestionsTab()),
          ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => ref.read(tabProvider.notifier).state = i,
        destinations: [
          NavigationDestination(
              key: const Key('nav-home'), icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home), label: l.navHome),
          NavigationDestination(
              key: const Key('nav-info'), icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book), label: l.navInfo),
          NavigationDestination(
            key: const Key('nav-mine'),
            icon: Badge(
                key: const Key('unread-badge'),
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.forum_outlined)),
            selectedIcon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.forum)),
            label: l.navMine,
          ),
        ],
      ),
    );
  }
}
