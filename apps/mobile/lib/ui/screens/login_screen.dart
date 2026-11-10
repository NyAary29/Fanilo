import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/auth/auth_repository.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

/// Connexion. Utilisé au premier lancement et pour se reconnecter quand la
/// session a expiré (dans ce cas, l'écran est fermé après succès).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.isReauth = false});
  final bool isReauth;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (widget.isReauth && user != null) _login.text = user.login;
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (_login.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(_login.text, _password.text);
      if (!mounted) return;
      if (widget.isReauth) {
        Navigator.of(context).pop();
        // Les modifications en attente partent tout de suite.
        ref.read(syncServiceProvider).sync(force: true);
      }
    } on ApiException catch (e) {
      setState(() => _error = (e.statusCode == 401 || e.statusCode == 422)
          ? l.loginErrorCredentials
          : l.loginErrorGeneric);
    } on NetworkException {
      setState(() => _error = l.loginErrorOffline);
    } on DifferentUserException {
      setState(() => _error = l.loginErrorDifferentUser);
    } on Object {
      setState(() => _error = l.loginErrorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final form = SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.isReauth ? l.reauthButton : l.loginTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: FaniloColors.forestDark)),
          const SizedBox(height: 16),
          TextField(
            key: const Key('login-field'),
            controller: _login,
            enabled: !widget.isReauth,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
                labelText: l.loginField, prefixIcon: const Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('password-field'),
            controller: _password,
            obscureText: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
                labelText: l.passwordField, prefixIcon: const Icon(Icons.lock_outline)),
          ),
          const SizedBox(height: 18),
          if (_error != null)
            NoticeCard(tone: NoticeTone.alert, text: _error!),
          FilledButton.icon(
            key: const Key('login-button'),
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.login),
            label: Text(l.loginButton),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: widget.isReauth ? AppBar() : null,
      bottomNavigationBar: const DisclaimerFooter(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              decoration: BoxDecoration(
                color: FaniloColors.forest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(children: [
                FaniloLogo(size: 64, onDark: true, tagline: l.appTagline),
                const SizedBox(height: 16),
                Text(l.loginWelcome,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 16),
            form,
          ],
        ),
      ),
    );
  }
}
