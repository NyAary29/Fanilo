import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth/auth_repository.dart';
import '../l10n/gen/app_localizations.dart';
import 'providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

/// Thème : grandes cibles tactiles (≥ 56 px), texte lisible.
ThemeData buildTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
    useMaterial3: true,
  );
  const minSize = Size(64, 56);
  const text = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: minSize, textStyle: text)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: minSize, textStyle: text)),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48), textStyle: text)),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    listTileTheme: const ListTileThemeData(minTileHeight: 56),
  );
}

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
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.signedIn => const HomeScreen(),
    };
  }
}
