import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/api/api_client.dart';
import '../data/auth/auth_repository.dart';
import '../data/local/database.dart';
import '../data/reference/reference_repository.dart';
import '../data/repositories/local_repository.dart';
import '../data/repositories/outbox_repository.dart';
import '../data/secure/secure_store.dart';
import '../data/sync/sync_scheduler.dart';
import '../data/sync/sync_service.dart';
import '../domain/reference_data.dart';

/// Graphe de dépendances. Les feuilles « plateforme » (base, stockage
/// sécurisé, API, réseau) sont surchargées dans `main.dart` et dans les tests.

final appConfigProvider = Provider<AppConfig>((_) => AppConfig.fromEnvironment());

final secureStoreProvider = Provider<SecureStore>(
    (_) => throw UnimplementedError('secureStoreProvider à surcharger'));

final databaseProvider = Provider<AppDatabase>(
    (_) => throw UnimplementedError('databaseProvider à surcharger'));

final networkSourceProvider =
    Provider<NetworkStatusSource>((_) => ConnectivityPlusSource());

final transportProvider = Provider<ApiTransport>(
    (ref) => ApiTransport(baseUrl: ref.watch(appConfigProvider).apiBaseUrl));

final authApiProvider =
    Provider<AuthApi>((ref) => HttpAuthApi(ref.watch(transportProvider)));

final authProvider = StateNotifierProvider<AuthRepository, AuthState>((ref) =>
    AuthRepository(ref.watch(authApiProvider), ref.watch(secureStoreProvider)));

final _httpApiProvider = Provider<HttpFaniloApi>((ref) => HttpFaniloApi(
    ref.watch(transportProvider), ref.watch(authProvider.notifier)));

final syncApiProvider = Provider<SyncApi>((ref) => ref.watch(_httpApiProvider));

final interactionApiProvider =
    Provider<InteractionApi>((ref) => ref.watch(_httpApiProvider));

final referenceApiProvider =
    Provider<ReferenceApi>((ref) => ref.watch(_httpApiProvider));

final referenceRepositoryProvider = Provider<ReferenceRepository>((ref) =>
    ReferenceRepository(ref.watch(databaseProvider), ref.watch(referenceApiProvider),
        modules: const [AppConfig.askModule]));

final outboxRepositoryProvider =
    Provider<OutboxRepository>((ref) => OutboxRepository(ref.watch(databaseProvider)));

final localRepositoryProvider = Provider<LocalRepository>((ref) => LocalRepository(
    ref.watch(databaseProvider), ref.watch(outboxRepositoryProvider)));

final syncServiceProvider = Provider<SyncService>((ref) {
  final s = SyncService(
      db: ref.watch(databaseProvider),
      api: ref.watch(syncApiProvider),
      references: ref.watch(referenceRepositoryProvider));
  ref.onDispose(s.dispose);
  return s;
});

/// Démarré par l'écran d'accueil (utilisateur connecté).
final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(
    ref.watch(syncServiceProvider),
    ref.watch(networkSourceProvider),
    canSync: () => !ref.read(authProvider).needsReauth,
  );
  scheduler.start();
  ref.onDispose(scheduler.stop);
  return scheduler;
});

// ------------------------------------------------------------- flux d'état

final onlineProvider = StreamProvider<bool>((ref) async* {
  final source = ref.watch(networkSourceProvider);
  yield await source.isOnline();
  yield* source.onlineChanges;
});

final syncRunningProvider = StreamProvider<bool>((ref) async* {
  final s = ref.watch(syncServiceProvider);
  yield s.isRunning;
  yield* s.runningStream;
});

final pendingCountProvider = StreamProvider<int>(
    (ref) => ref.watch(outboxRepositoryProvider).watchPendingCount());

final rejectedProvider =
    StreamProvider((ref) => ref.watch(outboxRepositoryProvider).watchRejected());

final conflictsProvider =
    StreamProvider((ref) => ref.watch(localRepositoryProvider).watchOpenConflicts());

