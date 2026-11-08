# FANILO mobile : application de l'agent communautaire

Application Flutter **offline-first** (exigence F-10, P0) destinée aux agents communautaires (AC) :
enregistrement avec consentement, suivi de grossesse et des CPN, références, alertes en lecture et
signalement de signes. Elle est codée contre `docs/api-contrat.md` (sections 1, 3, 4, 6, 7 et 8).

> FANILO ne remplace pas un professionnel de santé. Cette mention reste affichée en pied de chaque écran.

## Démarrage

```bash
flutter pub get                       # régénère aussi lib/l10n/gen (generate: true)
dart run build_runner build           # régénère lib/data/local/database.g.dart (drift)
flutter analyze
flutter test
flutter run --dart-define=FANILO_API_URL=http://10.0.2.2:8000
```

Sans `FANILO_API_URL`, l'URL par défaut est `http://10.0.2.2:8000` (API locale vue depuis l'émulateur
Android). Le HTTP en clair n'est autorisé que dans le manifeste `debug`. En mode debug, le menu de
l'accueil propose de charger des **données de démonstration fictives**, ce qui permet de parcourir les
écrans sans backend.

Versions : Flutter 3.29.3 et Dart 3.7.2. `minSdk` Android 23 (pour `flutter_secure_storage` et SQLCipher).

## Paquets

| Paquet | Version | Rôle |
|---|---|---|
| flutter_riverpod | 2.6.1 | État et injection de dépendances |
| drift / drift_dev | 2.31.0 | SQLite typé, requêtes réactives, génération de code |
| sqlcipher_flutter_libs | 0.6.8 | SQLCipher natif (Android et iOS) |
| sqlite3 | 2.9.4 | Liaison FFI (`open.overrideFor`) |
| flutter_secure_storage | 10.3.4 | Jetons et clé de base (Keystore et Keychain) |
| connectivity_plus | 7.3.1 | Détection du retour du réseau |
| http | 1.6.0 | Client HTTP |
| uuid | 4.6.0 | UUID v4 côté client (`id`, `change_id`, `device_id`) |
| path_provider, path, intl | 2.1.5, 1.9.1, 0.19.0 | Fichiers et l10n |
| build_runner (dev) | 2.15.0 | Génération drift |

## Architecture

```
lib/
  config/        AppConfig (URL de l'API via --dart-define)
  domain/        modèles et règles pures, sans Flutter ni base de données
                 enums (valeurs du contrat), referral_rules (transitions),
                 registration (consentement obligatoire), sign_catalog (DÉMO)
  data/
    api/         dto, ApiTransport, HttpAuthApi, HttpFaniloApi
                 interfaces AuthApi, SyncApi, InteractionApi
    auth/        AuthRepository (session, refresh, usage hors ligne)
    local/       tables drift, AppDatabase, EntityStore (JSON ↔ lignes), connexion chiffrée
    repositories/OutboxRepository, LocalRepository (écritures métier et outbox, en transaction)
    sync/        SyncService (push et pull), SyncScheduler (réseau et minuterie)
    secure/      SecureStore (abstraction de flutter_secure_storage)
    demo/        DemoSeeder (données fictives, debug uniquement)
  ui/            providers.dart (graphe Riverpod), app.dart (thème, AuthGate), screens/, widgets/
  l10n/          app_fr.arb (source des chaînes) et gen/ (généré)
```

**Choix de Riverpod plutôt que Provider.** Le graphe de dépendances se déclare hors de l'arbre de
widgets : la base, le stockage sécurisé, l'API et le réseau sont des feuilles que `main.dart` et les
tests remplacent avec `overrideWithValue`, sans `BuildContext`. Les `StreamProvider` se branchent
directement sur les requêtes réactives de drift, si bien que l'interface se met à jour seule après une
écriture locale ou une synchronisation. Le code reste sans génération (pas de `riverpod_generator`)
pour rester simple. Les services (`SyncService`, `AuthRepository`, les dépôts) sont des classes Dart
ordinaires, testables sans Flutter.

**Interface.** Les écrans sont en français. Toutes les chaînes viennent de `lib/l10n/app_fr.arb` :
pour ajouter le malgache, il suffit de créer `app_mg.arb`. Malgache n'étant pas une locale Material,
il faudra alors fournir un délégué Material de repli, par exemple vers le français. L'interface utilise
de grosses cibles tactiles (boutons de 56 px minimum), des messages courts et des icônes.

## Base locale

Les tables miroir (`beneficiaries`, `beneficiary_identities`, `consents`, `pregnancies`, `anc_visits`,
`referrals`, `alerts`) portent toutes `version` (dernière version serveur connue, 0 si l'entité n'a
jamais été synchronisée) et `deleted_at` (suppression logique). Les dates sont stockées en texte, telles
qu'échangées avec l'API, pour éviter toute conversion de fuseau horaire.

Tables techniques :

