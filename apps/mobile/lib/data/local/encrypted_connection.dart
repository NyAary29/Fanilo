import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import '../secure/secure_store.dart';

/// Gestion de la clé de chiffrement de la base locale.
///
/// La clé (256 bits aléatoires, `Random.secure`) est générée au premier
/// lancement et stockée uniquement dans le stockage sécurisé du système
/// (Keystore / Keychain). Elle n'est jamais écrite sur disque en clair.
class DatabaseKeyStore {
  DatabaseKeyStore(this._store, {Random? random})
      : _random = random ?? Random.secure();

  static const storageKey = 'fanilo.db_key.v1';

  final SecureStore _store;
  final Random _random;

  Future<String> getOrCreateKey() async {
    final existing = await _store.read(storageKey);
    if (existing != null && isValidKey(existing)) return existing;
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _store.write(storageKey, hex);
    return hex;
  }

  static bool isValidKey(String key) =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(key);
}

class EncryptionUnavailableException implements Exception {
  const EncryptionUnavailableException();
  @override
  String toString() =>
      'SQLCipher indisponible : la base locale ne serait pas chiffrée. '
      'Ouverture refusée.';
}

/// Applique la clé (clé brute hexadécimale, sans dérivation PBKDF2) puis
/// vérifie que la bibliothèque chargée est bien SQLCipher.
///
/// Refuse d'ouvrir la base si SQLCipher n'est pas présent : on ne stocke
/// jamais de données de santé dans une base SQLite non chiffrée.
void applyCipherKey(Database db, String hexKey) {
  if (!DatabaseKeyStore.isValidKey(hexKey)) {
    throw ArgumentError('Clé de base invalide');
  }
  assertCipherAvailable(db);
  db.execute("PRAGMA key = \"x'$hexKey'\";");
  // Lecture de contrôle : échoue si la clé ne correspond pas au fichier.
  db.select('SELECT count(*) FROM sqlite_master;');
}

/// Lève [EncryptionUnavailableException] si `PRAGMA cipher_version` ne
/// renvoie rien (SQLite standard, sans chiffrement).
void assertCipherAvailable(Database db) {
  final rows = db.select('PRAGMA cipher_version;');
  if (rows.isEmpty || (rows.first.values.first?.toString() ?? '').isEmpty) {
    throw const EncryptionUnavailableException();
  }
}

/// Nom de la bibliothèque SQLCipher compilée par `sqlcipher_flutter_libs`
/// pour Linux (copiée dans `bundle/lib/` et déjà chargée par l'exécutable).
const linuxSqlCipherLibrary = 'libsqlcipher_flutter_libs_plugin.so';

/// Configure le chargement de la bibliothèque SQLCipher.
///
/// - Android : `libsqlcipher.so` fournie par `sqlcipher_flutter_libs`.
/// - Linux (poste de développement) : SQLCipher compilé par le plugin, lié
///   statiquement à OpenSSL. Sans cette surcharge, `package:sqlite3`
///   chargerait le `libsqlite3.so` du système, non chiffré, et l'ouverture
///   serait refusée par [assertCipherAvailable].
/// - iOS : `sqlcipher_flutter_libs` lie SQLCipher statiquement.
void overrideSqliteWithSqlCipher() {
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  open.overrideFor(
      OperatingSystem.linux, () => DynamicLibrary.open(linuxSqlCipherLibrary));
}

/// Ouvre la base chiffrée de l'application dans un isolat d'arrière-plan.
///
/// Couvert sur Linux par `integration_test/e2e_test.dart` (SQLCipher réel) ;
/// sur Android et iOS, à vérifier sur appareil : voir README, « Chiffrement ».
///
/// [file] permet aux tests d'intégration d'utiliser un fichier temporaire
/// (toujours chiffré).
Future<QueryExecutor> openEncryptedExecutor(SecureStore secureStore,
    {File? file}) async {
  final key = await DatabaseKeyStore(secureStore).getOrCreateKey();
  file ??= File(p.join(
      (await getApplicationSupportDirectory()).path, 'fanilo.sqlite'));

  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
  }

  return NativeDatabase.createInBackground(
    file,
    isolateSetup: overrideSqliteWithSqlCipher,
    setup: (db) => applyCipherKey(db, key),
  );
}
