/// Configuration de l'application, fournie à la compilation :
///
/// `flutter run --dart-define=FANILO_API_URL=https://api.exemple.mg`
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  /// Par défaut : API locale vue depuis l'émulateur Android.
  static const _defaultUrl = 'http://10.0.2.2:8000';

  factory AppConfig.fromEnvironment() => AppConfig(
        apiBaseUrl: Uri.parse(const String.fromEnvironment('FANILO_API_URL',
            defaultValue: _defaultUrl)),
      );

  final Uri apiBaseUrl;

  /// Module utilisé pour le signalement de signes en P0.
  static const askModule = 'reny';
}
