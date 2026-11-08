import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums.dart';
import '../../domain/registration.dart';
import '../../domain/sign_catalog.dart';
import '../../l10n/gen/app_localizations.dart';
import '../labels.dart';
import '../providers.dart';
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
  String? _infoVersion =
      kInformationVersions.length == 1 ? kInformationVersions.first : null;
  bool _presented = false;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _village = TextEditingController();
  final _birthYear = TextEditingController();
  PreferredChannel _channel = PreferredChannel.acVisit;
  bool _saving = false;
  String? _error;

  ConsentInput get _consent => ConsentInput(
        scopes: _scopes,
        method: _method,
        informationVersion: _infoVersion,
        informationPresented: _presented,
      );

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
    final consent = _consent;
    return ListView(
      key: const Key('consent-step'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.consentIntro, style: const TextStyle(fontSize: 17)),
        const SizedBox(height: 16),
        Text(l.consentScopes, style: Theme.of(context).textTheme.titleMedium),
        for (final s in ConsentScope.values)
          CheckboxListTile(
            key: Key('scope-${s.wire}'),
            value: _scopes.contains(s),
            title: Text(l.consentScope(s.wire)),
            onChanged: (v) => setState(() => v == true ? _scopes.add(s) : _scopes.remove(s)),
          ),
        const SizedBox(height: 8),
        Text(l.consentMethod, style: Theme.of(context).textTheme.titleMedium),
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
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('info-version'),
          value: _infoVersion,
          decoration: InputDecoration(labelText: l.infoVersion),
          items: [
            for (final v in kInformationVersions)
              DropdownMenuItem(value: v, child: Text(v)),
          ],
          onChanged: (v) => setState(() => _infoVersion = v),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const Key('info-presented'),
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
        FilledButton(
          key: const Key('consent-next'),
          onPressed: consent.isComplete ? () => setState(() => _step = 1) : null,
          child: Text(l.next),
        ),
      ],
    );
  }

  Widget _identityStep(AppLocalizations l) {
    return ListView(
      key: const Key('identity-step'),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
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
        Text(l.followUp, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
            controller: _birthYear,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.birthYear)),
        const SizedBox(height: 8),
        DropdownButtonFormField<PreferredChannel>(
          value: _channel,
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
            child: OutlinedButton(
                onPressed: _saving ? null : () => setState(() => _step = 0),
                child: Text(l.back)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
                key: const Key('save-registration'),
                onPressed: _saving ? null : _save,
                child: Text(l.save)),
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
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String text, bool active) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: active ? scheme.primary : scheme.surfaceContainerHighest,
            child: Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold)),
          ),
        );
    return Row(children: [
      chip(l.stepConsent, step == 0),
      chip(l.stepIdentity, step == 1),
    ]);
  }
}
