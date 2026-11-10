import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local/database.dart';
import 'data/local/encrypted_connection.dart';
import 'data/secure/secure_store.dart';
import 'ui/app.dart';
import 'ui/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final secureStore = FlutterSecureStore();

  AppDatabase db;
  try {
    db = AppDatabase(await openEncryptedExecutor(secureStore));
    // Force l'ouverture maintenant : échoue si SQLCipher est absent.
    await db.customSelect('SELECT 1').get();
  } on Object catch (e, st) {
    debugPrint('FANILO: ouverture de la base chiffrée refusée : $e\n$st');
    runApp(_FatalErrorApp(error: e));
    return;
  }

  runApp(ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(secureStore),
      databaseProvider.overrideWithValue(db),
    ],
    child: const FaniloApp(),
  ));
}

/// Affiché si la base chiffrée ne peut pas être ouverte : on ne bascule
/// jamais vers une base non chiffrée.
class _FatalErrorApp extends StatelessWidget {
  const _FatalErrorApp({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Impossible d\'ouvrir la base de données chiffrée.\n\n$error\n\n'
                'FANILO ne remplace pas un professionnel de santé.',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      );
}
