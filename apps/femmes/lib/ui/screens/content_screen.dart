import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Carte d'un contenu publié : titre, texte, bouton « Henoy » si audio.
class ContentCard extends ConsumerStatefulWidget {
  const ContentCard({super.key, required this.content, this.module, this.showDemo = true});
  final Content content;
  final Module? module;

  /// Faux si l'écran affiche déjà le bandeau DÉMO.
  final bool showDemo;

  @override
  ConsumerState<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends ConsumerState<ContentCard> {
  bool _playing = false;
  late final _player = ref.read(playbackProvider);

  @override
  void initState() {
    super.initState();
    _player; // lu tant que l'élément est actif (utilisé dans dispose).
  }

  Future<void> _toggle() async {
    final player = _player;
    if (_playing) {
      await player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    // `audio_url` peut être relative à l'API.
    final url = ref.read(configProvider).apiBaseUrl.resolve(widget.content.audioUrl!);
    setState(() => _playing = true);
    try {
      await player.play(url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l.errorOther)));
      }
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  void dispose() {
    if (_playing) _player.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.content;
    final accent = widget.module == null ? FaniloColors.forest : moduleStrong(widget.module!);
    return Container(
      key: Key('content-${c.code}'),
      decoration: BoxDecoration(
        color: FaniloColors.surface,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: kSoftShadow,
        border: Border(left: BorderSide(color: accent, width: 6)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!c.isValidated && widget.showDemo) ...[const DemoBanner(), const SizedBox(height: 10)],
        Text(c.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(c.body, style: const TextStyle(fontSize: 18, height: 1.4)),
        if (c.audioUrl != null && c.audioUrl!.isNotEmpty) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('play-audio'),
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.stop : Icons.volume_up, size: 28),
            label: Text(_playing ? context.l.stopAudio : context.l.listen),
          ),
        ],
      ]),
    );
  }
}

/// Écran plein d'un contenu (depuis les menus).
class ContentScreen extends StatelessWidget {
  const ContentScreen(
      {super.key, required this.content, required this.module, required this.number});
  final Content content;
  final Module module;
  final int number;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('${moduleTitle(module)} · $number'),
          actions: const [EmergencyAction()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ContentCard(content: content, module: module),
              const SizedBox(height: 16),
              IconLine(
                  icon: Icons.local_hospital,
                  text: context.l.welcomeEmergency,
                  color: FaniloColors.alert),
              const ScreenFooter(),
            ],
          ),
        ),
      );
}
