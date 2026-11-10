import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../data/api/dto.dart';
import '../labels.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Signalement de signes cochés par l'AC (saisie déterministe).
///
/// - En ligne : `POST /interactions/ask` en JSON avec `sign_codes`. La
///   décision vient du moteur de règles côté serveur ; l'écran n'affiche
///   que l'orientation et le contenu validé renvoyés, **jamais un diagnostic**.
/// - Hors ligne : aucun envoi différé ; message demandant de contacter
///   directement le CSB selon la procédure locale.
///
/// Sert d'onglet « Alerter » ([embedded]) et d'écran ouvert depuis une fiche
/// ou une visite (bénéficiaire présélectionnée).
class SignsScreen extends ConsumerStatefulWidget {
  const SignsScreen({super.key, this.beneficiaryId, this.embedded = false, this.onSent});
  final String? beneficiaryId;

  /// Onglet de l'écran principal (pas de retour, mention affichée par l'écran
  /// principal).
  final bool embedded;

  /// Appelé quand le serveur a répondu au signalement.
  final VoidCallback? onSent;

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
    // Référentiel à jour si le réseau est là ; sinon, copie locale.
    Future.microtask(() async {
      if (!mounted) return;
      if (await ref.read(networkSourceProvider).isOnline()) {
        await ref.read(referenceRepositoryProvider).refresh();
      }
    });
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
      widget.onSent?.call();
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
    final catalogState = ref.watch(signCatalogProvider);
    final catalog = catalogState.valueOrNull;
    final online = ref.watch(onlineProvider).valueOrNull ?? false;
    final beneficiaries = ref.watch(beneficiariesProvider).valueOrNull ?? const [];
    final identities = ref.watch(identitiesProvider).valueOrNull ?? const {};
    final response = _response;
    final signs = catalog?.forModule(AppConfig.askModule) ?? const [];

    final content = ListView(
      key: const Key('signs-list'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(l.signsLead,
            style: const TextStyle(fontSize: 16, color: FaniloColors.inkSoft)),
        const SizedBox(height: 6),
        if (catalog != null && catalog.showDemoBanner) DemoBanner(text: l.demoBanner),
        if (!online)
          NoticeCard(
            key: const Key('signs-offline'),
            tone: NoticeTone.alert,
            icon: Icons.phone_in_talk,
            title: l.offline,
            text: l.signsOffline,
          )
        else if (response == null)
          NoticeCard(tone: NoticeTone.ok, icon: Icons.wifi, text: l.signsOnline),
        if (response != null)
          _ResultCard(
            response: response,
            onReset: () => setState(() {
              _response = null;
              _selected.clear();
            }),
          )
        else if (signs.isEmpty)
          if (catalogState.isLoading)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
          else
            NoticeCard(
              tone: NoticeTone.warning,
              textKey: const Key('signs-catalog-missing'),
              text: l.signsCatalogMissing,
            )
        else ...[
          SectionHeader(l.signsWho, icon: Icons.person_outline),
          DropdownButtonFormField<String?>(
            key: const Key('signs-beneficiary'),
            initialValue: _beneficiaryId,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: l.signsBeneficiary,
                prefixIcon: const Icon(Icons.pregnant_woman)),
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
          SectionHeader(l.signsIntro, icon: Icons.checklist_rounded),
          for (final s in signs)
            _SignTile(
              key: Key('sign-${s.code}'),
              label: s.label,
              selected: _selected.contains(s.code),
              onTap: () => setState(() {
                _selected.contains(s.code) ? _selected.remove(s.code) : _selected.add(s.code);
                _message = null;
              }),
            ),
          if (_message != null)
            NoticeCard(
              tone: NoticeTone.alert,
              textKey: const Key('signs-message'),
              text: _message!,
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('signs-send'),
            style: FilledButton.styleFrom(
                backgroundColor: FaniloColors.alert, minimumSize: const Size(64, 60)),
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text(l.signsSend),
          ),
        ],
      ],
    );

    final title = Row(children: [
      const Icon(Icons.campaign_rounded, color: FaniloColors.alert),
      const SizedBox(width: 10),
      Flexible(child: Text(l.signsTitle)),
    ]);
    if (widget.embedded) {
      return Scaffold(
        appBar: AppBar(title: title, automaticallyImplyLeading: false),
        body: content,
      );
    }
    return FaniloScaffold(title: l.signsTitle, body: content);
  }
}

/// Grande case à cocher pour un signe (toute la carte est cliquable).
class _SignTile extends StatelessWidget {
  const _SignTile({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kRadius);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: selected ? FaniloColors.alertSoft : Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                  color: selected ? FaniloColors.alert : FaniloColors.line,
                  width: selected ? 2 : 1),
            ),
            child: Row(children: [
              Icon(selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 34, color: selected ? FaniloColors.alert : FaniloColors.forest),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
              ),
            ]),
          ),
        ),
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
    return Column(
      key: const Key('signs-result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (response.isDemo || content?.status == 'demo') DemoBanner(text: l.demoContent),
        SectionHeader(l.signsResultTitle, icon: Icons.directions),
        for (final a in response.actions)
          SoftCard(
            color: FaniloColors.forest,
            child: Row(children: [
              const Icon(Icons.directions, size: 32, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l.action(a),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ]),
          ),
        if (response.outcome == 'fallback')
          NoticeCard(icon: Icons.support_agent, text: l.fallbackOutcome),
        if (response.alertId != null)
          NoticeCard(
              tone: NoticeTone.warning,
              icon: Icons.notifications_active,
              text: l.alertCreated),
        if (content != null && (content.title.isNotEmpty || content.body.isNotEmpty))
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content.title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(content.body, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(response.disclaimer,
            style: const TextStyle(fontStyle: FontStyle.italic, color: FaniloColors.inkSoft)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
            onPressed: onReset, icon: const Icon(Icons.refresh), label: Text(l.newReport)),
      ],
    );
  }
}
