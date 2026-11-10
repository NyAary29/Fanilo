import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_store.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/consent.dart';

/// Réglages : langue, accord pour la voix, lieu (CSB).
Future<void> showSettingsSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SettingsSheet(),
    );

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final consent = ref.watch(voiceConsentProvider);
    final site = ref.watch(siteProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.settings, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          IconLine(icon: Icons.translate, text: l.language),
          const LanguageToggle(),
          const SizedBox(height: 16),
          IconLine(
              icon: consent != null ? Icons.mic : Icons.mic_off,
              text: consent != null ? l.voiceOn : l.voiceOff),
          if (consent != null)
            OutlinedButton.icon(
              key: const Key('withdraw-consent'),
              onPressed: () => ref.read(voiceConsentProvider.notifier).withdraw(),
              icon: const Icon(Icons.mic_off),
              label: Text(l.withdrawConsent),
            )
          else
            FilledButton.icon(
              key: const Key('give-consent'),
              onPressed: () => showVoiceConsentSheet(context),
              icon: const Icon(Icons.mic),
              label: Text(l.accept),
            ),
          const SizedBox(height: 16),
          IconLine(icon: Icons.place, text: '${l.place} : ${site?.name ?? l.noSite}'),
          OutlinedButton.icon(
            key: const Key('change-site'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const _SiteScreen())),
            icon: const Icon(Icons.edit_location_alt),
            label: Text(l.whereLive),
          ),
          if (site != null)
            TextButton.icon(
              onPressed: () => ref.read(siteProvider.notifier).set(null),
              icon: const Icon(Icons.close),
              label: Text(l.delete),
            ),
          const SizedBox(height: 16),
          // Malgache non relu : rappel visible.
          IconLine(icon: Icons.rate_review, text: l.unreviewedMg, color: FaniloColors.demo),
          const ScreenFooter(),
        ]),
      ),
    );
  }
}

class _SiteScreen extends ConsumerWidget {
  const _SiteScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(context.l.whereLive), actions: const [EmergencyAction()]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(context.l.whereLiveHelp,
              style: const TextStyle(fontSize: 16, color: FaniloColors.inkSoft)),
          const SizedBox(height: 12),
          SitePicker(onPicked: (s) async {
            await ref.read(siteProvider.notifier).set(SavedSite(s.id, s.name));
            if (context.mounted) Navigator.of(context).pop();
          }),
        ]),
      );
}
