import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/auth/auth_repository.dart';
import '../providers.dart';
import '../widgets/common.dart';

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
    return FaniloScaffold(
      title: l.loginTitle,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l.appTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 32),
          TextField(
            key: const Key('login-field'),
            controller: _login,
            enabled: !widget.isReauth,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l.loginField),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('password-field'),
            controller: _password,
            obscureText: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: l.passwordField),
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 16)),
            ),
          FilledButton(
            key: const Key('login-button'),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 24, width: 24, child: CircularProgressIndicator())
                : Text(l.loginButton),
          ),
        ],
      ),
    );
  }
}
