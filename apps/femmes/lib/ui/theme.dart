import 'package:flutter/material.dart';

/// Copié et adapté de apps/mobile/lib/ui/theme.dart (pas d'import entre
/// applications).
///
/// Palette FANILO (maquette « écosystème FANILO ») : vert forêt, fonds
/// crème et menthe, rouge doux pour les alertes, orange pour « À suivre ».
abstract final class FaniloColors {
  static const forest = Color(0xFFB0306A);
  static const forestDark = Color(0xFF8A2352);
  static const leaf = Color(0xFFC94B85);
  static const leafLight = Color(0xFFE8A1C1);
  static const mint = Color(0xFFFBEAF1);
  static const mintStrong = Color(0xFFF5D3E2);
  static const cream = Color(0xFFFBF5F7);
  static const surface = Colors.white;
  static const ink = Color(0xFF2A1D24);
  static const inkSoft = Color(0xFF6B5961);
  static const line = Color(0xFFEDDFE5);

  static const alert = Color(0xFFD64541);
  static const alertSoft = Color(0xFFFCE9E7);
  static const alertInk = Color(0xFF9E2622);

  static const follow = Color(0xFFE07B1A);
  static const followSoft = Color(0xFFFDEFD9);
  static const followInk = Color(0xFF8A4A0C);

  static const ok = Color(0xFF2E8B57);
  static const okSoft = Color(0xFFE2F3E8);

  static const demo = Color(0xFFB45309);
  static const demoSoft = Color(0xFFFEF3C7);
  static const sun = Color(0xFFE9A23B);

  // Modules de l'application Femmes & Adolescentes (maquette) :
  // RENY en rose, TANORA en menthe.
  static const reny = Color(0xFFF6D3D3);
  static const renyStrong = Color(0xFFE07A86);
  static const renyInk = Color(0xFF8C2F3D);
  static const tanora = Color(0xFFD5EFE3);
  static const tanoraStrong = Color(0xFF3E9E7A);
  static const tanoraInk = Color(0xFF1F5E3F);
}

const kRadius = 16.0;
const kTouch = 56.0;

/// Ombre douce des cartes.
const kSoftShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
];

/// Thème : grandes cibles tactiles (≥ 56 px), texte lisible et gras, cartes
/// arrondies.
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: FaniloColors.forest,
    primary: FaniloColors.forest,
    onPrimary: Colors.white,
    primaryContainer: FaniloColors.mintStrong,
    onPrimaryContainer: FaniloColors.forestDark,
    secondary: FaniloColors.leaf,
    secondaryContainer: FaniloColors.mint,
    onSecondaryContainer: FaniloColors.forestDark,
    error: FaniloColors.alert,
    errorContainer: FaniloColors.alertSoft,
    onErrorContainer: FaniloColors.alertInk,
    surface: FaniloColors.surface,
    onSurface: FaniloColors.ink,
    onSurfaceVariant: FaniloColors.inkSoft,
    surfaceContainerHighest: FaniloColors.mint,
    outline: FaniloColors.line,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme.apply(bodyColor: FaniloColors.ink, displayColor: FaniloColors.ink);
  final textTheme = text.copyWith(
    headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 21),
    titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 17),
    bodyLarge: text.bodyLarge?.copyWith(fontSize: 17),
    bodyMedium: text.bodyMedium?.copyWith(fontSize: 15.5),
    labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 17),
  );
  const minSize = Size(64, kTouch);
  final buttonText = textTheme.labelLarge!.copyWith(fontSize: 17, fontWeight: FontWeight.w700);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius));
  return base.copyWith(
    scaffoldBackgroundColor: FaniloColors.cream,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: FaniloColors.cream,
      foregroundColor: FaniloColors.forest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: FaniloColors.forest),
      toolbarHeight: 64,
    ),
    cardTheme: CardThemeData(
      color: FaniloColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: FaniloColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: minSize,
            textStyle: buttonText,
            shape: shape,
            padding: const EdgeInsets.symmetric(horizontal: 20))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: minSize,
            textStyle: buttonText,
            shape: shape,
            foregroundColor: FaniloColors.forest,
            side: const BorderSide(color: FaniloColors.forest, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 20))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: buttonText,
            foregroundColor: FaniloColors.forest)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FaniloColors.surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: FaniloColors.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: FaniloColors.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: FaniloColors.forest, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    listTileTheme: const ListTileThemeData(minTileHeight: kTouch),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: FaniloColors.forest, width: 2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: FaniloColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: FaniloColors.mintStrong,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => textTheme.labelMedium!.copyWith(
            fontSize: 14,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? FaniloColors.forest : FaniloColors.inkSoft,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 28,
            color: s.contains(WidgetState.selected) ? FaniloColors.forest : FaniloColors.inkSoft,
          )),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: FaniloColors.forest,
      unselectedLabelColor: FaniloColors.inkSoft,
      indicatorColor: FaniloColors.forest,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: textTheme.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
      unselectedLabelStyle:
          textTheme.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      dividerColor: FaniloColors.line,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FaniloColors.forestDark,
      contentTextStyle: textTheme.bodyLarge!.copyWith(fontSize: 16, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: FaniloColors.cream,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: FaniloColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(64, kTouch),
        selectedBackgroundColor: FaniloColors.mintStrong,
        selectedForegroundColor: FaniloColors.forestDark,
        textStyle: buttonText,
      ),
    ),
    dividerTheme: const DividerThemeData(color: FaniloColors.line, space: 1),
  );
}
