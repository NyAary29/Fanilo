import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import 'providers.dart';
import 'screens/shell_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme.dart';

/// Le malgache n'est pas une locale Material/Cupertino : on charge les
/// libellés système (boutons, dialogues, accessibilité) en français.
class _FallbackDelegate<T> extends LocalizationsDelegate<T> {
  const _FallbackDelegate(this._inner);
  final LocalizationsDelegate<T> _inner;
  static const _fallback = Locale('fr');

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'mg';

  @override
  Future<T> load(Locale locale) => _inner.load(_fallback);

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  _FallbackDelegate<MaterialLocalizations>(GlobalMaterialLocalizations.delegate),
  _FallbackDelegate<CupertinoLocalizations>(GlobalCupertinoLocalizations.delegate),
  _FallbackDelegate<WidgetsLocalizations>(GlobalWidgetsLocalizations.delegate),
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

/// Malgache d'abord, français ensuite.
const supportedLocales = [Locale('mg'), Locale('fr')];

class FaniloFemmesApp extends ConsumerWidget {
  const FaniloFemmesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final onboarded = ref.watch(onboardedProvider);
    return MaterialApp(
      title: 'FANILO',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: localizationsDelegates,
      home: onboarded ? const ShellScreen() : const WelcomeScreen(),
    );
  }
}
