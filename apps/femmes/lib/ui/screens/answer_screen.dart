import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/models.dart';
import '../ask_flow.dart';
import '../providers.dart';
import '../ticket_status.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'content_screen.dart';

/// Réponse à une question : bloc d'urgence si `urgent`, contenu publié,
/// suivi par un conseiller si `follow_up`, et toujours l'avertissement.
class AnswerScreen extends ConsumerWidget {
  const AnswerScreen(
      {super.key, required this.result, required this.module, this.fromVoice = false});
  final AskResult result;
  final Module module;

  /// Question posée à la voix : on montre ce qui a été compris.
  final bool fromVoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final content = result.content;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.answerTitle),
        actions: const [EmergencyAction()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (result.showDemoBanner) ...[const DemoBanner(), const SizedBox(height: 12)],
            // Signe de danger reconnu OU suspecté : toujours en premier, quel
            // que soit `outcome`.
            if (result.urgent) ...[const UrgentBlock(), const SizedBox(height: 16)],
            if (fromVoice && (result.transcript?.trim().isNotEmpty ?? false))
              _VoiceCheck(result: result)
            else if (result.transcript != null && result.transcript!.trim().isNotEmpty)
              _Transcript(
                  text: result.transcript!,
                  needsReview: result.transcriptNeedsReview,
                  fromVoice: fromVoice)
            else if (fromVoice)
              _NotTranscribed(sentToCounselor: result.followUp != null),
            if (content != null)
              ContentCard(content: content, module: module, showDemo: !result.showDemoBanner)
            else if (result.followUp == null)
              IconLine(icon: Icons.help_outline, text: l.noContent),
            if (result.followUp != null) ...[
              const SizedBox(height: 12),
              _FollowUpCard(onOpen: () {
                ref.read(tabProvider.notifier).state = 2;
                Navigator.of(context).popUntil((r) => r.isFirst);
              }),
            ],
            if (!result.urgent) ...[
              const SizedBox(height: 12),
              IconLine(
                  icon: Icons.local_hospital, text: l.welcomeEmergency, color: FaniloColors.alert),
            ],
            const SizedBox(height: 8),
            Disclaimer(text: result.disclaimer),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('ask-another'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.mic, size: 26),
              label: Text(l.askAnother),
            ),
          ],
        ),
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.text, required this.needsReview, required this.fromVoice});
  final String text;
  final bool needsReview;
  final bool fromVoice;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          key: const Key('transcript'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FaniloColors.mint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.record_voice_over, size: 20, color: FaniloColors.forest),
              const SizedBox(width: 6),
              Expanded(
                child: Text(fromVoice ? context.l.weUnderstood : context.l.yourQuestion,
                    style:
                        const TextStyle(fontWeight: FontWeight.w800, color: FaniloColors.forest)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('« $text »', style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
            if (needsReview)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(context.l.transcriptReview,
                    style: const TextStyle(color: FaniloColors.inkSoft, fontSize: 14)),
              ),
          ]),
        ),
      );
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Container(
      key: const Key('follow-up'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FaniloColors.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: FaniloColors.leaf, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        IconLine(icon: Icons.support_agent, text: l.sentToCounselor),
        IconLine(icon: Icons.forum, text: l.findReplyIn),
        IconLine(icon: Icons.schedule, text: l.noDelay, color: FaniloColors.follow),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('open-mine'),
          onPressed: onOpen,
          icon: const Icon(Icons.forum, size: 26),
          label: Text(l.seeMyQuestions),
        ),
      ]),
    );
  }
}

/// Question vocale transcrite : « Est-ce bien ce que vous avez dit ? ».
/// « Non, je l'écris » retire la question envoyée (pour que le conseiller
/// n'en reçoive pas une version fausse) et rouvre le champ texte prérempli.
class _VoiceCheck extends ConsumerStatefulWidget {
  const _VoiceCheck({required this.result});
  final AskResult result;

  @override
  ConsumerState<_VoiceCheck> createState() => _VoiceCheckState();
}

class _VoiceCheckState extends ConsumerState<_VoiceCheck> {
  bool _confirmed = false;
  bool _busy = false;

  Future<void> _rewrite() async {
    final r = widget.result;
    setState(() => _busy = true);
    final follow = r.followUp;
    if (follow != null) {
      try {
        await ref.read(apiProvider).deleteQuestion(r.questionId, follow.token);
      } catch (_) {
        // Hors ligne : le ticket reste, l'utilisatrice pourra l'effacer
        // depuis « Ny fanontaniako ».
        if (mounted) setState(() => _busy = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: FaniloColors.alertInk, content: Text(context.l.errorNetwork)));
        }
        return;
      }
      await ref.read(ticketsProvider.notifier).remove(r.questionId);
      ref.read(ticketStatusProvider.notifier).forget(r.questionId);
    }
    if (mounted) Navigator.of(context).pop(AnswerExit.write(r.transcript!.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final r = widget.result;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        key: const Key('voice-check'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FaniloColors.mint,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: FaniloColors.leaf, width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.record_voice_over, color: FaniloColors.forest, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.isThisWhatYouSaid,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 18, color: FaniloColors.forest)),
            ),
          ]),
          const SizedBox(height: 8),
          Text('« ${r.transcript!.trim()} »',
              key: const Key('transcript'),
              style: const TextStyle(fontSize: 19, fontStyle: FontStyle.italic, height: 1.35)),
          if (r.transcriptNeedsReview)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.transcriptReview,
                  style: const TextStyle(color: FaniloColors.inkSoft, fontSize: 14)),
            ),
          if (!_confirmed) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('transcript-yes'),
                  onPressed: _busy ? null : () => setState(() => _confirmed = true),
                  icon: const Icon(Icons.check_circle, size: 28),
                  label: Text(l.yes),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  key: const Key('transcript-no'),
                  onPressed: _busy ? null : _rewrite,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 22, child: CircularProgressIndicator(strokeWidth: 3))
                      : const Icon(Icons.edit, size: 26),
                  label: Text(l.noWrite, textAlign: TextAlign.center),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Question vocale sans transcription (voix non comprise ou silence).
class _NotTranscribed extends StatelessWidget {
  const _NotTranscribed({required this.sentToCounselor});
  final bool sentToCounselor;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        key: const Key('not-transcribed'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FaniloColors.followSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FaniloColors.follow),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          IconLine(icon: Icons.hearing_disabled, text: l.voiceNotUnderstood, color: FaniloColors.followInk),
          // Le serveur ne garde pas l'audio : on ne promet pas d'écoute,
          // seulement la transmission de la question à un conseiller.
          if (sentToCounselor)
            IconLine(
                icon: Icons.support_agent,
                text: l.voiceNotTranscribedFollow,
                color: FaniloColors.followInk),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('voice-retry'),
                onPressed: () => Navigator.of(context).pop(const AnswerExit.retryVoice()),
                icon: const Icon(Icons.mic, size: 28),
                label: Text(l.retryVoice),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('voice-write'),
                onPressed: () => Navigator.of(context).pop(const AnswerExit.write('')),
                icon: const Icon(Icons.edit, size: 26),
                label: Text(l.writeQuestion),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
