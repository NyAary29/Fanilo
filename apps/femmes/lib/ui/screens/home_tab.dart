import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../data/api/models.dart';
import '../ask_flow.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/consent.dart';

enum _Mic { idle, recording, sending }

/// Accueil (maquette) : « Salama ! », gros bouton micro, cartes RENY et
/// TANORA, champ texte de secours.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _text = TextEditingController();
  final _textFocus = FocusNode();
  _Mic _mic = _Mic.idle;
  bool _sendingText = false;
  Timer? _timer;
  int _seconds = 0;
  late final _recorder = ref.read(recorderProvider);

  @override
  void initState() {
    super.initState();
    _recorder; // lu tant que l'élément est actif (utilisé dans dispose).
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_mic == _Mic.recording) _recorder.cancel();
    _text.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _onMic() async {
    if (_mic == _Mic.sending) return;
    if (_mic == _Mic.recording) return _stopAndSend();

    // 1. Accord pour la voix (sinon : le texte reste utilisable).
    if (ref.read(voiceConsentProvider) == null) {
      final ok = await showVoiceConsentSheet(context);
      if (!ok || !mounted) return;
    }
    // 2. Module.
    final module = await ensureModule(context, ref);
    if (module == null || !mounted) return;
    // 3. Autorisation du micro, avec explication.
    final recorder = _recorder;
    _snack(context.l.micPermission);
    bool allowed;
    try {
      allowed = await recorder.requestPermission();
    } catch (_) {
      allowed = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (!allowed) return _snack(context.l.micDenied);
    try {
      await recorder.start();
    } catch (_) {
      if (mounted) _snack(context.l.micDenied);
      return;
    }
    if (!mounted) return;
    setState(() {
      _mic = _Mic.recording;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      if (_seconds >= AppConfig.maxRecording.inSeconds) _stopAndSend();
    });
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    setState(() => _mic = _Mic.sending);
    final module = ref.read(selectedModuleProvider);
    AnswerExit? exit;
    try {
      final clip = await _recorder.stop();
      if (clip == null || module == null || !mounted) return;
      exit = (await submitQuestion(context, ref, module: module, clip: clip)).exit;
    } catch (_) {
      if (mounted) _snack(context.l.errorOther);
    } finally {
      if (mounted) setState(() => _mic = _Mic.idle);
    }
    if (!mounted || exit == null) return;
    if (exit.retryVoice) {
      await _onMic();
    } else {
      // Texte à corriger (transcription) ou à écrire : envoyé ensuite comme
      // question écrite.
      _text.text = exit.prefill ?? '';
      _text.selection = TextSelection.collapsed(offset: _text.text.length);
      _textFocus.requestFocus();
    }
  }

  Future<void> _sendText() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sendingText) return;
    FocusScope.of(context).unfocus();
    final module = await ensureModule(context, ref);
    if (module == null || !mounted) return;
    setState(() => _sendingText = true);
    final res = await submitQuestion(context, ref, module: module, text: text);
    if (!mounted) return;
    setState(() => _sendingText = false);
    // Le texte n'est gardé nulle part : on vide le champ après l'envoi.
    if (res.sent) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final selected = ref.watch(selectedModuleProvider);
    final hasConsent = ref.watch(voiceConsentProvider) != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        Text(l.hello,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900, fontSize: 28)),
        Text(l.homeSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, color: FaniloColors.inkSoft)),
        const SizedBox(height: 14),
        Center(
          child: _MicButton(
            state: _mic,
            seconds: _seconds,
            hasConsent: hasConsent,
            onTap: _onMic,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          switch (_mic) {
            _Mic.idle => l.micHint,
            _Mic.recording => '${l.micListening}  ${_seconds}s · ${l.micStop}',
            _Mic.sending => l.voiceWait,
          },
          key: const Key('mic-label'),
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: _mic == _Mic.sending ? 20 : 18,
              fontWeight: FontWeight.w800,
              color: _mic == _Mic.sending ? FaniloColors.forest : null),
        ),
        // Transcription : 10 à 20 s possibles, on montre que ça avance.
        if (_mic == _Mic.sending)
          const Padding(
            key: Key('voice-wait'),
            padding: EdgeInsets.fromLTRB(40, 10, 40, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              child: LinearProgressIndicator(minHeight: 10),
            ),
          ),
        const SizedBox(height: 18),
        Row(children: [
          for (final m in Module.values) ...[
            if (m != Module.values.first) const SizedBox(width: 12),
            Expanded(
              child: _ModuleCard(
                module: m,
                selected: selected == m,
                onTap: () => ref.read(selectedModuleProvider.notifier).state = m,
              ),
            ),
          ],
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('ask-text'),
              controller: _text,
              focusNode: _textFocus,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(
                counterText: '',
                prefixIcon: const Icon(Icons.edit, color: FaniloColors.forest),
                hintText: l.writeHint,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox.square(
            dimension: 60,
            child: IconButton.filled(
              key: const Key('ask-send'),
              tooltip: l.send,
              iconSize: 30,
              onPressed: _sendingText ? null : _sendText,
              icon: _sendingText
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : const Icon(Icons.send),
            ),
          ),
        ]),
        const ScreenFooter(),
      ],
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton(
      {required this.state, required this.seconds, required this.hasConsent, required this.onTap});
  final _Mic state;
  final int seconds;
  final bool hasConsent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recording = state == _Mic.recording;
    final color = recording ? FaniloColors.alert : FaniloColors.leaf;
    return Semantics(
      button: true,
      label: context.l.micHint,
      child: SizedBox(
        width: 260,
        height: 132,
        child: Stack(alignment: Alignment.center, children: [
          // Ondes sonores de part et d'autre (maquette).
          const Positioned.fill(child: CustomPaint(painter: _WavesPainter())),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              key: const Key('mic-button'),
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: recording
                        ? [FaniloColors.alert, FaniloColors.alertInk]
                        : [FaniloColors.leafLight, FaniloColors.forest],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: recording ? 6 : 2),
                  ],
                  border: Border.all(color: Colors.white, width: 5),
                ),
                child: state == _Mic.sending
                    ? const Padding(
                        padding: EdgeInsets.all(38),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 5))
                    : Icon(recording ? Icons.stop_rounded : Icons.mic,
                        color: Colors.white, size: 64),
              ),
            ),
          ),
          if (!hasConsent && state == _Mic.idle)
            Positioned(
              right: 62,
              bottom: 6,
              child: Container(
                key: const Key('mic-locked'),
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.lock, size: 22, color: FaniloColors.inkSoft),
              ),
            ),
        ]),
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  const _WavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    for (var i = 0; i < 3; i++) {
      final r = 74.0 + i * 16;
      paint.color = FaniloColors.leaf.withValues(alpha: 0.55 - i * 0.15);
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawArc(rect, -math.pi / 5, 2 * math.pi / 5, false, paint);
      canvas.drawArc(rect, math.pi - math.pi / 5, 2 * math.pi / 5, false, paint);
    }
  }

  @override
  bool shouldRepaint(_WavesPainter oldDelegate) => false;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.selected, required this.onTap});
  final Module module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strong = moduleStrong(module);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: moduleColor(module),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: Key('module-${module.name}'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 172),
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? strong : Colors.transparent, width: 3),
            ),
            child: Column(children: [
              _ModuleFigure(module: module),
              const SizedBox(height: 6),
              Text(moduleTitle(module),
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: moduleInk(module))),
              Text(moduleSubtitle(context, module),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, height: 1.2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: strong, shape: BoxShape.circle),
                  child: Icon(selected ? Icons.check : Icons.arrow_forward,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Pictogramme du module (vectoriel, sans image) : femme enceinte ou
/// adolescente avec sac.
class _ModuleFigure extends StatelessWidget {
  const _ModuleFigure({required this.module});
  final Module module;

  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(
          module == Module.reny ? Icons.pregnant_woman : Icons.face_3,
          size: 44,
          color: moduleStrong(module),
        ),
      );
}