final lastSyncAtProvider = StreamProvider<String?>(
    (ref) => ref.watch(databaseProvider).watchState(SyncStateKeys.lastSyncAt));

final lastSyncErrorProvider = StreamProvider<String?>(
    (ref) => ref.watch(databaseProvider).watchState(SyncStateKeys.lastSyncError));

final beneficiariesProvider =
    StreamProvider((ref) => ref.watch(localRepositoryProvider).watchBeneficiaries());

final identitiesProvider =
    StreamProvider((ref) => ref.watch(localRepositoryProvider).watchIdentities());

final upcomingAncProvider =
    StreamProvider((ref) => ref.watch(localRepositoryProvider).watchUpcomingAnc());

final alertsProvider =
    StreamProvider((ref) => ref.watch(localRepositoryProvider).watchAlerts());

final openAlertsProvider = StreamProvider(
    (ref) => ref.watch(localRepositoryProvider).watchAlerts(openOnly: true));

final referralsProvider =
    StreamProvider((ref) => ref.watch(localRepositoryProvider).watchReferrals());

final beneficiaryProvider = StreamProvider.family(
    (ref, String id) => ref.watch(localRepositoryProvider).watchBeneficiary(id));

final identityProvider = StreamProvider.family(
    (ref, String id) => ref.watch(localRepositoryProvider).watchIdentity(id));

final consentsProvider = StreamProvider.family(
    (ref, String id) => ref.watch(localRepositoryProvider).watchConsents(id));

final pregnanciesProvider = StreamProvider.family(
    (ref, String id) => ref.watch(localRepositoryProvider).watchPregnancies(id));

final ancVisitsProvider = StreamProvider.family(
    (ref, String pregnancyId) =>
        ref.watch(localRepositoryProvider).watchAncVisits(pregnancyId));

/// Clés `entity/id` ayant une modification locale non encore confirmée.
final pendingKeysProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.outbox)..where((o) => o.status.equals('pending')))
      .watch()
      .map((rows) => {for (final r in rows) '${r.entity}/${r.entityId}'});
});

/// Sites pouvant recevoir une référence (hors site de l'utilisateur).
final referralSitesProvider = StreamProvider<List<SiteRow>>((ref) => ref
    .watch(localRepositoryProvider)
    .watchReferralSites(excludeSiteId: ref.watch(authProvider).user?.siteId));

final sitesByIdProvider = StreamProvider<Map<String, SiteRow>>(
    (ref) => ref.watch(localRepositoryProvider).watchSitesById());

/// Codes de signes (copie locale du référentiel serveur), null si jamais reçu.
final signCatalogProvider = StreamProvider<SignCatalog?>((ref) => ref
    .watch(referenceRepositoryProvider)
    .watchSignCatalog(AppConfig.askModule));

/// Information de consentement (copie locale), null si jamais reçue.
final consentInformationProvider = StreamProvider<ConsentInformationSet?>(
    (ref) => ref.watch(referenceRepositoryProvider).watchConsentInformation());

/// Contenus publiés (copie locale) pour les conseils de visite, null si
/// jamais reçus.
final publishedContentsProvider = StreamProvider<PublishedContents?>((ref) => ref
    .watch(referenceRepositoryProvider)
    .watchContents(AppConfig.askModule));

final allPregnanciesProvider =
    StreamProvider((ref) => ref.watch(localRepositoryProvider).watchAllPregnancies());

final allAncVisitsProvider =
    StreamProvider((ref) => ref.watch(localRepositoryProvider).watchAllAncVisits());

/// Date du jour `YYYY-MM-DD` (heure locale du téléphone), surchargeable dans
/// les tests.
final todayProvider =
    Provider<String>((_) => DateTime.now().toIso8601String().substring(0, 10));

/// Onglet affiché par l'écran principal (0 Accueil, 1 Mes visites, 2 Alerter).
final homeTabProvider = StateProvider<int>((_) => 0);
