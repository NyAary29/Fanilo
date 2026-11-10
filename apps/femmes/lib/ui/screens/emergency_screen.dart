import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/emergency.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Conduite à tenir en cas d'urgence. Générique : FANILO n'appelle personne
/// et ne promet aucune prise en charge.
class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = ref.watch(siteProvider);
    final l = context.l;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.sos, color: FaniloColors.alert),
          const SizedBox(width: 8),
          Text(l.emergency, style: const TextStyle(color: FaniloColors.alertInk)),
        ]),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const UrgentBlock(),
            const SizedBox(height: 16),
            if (site != null)
              IconLine(icon: Icons.place, text: l.emergencyYourCsb(site.name)),
            IconLine(icon: Icons.phone_disabled, text: l.emergencyNoCall, color: FaniloColors.alert),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.rule, color: FaniloColors.forest),
                    const SizedBox(width: 8),
                    Text(l.localProcedure, style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 8),
                  const Text(kLocalEmergencyProcedure,
                      key: Key('local-procedure'), style: TextStyle(fontSize: 15)),
                ]),
              ),
            ),
            const ScreenFooter(),
          ],
        ),
      ),
    );
  }
}
