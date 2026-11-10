import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth/auth_repository.dart';
import '../l10n/gen/app_localizations.dart';
import 'providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';
import 'widgets/logo.dart';

export 'theme.dart' show buildTheme;

class FaniloApp extends StatelessWidget {
  const FaniloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      theme: buildTheme(),
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

/// Choisit l'écran selon la session. Une session restaurée suffit pour
/// travailler hors ligne ; aucune requête réseau n'est nécessaire.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    if (auth.status == AuthStatus.unknown) {
      Future.microtask(() => ref.read(authProvider.notifier).restore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authProvider.select((s) => s.status));
    return switch (status) {
      AuthStatus.unknown =>
        const Scaffold(body: Center(child: FaniloMark(size: 96))),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.signedIn => const HomeScreen(),
    };
  }
}
