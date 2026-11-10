import 'package:fanilo_mobile/data/api/api_client.dart';
import 'package:fanilo_mobile/data/auth/auth_repository.dart';
import 'package:fanilo_mobile/data/local/encrypted_connection.dart';
import 'package:fanilo_mobile/data/secure/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fakes.dart';

void main() {
  group('AuthRepository', () {
    late FakeAuthApi api;
    late InMemorySecureStore store;
    late DateTime now;
    late AuthRepository auth;

    setUp(() {
      api = FakeAuthApi();
      store = InMemorySecureStore();
      now = DateTime.now().toUtc();
      auth = AuthRepository(api, store, now: () => now);
    });

    test('login : jetons et profil dans le stockage sécurisé', () async {
      await auth.login('ac.demo', 'secret');
      expect(auth.state.status, AuthStatus.signedIn);
      expect(store.values[AuthRepository.kAccess], 'access-0');
      expect(store.values[AuthRepository.kRefresh], 'refresh-0');
      expect(store.values[AuthRepository.kUser], contains('community_agent'));
    });

    test('mauvais mot de passe : ApiException 401, rien stocké', () async {
      await expectLater(auth.login('ac.demo', 'x'), throwsA(isA<ApiException>()));
      expect(store.values, isEmpty);
    });

    test('session restaurée sans réseau (usage hors ligne)', () async {
      await auth.login('ac.demo', 'secret');
      api.offline = true;
      final restored = AuthRepository(api, store, now: () => now);
      await restored.restore();
      expect(restored.state.status, AuthStatus.signedIn);
      expect(restored.state.user!.siteId, 'site-demo-1');
    });

    test('refresh proactif avant expiration, un seul appel concurrent', () async {
      await auth.login('ac.demo', 'secret');
      expect(await auth.validAccessToken(), 'access-0');
      now = now.add(const Duration(seconds: 900 - 30)); // dans la marge
      final tokens = await Future.wait([auth.validAccessToken(), auth.validAccessToken()]);
      expect(tokens, ['access-1', 'access-1']);
      expect(api.refreshCalls, 1);
      expect(store.values[AuthRepository.kRefresh], 'refresh-1', reason: 'rotation');
    });

    test('refresh refusé : reconnexion demandée, session locale conservée', () async {
      await auth.login('ac.demo', 'secret');
      api.refreshRejected = true;
      await expectLater(auth.refreshAfterUnauthorized(),
          throwsA(isA<SessionExpiredException>()));
      expect(auth.state.status, AuthStatus.signedIn);
      expect(auth.state.needsReauth, isTrue);

      // Reconnexion avec le même compte : l'indicateur disparaît.
      await auth.login('ac.demo', 'secret');
      expect(auth.state.needsReauth, isFalse);
    });

    test('refresh hors ligne : erreur réseau, pas de demande de reconnexion', () async {
      await auth.login('ac.demo', 'secret');
      api.offline = true;
      await expectLater(auth.refreshAfterUnauthorized(), throwsA(isA<NetworkException>()));
      expect(auth.state.needsReauth, isFalse);
    });

    test('logout efface les jetons', () async {
      await auth.login('ac.demo', 'secret');
      await auth.logout();
      expect(store.values, isEmpty);
      expect(auth.state.status, AuthStatus.signedOut);
    });
  });

  group('Chiffrement (vérifiable sans appareil)', () {
    setUpAll(useSystemSqliteForTests);

    test('clé 256 bits générée une fois puis réutilisée', () async {
      final store = InMemorySecureStore();
      final k1 = await DatabaseKeyStore(store).getOrCreateKey();
      final k2 = await DatabaseKeyStore(store).getOrCreateKey();
      expect(k1, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(k2, k1);
      expect(store.values[DatabaseKeyStore.storageKey], k1);
    });

    test('clé corrompue remplacée', () async {
      final store = InMemorySecureStore()..values[DatabaseKeyStore.storageKey] = 'abc';
      final k = await DatabaseKeyStore(store).getOrCreateKey();
      expect(DatabaseKeyStore.isValidKey(k), isTrue);
    });

    test('ouverture refusée si la bibliothèque n\'est pas SQLCipher', () {
      // SQLite système de la machine de test (sans SQLCipher).
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      final cipher = db.select('PRAGMA cipher_version;');
      if (cipher.isNotEmpty) {
        markTestSkipped('SQLCipher présent sur cette machine');
        return;
      }
      expect(() => applyCipherKey(db, 'a' * 64),
          throwsA(isA<EncryptionUnavailableException>()));
    });

    test('clé mal formée refusée', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      expect(() => applyCipherKey(db, "x'; DROP"), throwsArgumentError);
    });
  });
}
