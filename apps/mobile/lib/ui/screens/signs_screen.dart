import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../data/api/dto.dart';
import '../../domain/sign_catalog.dart';
import '../labels.dart';
import '../providers.dart';
import '../widgets/common.dart';

final signCatalogProvider = Provider<SignCatalog>((_) => SignCatalog.demo);

/// Signalement de signes cochés par l'AC (saisie déterministe).
///
/// - En ligne : `POST /interactions/ask` en JSON avec `sign_codes`. La
///   décision vient du moteur de règles côté serveur ; l'écran n'affiche
///   que l'orientation et le contenu validé renvoyés, **jamais un diagnostic**.
/// - Hors ligne : aucun envoi différé ; message demandant de contacter
///   directement le CSB selon la procédure locale.
class SignsScreen extends ConsumerStatefulWidget {
  const SignsScreen({super.key, this.beneficiaryId});
  final String? beneficiaryId;

  @override
  ConsumerState<SignsScreen> createState() => _SignsScreenState();
}

class _SignsScreenState extends ConsumerState<SignsScreen> {
  final Set<String> _selected = {};
  String? _beneficiaryId;
  bool _sending = false;
  String? _message;
  AskResponse? _response;

  @override
  void initState() {
    super.initState();
    _beneficiaryId = widget.beneficiaryId;
  }

  Future<void> _send() async {
    final l = context.l10n;
    if (_selected.isEmpty) {
      setState(() => _message = l.signsSelectOne);
      return;
    }
    final online = ref.read(onlineProvider).valueOrNull ?? false;
    if (!online) {
      setState(() => _message = l.signsOffline);
      return;
    }
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      final r = await ref.read(interactionApiProvider).askWithSigns(
            module: AppConfig.askModule,
            beneficiaryId: _beneficiaryId,
            signCodes: _selected.toList()..sort(),
          );
      setState(() => _response = r);
      // Une alerte a pu être créée : on la récupère.
      ref.read(syncServiceProvider).sync();
    } on Object {
      setState(() => _message = l.signsError);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = ref.watch(signCatalogProvider);
    final online = ref.watch(onlineProvider).valueOrNull ?? false;
    final beneficiaries = ref.watch(beneficiariesProvider).valueOrNull ?? const [];
    final identities = ref.watch(identitiesProvider).valueOrNull ?? const {};
    final response = _response;

    return FaniloScaffold(
      title: l.signsTitle,
      body: ListView(
        children: [
          if (!catalog.isValidated) DemoBanner(text: l.demoBanner),
          if (!online)
            Container(
              key: const Key('signs-offline'),
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.phone_in_talk, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l.signsOffline,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          if (response != null)
            _ResultCard(
              response: response,
              onReset: () => setState(() {
                _response = null;
                _selected.clear();
              }),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String?>(
                value: _beneficiaryId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.signsBeneficiary),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(l.noneSelected)),
                  for (final b in beneficiaries)
                    DropdownMenuItem<String?>(
                      value: b.id,
                      child: Text(identities[b.id]?.displayName ?? b.code ?? l.codePending,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _beneficiaryId = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l.signsIntro, style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final s in catalog.forModule(AppConfig.askModule))
              CheckboxListTile(
                key: Key('sign-${s.code}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                value: _selected.contains(s.code),
                title: Text(s.label, style: const TextStyle(fontSize: 18)),
                onChanged: (v) => setState(() {
                  v == true ? _selected.add(s.code) : _selected.remove(s.code);
                  _message = null;
                }),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_message!,
                    key: const Key('signs-message'),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error)),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                key: const Key('signs-send'),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(l.signsSend),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.response, required this.onReset});
  final AskResponse response;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final content = response.content;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        key: const Key('signs-result'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (response.isDemo || content?.status == 'demo')
            DemoBanner(text: l.demoContent),
          const SizedBox(height: 8),
          Text(l.signsResultTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          for (final a in response.actions)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.directions, size: 32),
                title: Text(l.action(a),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          if (response.outcome == 'fallback')
            Card(child: ListTile(
                leading: const Icon(Icons.support_agent),
                title: Text(l.fallbackOutcome))),
          if (response.alertId != null)
            Card(child: ListTile(
                leading: const Icon(Icons.notifications_active),
                title: Text(l.alertCreated))),
          if (content != null && (content.title.isNotEmpty || content.body.isNotEmpty))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(content.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(content.body, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(response.disclaimer, style: const TextStyle(fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onReset, child: Text(l.newReport)),
        ],
      ),
    );
  }
}
