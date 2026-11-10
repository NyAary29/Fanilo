import 'dart:io' show Platform;

/// Configuration fournie à la compilation :
///
/// `flutter run --dart-define=FANILO_API_URL=http://localhost:8000`
///
/// `--dart-define=FANILO_FAKE_API=true` remplace l'API par une fausse API
/// locale (contenus FICTIFS marqués DÉMO), pour parcourir les écrans sans
/// serveur.
class AppConfig {
  const AppConfig({required this.apiBaseUrl, this.fakeApi = false});

  static const _defined = String.fromEnvironment('FANILO_API_URL');
  static const _fake = bool.fromEnvironment('FANILO_FAKE_API');

  /// Par défaut : API locale vue depuis l'émulateur Android (`10.0.2.2`) ou
  /// depuis le poste de développement (`localhost`). Sur un vrai téléphone
  /// relié en USB : `adb reverse tcp:8000 tcp:8000` puis
  /// `--dart-define=FANILO_API_URL=http://localhost:8000`.
  static String get _defaultUrl =>
      Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://localhost:8000';

  factory AppConfig.fromEnvironment() => AppConfig(
        apiBaseUrl: Uri.parse(_defined.isNotEmpty ? _defined : _defaultUrl),
        fakeApi: _fake,
      );

  final Uri apiBaseUrl;
  final bool fakeApi;

  /// Durée maximale d'un message vocal.
  static const maxRecording = Duration(seconds: 60);

  /// Relecture de l'état des questions tant que l'application est au
  /// premier plan (en plus du démarrage, du retour au premier plan, de
  /// l'ouverture de « Ny fanontaniako » et de l'ajout d'une question).
  static const pollInterval = Duration(seconds: 15);
}
