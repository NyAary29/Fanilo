import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/api/fake_public_api.dart';
import '../data/api/models.dart';
import '../data/api/public_api.dart';
import '../data/audio/voice.dart';
import '../data/local/local_store.dart';

final configProvider = Provider<AppConfig>((_) => AppConfig.fromEnvironment());

final apiProvider = Provider<PublicApi>((ref) {
  final config = ref.watch(configProvider);
  return config.fakeApi ? FakePublicApi(answerAfterPolls: 2) : HttpPublicApi(config.apiBaseUrl);
});

/// Fourni par `main()` (ou les tests) après `SharedPreferences.getInstance()`.
final storeProvider = Provider<LocalStore>((_) => throw UnimplementedError('storeProvider'));

final recorderProvider = Provider<VoiceRecorder>((ref) {
  final r = RecordVoiceRecorder();
  ref.onDispose(r.dispose);
  return r;
});

final playbackProvider = Provider<AudioPlayback>((_) => JustAudioPlayback());

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._store) : super(Locale(_store.locale));
  final LocalStore _store;

  Future<void> set(String code) async {
    state = Locale(code);
    await _store.setLocale(code);
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier(ref.watch(storeProvider)));

/// Langue envoyée à l'API (`mg` ou `fr`).
final languageProvider = Provider<String>((ref) => ref.watch(localeProvider).languageCode);

class OnboardedNotifier extends StateNotifier<bool> {
  OnboardedNotifier(this._store) : super(_store.onboarded);
  final LocalStore _store;

  Future<void> done() async {
    state = true;
    await _store.setOnboarded();
  }
}

final onboardedProvider = StateNotifierProvider<OnboardedNotifier, bool>(
    (ref) => OnboardedNotifier(ref.watch(storeProvider)));

class VoiceConsentNotifier extends StateNotifier<VoiceConsent?> {
  VoiceConsentNotifier(this._store) : super(_store.voiceConsent);
  final LocalStore _store;

  Future<void> accept(String version) async {
    final c = VoiceConsent(version: version, acceptedAt: DateTime.now());
    state = c;
    await _store.setVoiceConsent(c);
  }

  Future<void> withdraw() async {
    state = null;
    await _store.setVoiceConsent(null);
  }
}

final voiceConsentProvider = StateNotifierProvider<VoiceConsentNotifier, VoiceConsent?>(
    (ref) => VoiceConsentNotifier(ref.watch(storeProvider)));

class SiteNotifier extends StateNotifier<SavedSite?> {
  SiteNotifier(this._store) : super(_store.site);
  final LocalStore _store;

  Future<void> set(SavedSite? site) async {
    state = site;
    await _store.setSite(site);
  }
}

final siteProvider =
    StateNotifierProvider<SiteNotifier, SavedSite?>((ref) => SiteNotifier(ref.watch(storeProvider)));

class TicketsNotifier extends StateNotifier<List<Ticket>> {
  TicketsNotifier(this._store) : super(_store.tickets);
  final LocalStore _store;

  Future<void> add(Ticket t) async {
    await _store.addTicket(t);
    state = _store.tickets;
  }

  Future<void> remove(String questionId) async {
    await _store.removeTicket(questionId);
    state = _store.tickets;
  }

  Future<void> clear() async {
    await _store.clearTickets();
    state = const [];
  }
}

final ticketsProvider = StateNotifierProvider<TicketsNotifier, List<Ticket>>(
    (ref) => TicketsNotifier(ref.watch(storeProvider)));

/// Module choisi sur l'accueil (RENY ou TANORA), pour la session seulement.
final selectedModuleProvider = StateProvider<Module?>((_) => null);

/// Onglet courant : 0 accueil, 1 informations, 2 mes questions.
final tabProvider = StateProvider<int>((_) => 0);

/// Module affiché dans l'onglet « Fampahalalana ».
final infoModuleProvider = StateProvider<Module>((_) => Module.reny);

final informationProvider = FutureProvider<List<InformationItem>>(
    (ref) => ref.watch(apiProvider).information());

final sitesProvider = FutureProvider<List<Site>>((ref) => ref.watch(apiProvider).sites());

final menuProvider = FutureProvider.family<Menu, (Module, String)>(
    (ref, key) => ref.watch(apiProvider).menus(key.$1, key.$2));
