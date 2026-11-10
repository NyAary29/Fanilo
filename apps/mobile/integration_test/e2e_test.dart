// Test de bout en bout contre une API FANILO **réelle** (locale), avec la base
// chiffrée SQLCipher réelle (Linux : bibliothèque compilée par
// sqlcipher_flutter_libs).
//
//   flutter test integration_test -d linux \
//     --dart-define=FANILO_API_URL=http://localhost:8000
//
// Prérequis : API démarrée, données de démonstration chargées
// (FANILO_ALLOW_DEMO_CONTENT=true), compte `ac.a1` / `fanilo-demo-2026`.
// Données créées : une bénéficiaire FICTIVE, sa grossesse, une référence et
// une alerte de démonstration.
import 'dart:async';
import 'dart:io';

import 'package:fanilo_mobile/data/local/database.dart';
import 'package:fanilo_mobile/data/local/encrypted_connection.dart';
import 'package:fanilo_mobile/data/secure/secure_store.dart';
import 'package:fanilo_mobile/data/sync/sync_scheduler.dart';
import 'package:fanilo_mobile/ui/app.dart';
import 'package:fanilo_mobile/ui/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _login = String.fromEnvironment('FANILO_E2E_LOGIN', defaultValue: 'ac.a1');
const _password =
    String.fromEnvironment('FANILO_E2E_PASSWORD', defaultValue: 'fanilo-demo-2026');

