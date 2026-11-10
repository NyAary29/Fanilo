import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/models.dart';
import '../data/local/local_store.dart';
import 'providers.dart';
import 'screens/answer_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Demande RENY ou TANORA si aucun module n'est choisi.
Future<Module?> ensureModule(BuildContext context, WidgetRef ref) async {
  final current = ref.read(selectedModuleProvider);
  if (current != null) return current;
  final picked = await showModalBottomSheet<Module>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ctx.l.chooseModule,
              textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 16),
          for (final m in Module.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: Key('pick-${m.name}'),
                  style: FilledButton.styleFrom(
                      backgroundColor: moduleColor(m),
                      foregroundColor: moduleInk(m),
                      minimumSize: const Size(64, 72)),
                  onPressed: () => Navigator.of(ctx).pop(m),
                  child: Text('${moduleTitle(m)} · ${moduleSubtitle(ctx, m)}',
                      textAlign: TextAlign.center),
                ),
              ),
            ),
        ]),
      ),
    ),
  );
  if (picked != null) ref.read(selectedModuleProvider.notifier).state = picked;
  return picked;
}

/// Ce que l'utilisatrice demande en quittant l'écran de réponse d'une
/// question vocale.
class AnswerExit {
  const AnswerExit.retryVoice()
      : retryVoice = true,
        prefill = null;
  const AnswerExit.write(String this.prefill) : retryVoice = false;
  final bool retryVoice;

  /// Texte à mettre dans le champ (transcription à corriger, ou vide).
  final String? prefill;
}

/// Résultat de [submitQuestion].
class SubmitResult {
  const SubmitResult({required this.sent, this.exit});
  final bool sent;
  final AnswerExit? exit;
}

/// Envoie la question (texte OU audio), garde le ticket si un conseiller la
/// suit, puis ouvre l'écran de réponse.
Future<SubmitResult> submitQuestion(
  BuildContext context,
  WidgetRef ref, {
  required Module module,
  String? text,
  VoiceClip? clip,
}) async {
  final api = ref.read(apiProvider);
  final language = ref.read(languageProvider);
  final siteId = ref.read(siteProvider)?.id;
  try {
    final AskResult result;
    if (clip != null) {
      result = await api.askVoice(
        module: module,
        clip: clip,
        language: language,
        siteId: siteId,
        voiceConsent: ref.read(voiceConsentProvider) != null,
      );
    } else {
      result = await api.askText(
          module: module, text: text!, language: language, siteId: siteId);
    }
    final follow = result.followUp;
    if (follow != null) {
      // Seuls l'identifiant, le jeton, le module et la date sont gardés.
      await ref.read(ticketsProvider.notifier).add(Ticket(
            questionId: result.questionId,
            token: follow.token,
            module: module,
            createdAt: DateTime.now(),
          ));
    }
    if (!context.mounted) return const SubmitResult(sent: true);
    final exit = await Navigator.of(context).push(MaterialPageRoute<AnswerExit>(
        builder: (_) => AnswerScreen(result: result, module: module, fromVoice: clip != null)));
    return SubmitResult(sent: true, exit: exit);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: FaniloColors.alertInk,
        content: Text(apiErrorMessage(context, e)),
      ));
    }
    return const SubmitResult(sent: false);
  }
}
