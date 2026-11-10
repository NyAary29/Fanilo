import 'dart:io' show Platform;

/// Configuration de l'application, fournie à la compilation :
///
/// `flutter run --dart-define=FANILO_API_URL=https://api.exemple.mg`
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  static const _defined = String.fromEnvironment('FANILO_API_URL');

  /// Par défaut : API locale, vue depuis l'émulateur Android (`10.0.2.2`)
  /// ou depuis le poste de développement (`localhost`, cible Linux).
  static String get _defaultUrl =>
      Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://localhost:8000';

  factory AppConfig.fromEnvironment() => AppConfig(
      apiBaseUrl: Uri.parse(_defined.isNotEmpty ? _defined : _defaultUrl));

  final Uri apiBaseUrl;

  /// Module utilisé pour le signalement de signes en P0.
  static const askModule = 'reny';
}