/// Réseau considéré comme disponible (l'API locale l'est).
class _AlwaysOnline implements NetworkStatusSource {
  @override
  Future<bool> isOnline() async => true;
  @override
  Stream<bool> get onlineChanges => const Stream.empty();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AC : connexion, enregistrement, grossesse, CPN, référence, signes, alerte',
      (tester) async {
    final dir = await Directory.systemTemp.createTemp('fanilo_e2e');
    final file = File('${dir.path}/fanilo.sqlite');
    final store = InMemorySecureStore();
    final db = AppDatabase(await openEncryptedExecutor(store, file: file));

    // 0. SQLCipher réellement chargé (sinon l'ouverture aurait été refusée).
    final cipher = await db.customSelect('PRAGMA cipher_version').get();
    expect(cipher.single.data.values.first.toString(), isNotEmpty);

    Future<void> pumpUntil(FutureOr<bool> Function() done, String what,
        {Duration timeout = const Duration(seconds: 40)}) async {
      final end = DateTime.now().add(timeout);
      while (!await done()) {
        if (DateTime.now().isAfter(end)) fail('Délai dépassé : $what');
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> tapVisible(Finder f, {Finder? scrollable}) async {
      // Un SnackBar (ex. « Synchronisation terminée. ») peut masquer le bas
      // de l'écran.
      for (final m in tester.stateList<ScaffoldMessengerState>(
          find.byType(ScaffoldMessenger))) {
        m.removeCurrentSnackBar();
      }
      if (f.evaluate().isEmpty) {
        // Élément pas encore construit (liste paresseuse) : on fait défiler.
        await tester.scrollUntilVisible(f, 200,
            scrollable: scrollable ?? find.byType(Scrollable).first);
      }
      await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pump();
    }

    final container = ProviderContainer(overrides: [
      secureStoreProvider.overrideWithValue(store),
      databaseProvider.overrideWithValue(db),
      networkSourceProvider.overrideWithValue(_AlwaysOnline()),
    ]);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const FaniloApp()));

    // 1. Connexion.
    await pumpUntil(
        () => find.byKey(const Key('login-field')).evaluate().isNotEmpty, 'écran de login');
    await tester.enterText(find.byKey(const Key('login-field')), _login);
    await tester.enterText(find.byKey(const Key('password-field')), _password);
    await tester.tap(find.byKey(const Key('login-button')));
    await pumpUntil(
        () => find.byKey(const Key('sync-button')).evaluate().isNotEmpty, 'accueil');

    // 2. Première synchro : sites (pull) et référentiels.
    await tester.tap(find.byKey(const Key('sync-button')));
    await pumpUntil(() async => (await db.select(db.sites).get()).isNotEmpty, 'sites');
    await pumpUntil(
        () async => (await db.select(db.referenceCache).get()).length >= 2, 'référentiels');

    // 3. Enregistrement avec consentement (information servie par l'API).
    await tester.tap(find.byKey(const Key('action-new-patient')));
    await pumpUntil(
        () => find.byKey(const Key('scope-info-reny')).evaluate().isNotEmpty,
        'information de consentement');
    expect(find.textContaining('Information version'), findsWidgets);
    await tapVisible(find.text('Orale'));
    await tapVisible(find.byKey(const Key('info-presented')));
    await tapVisible(find.byKey(const Key('consent-next')));
    await tester.pumpAndSettle();
    final name = 'Personne fictive E2E ${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(find.byKey(const Key('name-field')), name);
    await tapVisible(find.byKey(const Key('save-registration')));
    await pumpUntil(
        () => find.byKey(const Key('declare-pregnancy')).evaluate().isNotEmpty,
        'fiche bénéficiaire');
    final identity = (await (db.select(db.beneficiaryIdentities)
              ..where((i) => i.displayName.equals(name)))
            .getSingle());
    final beneficiaryId = identity.beneficiaryId;

    // Code FAN-XXXXXX attribué par le serveur.
    await pumpUntil(() async {
      final b = await (db.select(db.beneficiaries)..where((b) => b.id.equals(beneficiaryId)))
          .getSingle();
      return b.code != null && b.version > 0;
    }, 'code FAN attribué par le serveur');

    // 4. Déclaration de grossesse SANS date des dernières règles : le serveur
    // ne génère pas de calendrier et la fiche l'indique.
    await pumpUntil(() {
      final btn = find.byKey(const Key('declare-pregnancy'));
      return btn.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(btn).onPressed != null;
    }, 'bouton grossesse actif');
    await tapVisible(find.byKey(const Key('declare-pregnancy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-pregnancy-dates')));
    await tester.pumpAndSettle();
    await pumpUntil(() async {
      final p = await (db.select(db.pregnancies)
            ..where((p) => p.beneficiaryId.equals(beneficiaryId)))
          .get();
      return p.isNotEmpty && p.single.version > 0;
    }, 'grossesse acceptée par le serveur');
    await tester.pumpAndSettle();
    expect(find.textContaining('Pas de calendrier CPN'), findsOneWidget);

    // Puis saisie de la date après coup (upsert pregnancy) : le serveur
    // génère alors le calendrier. Le sélecteur s'ouvre sur aujourd'hui.
    final pregnancyId = (await (db.select(db.pregnancies)
              ..where((p) => p.beneficiaryId.equals(beneficiaryId)))
            .getSingle())
        .id;
    await tapVisible(find.byKey(Key('edit-pregnancy-dates-$pregnancyId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lmp-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-pregnancy-dates')));
    await tester.pumpAndSettle();

    // 5. Synchro : le calendrier CPN revient du serveur.
    await pumpUntil(() async {
      final p = await (db.select(db.pregnancies)
            ..where((p) => p.beneficiaryId.equals(beneficiaryId)))
          .get();
      if (p.isEmpty || p.single.version < 2) return false;
      final visits = await (db.select(db.ancVisits)
            ..where((v) => v.pregnancyId.equals(p.single.id)))
          .get();
      if (visits.isEmpty) {
        // Au cas où le calendrier n'arriverait qu'au pull suivant.
        unawaited(container.read(syncServiceProvider).sync(force: true));
      }
      return visits.isNotEmpty;
    }, 'calendrier CPN');
    await tester.pumpAndSettle();
    expect(find.textContaining('CPN 1'), findsWidgets);

    // 6. Référence vers un CSB synchronisé (statut proposed, via l'outbox).
    await tapVisible(find.byKey(const Key('refer-beneficiary')),
        scrollable: find
            .descendant(
                of: find.byKey(const Key('follow-up-tab')), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('referral-site')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('CSB II Démo Bongolava A').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('referral-reason')), 'Test E2E (fictif)');
    await tester.tap(find.byKey(const Key('save-referral')));
    await pumpUntil(() async {
      final r = await (db.select(db.referrals)
            ..where((r) => r.beneficiaryId.equals(beneficiaryId)))
          .get();
      return r.isNotEmpty && r.single.version > 0;
    }, 'référence acceptée par le serveur');
    final referral = await (db.select(db.referrals)
          ..where((r) => r.beneficiaryId.equals(beneficiaryId)))
        .getSingle();
    expect(referral.status, 'proposed');
    expect(referral.fromSiteId, isNotNull);

    // 7. Signes (en ligne) : orientation et alerte, jamais de diagnostic.
    await tester.pumpAndSettle();
    // Retour en haut de la fiche (en-tête et boutons « Visite » / « Alerter »).
    await tester.fling(find.byKey(const Key('follow-up-tab')), const Offset(0, 3000), 4000);
    await tester.pumpAndSettle();
    await tapVisible(find.byKey(const Key('patient-alert')));
    await pumpUntil(
        () => find.byKey(const Key('sign-SIGN_DEMO_01')).evaluate().isNotEmpty,
        'liste des signes (API)');
    expect(find.byKey(const Key('demo-banner')), findsWidgets);
    await tapVisible(find.byKey(const Key('sign-SIGN_DEMO_01')));
    await tapVisible(find.byKey(const Key('signs-send')));
    await pumpUntil(
        () => find.byKey(const Key('signs-result')).evaluate().isNotEmpty, 'orientation');
    expect(find.text('Alerte transmise. En attente d\'accusé de réception.'), findsOneWidget);
    expect(find.text('Orienter vers la structure de référence'), findsOneWidget);
    expect(find.text('Critique'), findsNothing, reason: 'pas de sévérité affichée');

    // 8. L'alerte revient par la synchro (lecture seule).
    await pumpUntil(() async {
      final a = await (db.select(db.alerts)
            ..where((a) => a.beneficiaryId.equals(beneficiaryId)))
          .get();
      return a.isNotEmpty;
    }, 'alerte synchronisée');
    final alert = await (db.select(db.alerts)
          ..where((a) => a.beneficiaryId.equals(beneficiaryId)))
        .getSingle();
    expect(alert.isDemo, isTrue);
    expect(['open', 'escalated'], contains(alert.status));

    expect(await db.select(db.outbox).get(), isEmpty, reason: 'tout est envoyé');

    // 9. Le fichier est chiffré : pas d'en-tête SQLite en clair.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await db.close();
    final header = String.fromCharCodes((await file.readAsBytes()).take(15));
    expect(header, isNot('SQLite format 3'));
    await dir.delete(recursive: true);
  });
}
