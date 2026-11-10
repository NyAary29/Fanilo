import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_store.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/consent.dart';
import '../widgets/logo.dart';

/// Premier lancement : information (sans compte, rien d'identifiant gardé,
/// audio jamais conservé, urgence), accord facultatif pour la voix, puis
/// « Où habitez-vous ? » (facultatif).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  int _step = 0;

  void _next() => setState(() => _step++);

  Future<void> _finish() => ref.read(onboardedProvider.notifier).done();

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final Widget body = switch (_step) {
      0 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
              child: FittedBox(
                  fit: BoxFit.scaleDown, child: FaniloLogo(size: 56, tagline: l.tagline))),
          const SizedBox(height: 16),
          Center(child: Text(l.welcomeTitle, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: FaniloColors.forest))),
          const SizedBox(height: 12),
          const Center(child: LanguageToggle()),
          const SizedBox(height: 16),
          IconLine(icon: Icons.no_accounts, text: l.welcomeNoAccount),
          IconLine(icon: Icons.visibility_off, text: l.welcomeNothingKept),
          IconLine(icon: Icons.mic_off, text: l.welcomeAudio),
          IconLine(icon: Icons.local_hospital, text: l.welcomeEmergency, color: FaniloColors.alert),
          IconLine(icon: Icons.medical_information, text: l.disclaimer),
          const SizedBox(height: 8),
          const ServerInformation(scopes: ['reny', 'tanora']),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('welcome-continue'),
            onPressed: _next,
            icon: const Icon(Icons.arrow_forward, size: 28),
            label: Text(l.continueLabel),
          ),
        ]),
      1 => VoiceConsentPanel(onDone: (_) => _next()),
      _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.place, size: 40, color: FaniloColors.forest),
            const SizedBox(width: 12),
            Expanded(child: Text(l.whereLive, style: Theme.of(context).textTheme.headlineSmall)),
          ]),
          const SizedBox(height: 8),
          Text(l.whereLiveHelp, style: const TextStyle(fontSize: 16, color: FaniloColors.inkSoft)),
          const SizedBox(height: 12),
          SitePicker(onPicked: (s) async {
            await ref.read(siteProvider.notifier).set(SavedSite(s.id, s.name));
            await _finish();
          }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('site-skip'),
            onPressed: _finish,
            icon: const Icon(Icons.skip_next, size: 28),
            label: Text(l.skip),
          ),
        ]),
    };
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _step > 0
            ? IconButton(
                iconSize: 30,
                onPressed: () => setState(() => _step--),
                icon: const Icon(Icons.arrow_back))
            : null,
        title: _StepDots(step: _step),
        actions: const [EmergencyAction()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [body, if (_step > 0) const ScreenFooter()],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(right: 6),
            width: i == step ? 28 : 12,
            height: 12,
            decoration: BoxDecoration(
              color: i <= step ? FaniloColors.forest : FaniloColors.line,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
      ]);
}
