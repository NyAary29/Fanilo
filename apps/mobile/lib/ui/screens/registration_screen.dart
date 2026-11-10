import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums.dart';
import '../../domain/registration.dart';
import '../../domain/reference_data.dart';
import '../../l10n/gen/app_localizations.dart';
import '../labels.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'beneficiary_detail_screen.dart';

/// Enregistrement en deux étapes : **consentement d'abord** (obligatoire),
/// puis identité (affichée à part) et données de suivi sans nom.
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  int _step = 0;
  final Set<ConsentScope> _scopes = {ConsentScope.reny};
  ConsentMethod? _method;
  bool _presented = false;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _village = TextEditingController();
  final _birthYear = TextEditingController();
  PreferredChannel _channel = PreferredChannel.acVisit;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Information de consentement à jour si le réseau est là ; sinon, copie
    // locale (dernière reçue).
    Future.microtask(() async {
      if (!mounted) return;
      if (await ref.read(networkSourceProvider).isOnline()) {
        await ref.read(referenceRepositoryProvider).refresh();
      }
    });
  }

  ConsentInformationSet? get _info =>
      ref.read(consentInformationProvider).valueOrNull;

  /// Les versions viennent du référentiel servi par l'API, portée par portée.
  ConsentInput get _consent {
    final info = _info;
    return ConsentInput(
      scopes: _scopes,
      method: _method,
      informationVersions: {
        for (final s in _scopes)
          if (info?.forScope(s) != null) s: info!.forScope(s)!.version,
      },
      informationPresented: _presented,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _village.dispose();
    _birthYear.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final by = _birthYear.text.trim();
    final draft = RegistrationDraft(
      consent: _consent,
      identity: IdentityInput(
          displayName: _name.text, phone: _phone.text, village: _village.text),
      beneficiary: BeneficiaryInput(
          birthYear: by.isEmpty ? null : int.tryParse(by) ?? -1,
          preferredChannel: _channel),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(localRepositoryProvider)
          .registerBeneficiary(draft, user);
      if (!mounted) return;
      showSnack(context, l.registered);
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => BeneficiaryDetailScreen(beneficiaryId: id)));
      // Envoi immédiat si le réseau est là ; sinon, l'outbox attend.
      ref.read(syncServiceProvider).sync();
    } on ConsentRequiredException {
      setState(() {
        _error = l.consentIncomplete;
        _step = 0;
      });
    } on InvalidRegistrationException catch (e) {
      setState(() => _error = e.error == RegistrationError.nameRequired
          ? l.nameRequired
          : l.invalidBirthYear);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FaniloScaffold(
      title: l.registerTitle,
      body: Column(
        children: [
          _StepHeader(step: _step),
          Expanded(child: _step == 0 ? _consentStep(l) : _identityStep(l)),
        ],
      ),
    );
  }

  Widget _consentStep(AppLocalizations l) {
    final infoState = ref.watch(consentInformationProvider);
    final info = infoState.valueOrNull;
    final consent = _consent;
    if (info == null || info.items.isEmpty) {
      return ListView(
        key: const Key('consent-step'),
        padding: const EdgeInsets.all(16),
        children: [
          if (infoState.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Text(l.consentInfoMissing,
                key: const Key('consent-info-missing'),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error)),
        ],
      );
    }
    return ListView(
      key: const Key('consent-step'),
      padding: const EdgeInsets.all(16),
      children: [
        if (info.anyDemo) DemoBanner(text: l.consentInfoDemo),
        const SizedBox(height: 8),
        NoticeCard(icon: Icons.record_voice_over_outlined, text: l.consentIntro),
        const SizedBox(height: 16),
        SectionHeader(l.consentScopes, icon: Icons.checklist_rounded),
        for (final s in ConsentScope.values)
          _scopeTile(l, s, info.forScope(s)),
        const SizedBox(height: 8),
        SectionHeader(l.consentMethod, icon: Icons.how_to_reg_outlined),
        const SizedBox(height: 8),
        SegmentedButton<ConsentMethod>(
          key: const Key('consent-method'),
          emptySelectionAllowed: true,
          segments: [
            ButtonSegment(
                value: ConsentMethod.oral,
                label: Text(l.methodOral),
                icon: const Icon(Icons.record_voice_over)),
            ButtonSegment(
                value: ConsentMethod.written,
                label: Text(l.methodWritten),
                icon: const Icon(Icons.draw)),
          ],
          selected: {if (_method != null) _method!},
          onSelectionChanged: (s) =>
              setState(() => _method = s.isEmpty ? null : s.first),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const Key('info-presented'),
          tileColor: FaniloColors.mint,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
          value: _presented,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l.infoPresented, style: const TextStyle(fontSize: 16)),
          onChanged: (v) => setState(() => _presented = v ?? false),
        ),
        if (!consent.isComplete)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l.consentIncomplete,
                key: const Key('consent-required'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('consent-next'),
          onPressed: consent.isComplete ? () => setState(() => _step = 1) : null,
          icon: const Icon(Icons.arrow_forward),
          label: Text(l.next),
        ),
      ],
    );
  }

  /// Portée : cochable seulement si le serveur sert une information pour
  /// elle. Le résumé et sa version sont affichés pour être présentés.
  Widget _scopeTile(AppLocalizations l, ConsentScope s, ConsentInformation? info) {
    final available = info != null;
    return Card(
        child: CheckboxListTile(
      controlAffinity: ListTileControlAffinity.leading,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      key: Key('scope-${s.wire}'),
      value: available && _scopes.contains(s),
      title: Text(l.consentScope(s.wire),
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
      subtitle: Text(
        available
            ? '${info.summaryFr}\n${l.infoVersionOf(info.version)}'
            : l.consentScopeUnavailable,
        key: Key('scope-info-${s.wire}'),
      ),
      isThreeLine: available,
      onChanged: available
          ? (v) => setState(() => v == true ? _scopes.add(s) : _scopes.remove(s))
          : null,
    ));
  }

  Widget _identityStep(AppLocalizations l) {
    return ListView(
      key: const Key('identity-step'),
      padding: const EdgeInsets.all(16),
      children: [
        SoftCard(
          color: FaniloColors.mint,
          child: Padding(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock),
                title: Text(l.identityConfidential,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextField(
                  key: const Key('name-field'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l.displayName)),
              const SizedBox(height: 8),
              TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: l.phone)),
              const SizedBox(height: 8),
              TextField(
                  controller: _village,
                  decoration: InputDecoration(labelText: l.village)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        SectionHeader(l.followUp, icon: Icons.monitor_heart_outlined),
        const SizedBox(height: 8),
        TextField(
            controller: _birthYear,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.birthYear)),
        const SizedBox(height: 8),
        DropdownButtonFormField<PreferredChannel>(
          initialValue: _channel,
          decoration: InputDecoration(labelText: l.preferredChannel),
          items: [
            for (final c in PreferredChannel.values)
              DropdownMenuItem(value: c, child: Text(l.channel(c))),
          ],
          onChanged: (v) => setState(() => _channel = v ?? PreferredChannel.none),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
                onPressed: _saving ? null : () => setState(() => _step = 0),
                icon: const Icon(Icons.arrow_back),
                label: Text(l.back)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
                key: const Key('save-registration'),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_alt_rounded),
                label: Text(l.save)),
          ),
        ]),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget pill(int index, IconData icon, String text) {
      final active = step == index;
      final done = step > index;
      return Expanded(
        child: Container(
          height: kTouch,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active
                ? FaniloColors.forest
                : done
                    ? FaniloColors.mintStrong
                    : FaniloColors.surface,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: active ? FaniloColors.forest : FaniloColors.line),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(done ? Icons.check_circle : icon,
                color: active ? Colors.white : FaniloColors.forest),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: active ? Colors.white : FaniloColors.forestDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5)),
            ),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(children: [
        pill(0, Icons.handshake_outlined, l.stepConsent),
        const SizedBox(width: 10),
        pill(1, Icons.badge_outlined, l.stepIdentity),
      ]),
    );
  }
}