- `outbox` : `change_id` (UUID v4, clé primaire), `entity`, `op`, `id`, `base_version`, `data` (JSON),
  `status` (`pending` ou `rejected`), `attempts`, `last_error`, `seq` (ordre de saisie),
  `next_attempt_at` (backoff) ;
- `sync_conflicts` : modifications locales écartées lors d'un conflit, conservées pour revue ;
- `sync_state` : curseur de pull, `device_id`, date et erreur de la dernière synchronisation.

Chaque écriture métier (enregistrement, retrait de consentement, déclaration de grossesse, CPN réalisée
ou manquée, transition de référence) met à jour la table miroir **et** ajoute l'entrée d'outbox dans la
même transaction.

## Synchronisation (`SyncService`)

1. **Push** de l'outbox par lots de 50, dans l'ordre de saisie, avec **une seule entrée par entité et
   par lot**. Ainsi, une seconde modification de la même entité part avec la bonne `base_version`.
   - `applied` : l'entrée est retirée, la version locale prend la valeur `server_version`, et les
     entrées suivantes de la même entité sont rebasées sur cette version. Si `server_data` est fourni,
     il est appliqué, ce qui permet par exemple de récupérer le `code` FAN-XXXXXX.
   - `conflict` : `server_data` s'applique en local (la version serveur l'emporte, comme le prévoit le
     contrat par défaut) et la modification locale est copiée dans `sync_conflicts`. L'écran
     « Conflits » propose alors deux choix : « Garder le serveur » ou « Renvoyer ma version », qui crée
     une nouvelle entrée basée sur `server_version`.
   - `rejected` : l'entrée reste dans l'outbox avec le statut `rejected` et le message d'erreur, qui
     s'affiche sur l'accueil et dans l'écran « Conflits ». L'utilisateur peut la réessayer, ce qui lui
     attribue un **nouveau** `change_id` puisque le serveur mémorise le refus, ou l'abandonner.
   - Erreur réseau, réponse 5xx ou résultat absent : l'entrée reste en attente, `attempts` augmente de
     1 et `next_attempt_at` suit un backoff exponentiel (5 s × 2ⁿ⁻¹, plafonné à 30 min).
2. **Pull** depuis le curseur, page par page. Les données et le nouveau curseur sont écrits dans la
   **même transaction**. Une entité qui a une modification locale en attente n'est pas écrasée : le push
   suivant la réconciliera, par un conflit si nécessaire. Les entités inconnues sont ignorées.

**Idempotence.** Une entrée déjà envoyée n'est **jamais modifiée** : si la réponse s'est perdue, le
serveur a pu appliquer le changement, et il renverra le même résultat pour ce `change_id`. Une
modification ultérieure crée donc une nouvelle entrée. Seule une entrée jamais envoyée
(`attempts == 0`) peut être fusionnée. Le retrait de l'outbox est idempotent.

**Déclenchement.** La synchronisation se lance :

- avec le bouton « Synchroniser », qui ignore le backoff ;
- au retour du réseau (`connectivity_plus`), en ignorant aussi le backoff ;
- toutes les 5 minutes tant que l'accueil est ouvert, en respectant le backoff ;
- après chaque saisie.

Les appels concurrents partagent une seule exécution.

## Authentification

Le login appelle `/auth/login` puis `/auth/me`. Les jetons et le profil sont stockés dans
`flutter_secure_storage`. Le jeton d'accès est rafraîchi de façon proactive (60 s avant son
expiration) et réactive (après un 401, avec un seul nouvel essai). Un seul refresh peut être en cours à
la fois, car le serveur fait tourner les refresh tokens.

**Hors ligne.** Au démarrage, la session est restaurée depuis le stockage sécurisé sans aucun appel
réseau. Si le refresh token est refusé, l'utilisateur **n'est pas déconnecté** : un bandeau
« Reconnectez-vous pour synchroniser » apparaît et les données locales restent utilisables. La
reconnexion avec un autre compte est refusée. La déconnexion volontaire efface la base locale, après un
avertissement s'il reste des modifications non envoyées.

## Chiffrement

- La clé fait 256 bits, est tirée avec `Random.secure()` au premier lancement et n'est stockée que dans
  `flutter_secure_storage` (Keystore Android, Keychain iOS en mode `first_unlock_this_device`).
- La base `fanilo.sqlite` s'ouvre dans un isolat d'arrière-plan. Sur Android, la bibliothèque SQLite est
  remplacée par SQLCipher (`open.overrideFor(..., openCipherOnAndroid)`). La clé est ensuite appliquée
  par `PRAGMA key = "x'…'"` (clé brute, sans dérivation).
- **Garde-fou** : avant d'appliquer la clé, `PRAGMA cipher_version` est vérifié. Si la bibliothèque
  chargée n'est pas SQLCipher, l'ouverture est **refusée** et un écran d'erreur s'affiche. L'application
  ne bascule jamais vers une base non chiffrée.
- `android:allowBackup="false"` : la base ne serait de toute façon pas lisible sans la clé, qui reste
  dans le Keystore.

