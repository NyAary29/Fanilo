import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/models.dart';
import '../providers.dart';
import '../theme.dart';
import 'common.dart';

/// Version de l'information « voice_processing » acceptée. Si l'API n'a pas
/// répondu, seule l'information locale (textes de l'application) a été vue.
String voiceInfoVersion(AsyncValue<List<InformationItem>> info) {
  final items = info.valueOrNull ?? const <InformationItem>[];
  for (final i in items) {
    if (i.scope == 'voice_processing') return i.version;
  }
  return 'app-local';
}

/// Résumés servis par `GET /public/information` pour les portées données.
class ServerInformation extends ConsumerWidget {
  const ServerInformation({super.key, required this.scopes});
  final List<String> scopes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(informationProvider);
    final lang = ref.watch(languageProvider);
    return info.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
      error: (_, _) => IconLine(icon: Icons.wifi_off, text: context.l.infoUnavailable),
      data: (items) {
        final shown = [
          for (final s in scopes) ...items.where((i) => i.scope == s),
        ];
        if (shown.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (shown.any((i) => !i.isValidated)) const DemoBanner(),
          for (final i in shown)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: FaniloColors.mint, borderRadius: BorderRadius.circular(12)),
                child: Text(i.summary(lang),
                    key: Key('info-${i.scope}'), style: const TextStyle(fontSize: 15)),
              ),
            ),
        ]);
      },
    );
  }
}

/// Explication et boutons « Ekena / J'accepte » pour la voix.
class VoiceConsentPanel extends ConsumerWidget {
  const VoiceConsentPanel({super.key, required this.onDone});

  /// Appelé avec `true` si l'utilisatrice accepte.
  final ValueChanged<bool> onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: FaniloColors.mintStrong, shape: BoxShape.circle),
          child: const Icon(Icons.mic, size: 36, color: FaniloColors.forest),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(l.voiceConsentTitle, style: Theme.of(context).textTheme.headlineSmall)),
      ]),
      const SizedBox(height: 12),
      IconLine(icon: Icons.record_voice_over, text: l.voiceConsentBody),
      IconLine(icon: Icons.delete_forever, text: l.welcomeAudio),
      IconLine(icon: Icons.edit, text: l.voiceLater),
      const ServerInformation(scopes: ['voice_processing']),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('voice-accept'),
        onPressed: () async {
          await ref
              .read(voiceConsentProvider.notifier)
              .accept(voiceInfoVersion(ref.read(informationProvider)));
          onDone(true);
        },
        icon: const Icon(Icons.check_circle, size: 28),
        label: Text(l.accept),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        key: const Key('voice-decline'),
        onPressed: () => onDone(false),
        icon: const Icon(Icons.keyboard, size: 26),
        label: Text(l.notNow),
      ),
    ]);
  }
}

/// Feuille modale d'accord pour la voix ; renvoie `true` si acceptée.
Future<bool> showVoiceConsentSheet(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: VoiceConsentPanel(onDone: (v) => Navigator.of(ctx).pop(v)),
      ),
    ),
  );
  return ok ?? false;
}

/// Sélecteur MG / FR.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(localeProvider).languageCode;
    return SegmentedButton<String>(
      key: const Key('language-toggle'),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 'mg', label: Text('Malagasy')),
        ButtonSegment(value: 'fr', label: Text('Français')),
      ],
      selected: {code},
      onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(s.first),
    );
  }
}

/// Liste des CSB (facultatif). Renvoie le site choisi via [onPicked].
class SitePicker extends ConsumerStatefulWidget {
  const SitePicker({super.key, required this.onPicked});
  final ValueChanged<Site> onPicked;

  @override
  ConsumerState<SitePicker> createState() => _SitePickerState();
}

class _SitePickerState extends ConsumerState<SitePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(sitesProvider);
    final selected = ref.watch(siteProvider);
    return sites.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Column(children: [
        IconLine(icon: Icons.wifi_off, text: apiErrorMessage(context, e)),
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(sitesProvider),
          icon: const Icon(Icons.refresh),
          label: Text(context.l.retry),
        ),
      ]),
      data: (items) {
        final q = _q.toLowerCase();
        final shown = items
            .where((s) => q.isEmpty || '${s.name} ${s.place}'.toLowerCase().contains(q))
            .toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (items.length > 6)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search), hintText: context.l.searchHint),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
          for (final s in shown)
            Card(
              color: selected?.id == s.id ? FaniloColors.mintStrong : null,
              child: ListTile(
                key: Key('site-${s.id}'),
                leading: const Icon(Icons.local_hospital, color: FaniloColors.forest, size: 30),
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: s.place.isEmpty ? null : Text(s.place),
                trailing: selected?.id == s.id
                    ? const Icon(Icons.check_circle, color: FaniloColors.forest)
                    : null,
                onTap: () => widget.onPicked(s),
              ),
            ),
        ]);
      },
    );
  }
}