**Ce qui est vérifié par les tests** (`test/data/auth_and_crypto_test.dart`) :

- génération, persistance et remplacement d'une clé corrompue ;
- refus d'une clé mal formée ;
- refus d'ouvrir la base quand la bibliothèque n'est pas SQLCipher (testé avec le SQLite système de la
  machine de test).

**Ce qui n'est PAS vérifié** :

- l'ouverture réelle par SQLCipher sur un appareil Android ou iOS ;
- le fait que le fichier soit illisible sans la clé ;
- le comportement de `flutter_secure_storage` sur appareil (perte de la clé après une réinitialisation
  du Keystore, par exemple, qui rendrait la base illisible).

Les tests de logique utilisent une base drift **en mémoire non chiffrée** (`NativeDatabase.memory()`).
Sur appareil, il faut vérifier au minimum : le premier lancement, un redémarrage (la clé est relue), la
copie du fichier `fanilo.sqlite` puis sa lecture avec `sqlite3`, qui doit échouer avec « file is not a
database », et le lancement sur Android 7 (contournement
`applyWorkaroundToOpenSqlCipherOnOldAndroidVersions`).

## Sécurité médicale

- **Signaler des signes** : le formulaire n'est fait que de cases à cocher de codes. Un bandeau
  « DÉMO » reste affiché tant que le référentiel n'est pas `validated`, et la liste actuelle est une
  copie fictive de `services/rules/rulesets/demo/sign_codes.demo.yaml`. L'envoi part vers
  `POST /interactions/ask` en JSON (`module`, `beneficiary_id?`, `sign_codes`), **uniquement en ligne**.
  Hors ligne, rien n'est mis en file d'attente et un message demande de contacter directement le CSB
  selon la procédure locale. L'écran n'affiche que les orientations (`actions`), le contenu renvoyé
  par le serveur, la mention de l'alerte (« en attente d'accusé de réception », sans aucune promesse de
  prise en charge) et l'avertissement. Il n'affiche jamais de diagnostic ni de sévérité.
- Le calendrier CPN n'est **jamais** calculé dans l'application : il arrive du serveur après la
  déclaration de la grossesse. La date prévue d'accouchement n'est pas calculée non plus.
- Une grossesse ne peut être déclarée sans consentement RENY actif, ce qui reproduit localement la règle
  serveur qui répond 422.

## Tests

- `test/data/sync_service_test.dart` utilise un serveur factice fidèle au contrat (versions, conflits,
  idempotence, curseur). Il couvre `applied`, le rebasage, `conflict`, « Renvoyer ma version »,
  `rejected`, la nouvelle tentative, la réponse perdue (même `change_id`, aucune double application),
  le backoff, la concurrence, la pagination et le curseur, la suppression logique, l'absence
  d'écrasement d'une modification locale en attente, une donnée serveur malformée et le mode hors ligne.
- `test/data/outbox_test.dart` : UUID v4, ordre, fusion, absence de fusion après un envoi, alertes en
  lecture seule, abandon.
- `test/domain/registration_test.dart` : consentement obligatoire (rien n'est écrit sans lui), identité
  séparée, grossesse refusée sans consentement RENY.
- `test/domain/referral_rules_test.dart` : matrice complète des transitions et motif obligatoire.
- `test/data/auth_and_crypto_test.dart` : login, restauration hors ligne, refresh proactif et unique,
  refresh refusé, clé de chiffrement.
- `test/ui/widgets_test.dart` : enregistrement (l'identité reste inaccessible avant le consentement),
  signes hors ligne et en ligne, indicateur de l'accueil.

## Limites connues

- Les **sites** ne sont pas synchronisés : on ne peut pas encore créer une référence depuis le
  téléphone (`to_site_id` inconnu). Seules les transitions sont possibles.
- La **liste des signes** et les **versions de l'information** (`INFO-DEMO-0.1`) sont codées en dur et
  fictives : le contrat ne prévoit aucun endpoint pour les distribuer.
- « Abandonner » un envoi refusé laisse la donnée locale telle quelle jusqu'à la prochaine modification
  serveur de l'entité. Il n'y a pas encore de remise à zéro du curseur ni de rechargement ciblé.
- Un lot rejeté en bloc par le serveur (422 sur tout le `push`) est traité comme une erreur transitoire,
  avec backoff, et peut donc bloquer l'outbox. Le message apparaît dans `last_error`.
- Le statut « en ligne » repose sur `connectivity_plus`, qui ne garantit pas l'accès à l'API (portail
  captif, forfait épuisé). Les erreurs sont gérées par la synchronisation.
- Aucun build APK ou IPA n'a été produit ni testé. L'application n'a été vérifiée qu'avec
  `flutter analyze` et `flutter test`.
- Les fichiers générés (`*.g.dart`, `lib/l10n/gen/`) sont présents dans le dépôt. Après une modification
  des tables, relancer `build_runner`.
