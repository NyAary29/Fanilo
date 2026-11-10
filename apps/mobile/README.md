# FANILO mobile : application de l'agent communautaire

Application Flutter **offline-first** (exigence F-10, P0) destinée aux agents communautaires (AC) :
enregistrement avec consentement, suivi de grossesse et des CPN, références, alertes en lecture et
signalement de signes. Elle est codée contre `docs/api-contrat.md` (sections 1, 3, 4, 6, 7 et 8).

> FANILO ne remplace pas un professionnel de santé. Cette mention reste affichée en pied de chaque écran.

## Démarrage

```bash
flutter pub get                       # régénère aussi lib/l10n/gen (generate: true)
dart run build_runner build --delete-conflicting-outputs   # lib/data/local/database.g.dart (drift)
flutter analyze
flutter test                          # tests unitaires et widgets (sans backend)
```

Versions vérifiées : Flutter 3.47.6 (Dart 3.13.5). `intl` est en 0.20 (imposé par
`flutter_localizations`). Côté Android : Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, Java 17 (alignés sur
le modèle de Flutter 3.47), `minSdk = flutter.minSdkVersion` (24, il faut au moins 23 pour
`flutter_secure_storage` et SQLCipher).

URL de l'API : `--dart-define=FANILO_API_URL=...`. Sans cette option, l'application vise
`http://10.0.2.2:8000` sur Android (API locale vue depuis l'émulateur) et `http://localhost:8000`
ailleurs (Linux). Le HTTP en clair n'est autorisé que dans le manifeste `debug`. En mode debug, le menu
de l'accueil propose de charger des **données de démonstration fictives** (dont un site et des
référentiels marqués DÉMO), ce qui permet de parcourir les écrans sans backend.

### Lancer sur Linux (poste de développement) contre l'API locale

La cible Linux sert au développement et aux tests de bout en bout. Elle utilise la **vraie** base
chiffrée : `sqlcipher_flutter_libs` compile SQLCipher (`libsqlcipher_flutter_libs_plugin.so`, chargée
par `open.overrideFor(OperatingSystem.linux, ...)`) et la clé est rangée par `flutter_secure_storage`
dans le trousseau du bureau (libsecret, Secret Service de GNOME Keyring). Il n'y a **aucun** mode non
chiffré, même en debug.

Paquets système nécessaires à la compilation (en plus de la chaîne Flutter Linux : clang, cmake,
ninja, GTK 3) :

```bash
sudo apt install libssl-dev libsecret-1-dev
```

- `libssl-dev` : en-têtes OpenSSL pour compiler SQLCipher. `linux/CMakeLists.txt` force
  `OPENSSL_USE_STATIC_LIBS OFF` : SQLCipher est lié à la `libcrypto.so.3` du système, car la liaison
  statique par défaut échoue sur Ubuntu récent (`libcrypto.a` exige `libjitterentropy.a` et `libzstd`).
- `libsecret-1-dev` : en-têtes de libsecret pour `flutter_secure_storage_linux`.
- La première compilation télécharge l'amalgamation SQLCipher (`sqlcipher_flutter_libs`).

Sans droits root, on peut extraire ces deux paquets (`apt-get download`, puis `dpkg-deb -x` dans un
dossier) et exporter `PKG_CONFIG_PATH`, `OPENSSL_ROOT_DIR`, `CFLAGS`, `CXXFLAGS` et `LDFLAGS` vers ce
dossier (c'est ce qui a servi à la vérification ci-dessous). Effacer alors `build/linux` avant la
première compilation, car CMake garde ces variables en cache.

```bash
flutter run -d linux --dart-define=FANILO_API_URL=http://localhost:8000
```

La base est créée dans `~/.local/share/mg.fanilo.fanilo_mobile/fanilo.sqlite` (illisible par
`sqlite3` : « file is not a database »). Pour repartir de zéro : se déconnecter dans l'application,
ou supprimer ce fichier **et** l'entrée `fanilo.db_key.v1` du trousseau.

### Test de bout en bout (Linux, API réelle)

```bash
# API démarrée sur :8000, données de démo chargées, FANILO_ALLOW_DEMO_CONTENT=true
flutter test integration_test -d linux --dart-define=FANILO_API_URL=http://localhost:8000
```

`integration_test/e2e_test.dart` ouvre une base SQLCipher réelle dans un dossier temporaire (le
trousseau n'est pas utilisé : clé en mémoire), puis pilote l'interface avec le compte `ac.a1`.
Il crée des données **fictives** sur le serveur local (une bénéficiaire « Personne fictive E2E … », sa
grossesse, une référence et une alerte de démonstration). Identifiants modifiables avec
`--dart-define=FANILO_E2E_LOGIN=...` et `FANILO_E2E_PASSWORD=...`.

### Lancer sur l'émulateur Android

```bash
flutter build apk --debug             # vérifié : compile, libsqlcipher.so embarquée (arm64, armv7, x86_64)
flutter emulators --launch <avd>      # nécessite une image système installée dans le SDK
flutter run -d emulator-5554 --dart-define=FANILO_API_URL=http://10.0.2.2:8000
```

`10.0.2.2` est l'adresse de la machine hôte vue depuis l'émulateur : l'API doit écouter sur
`0.0.0.0:8000` ou `localhost:8000` de l'hôte.

## Paquets

| Paquet | Version | Rôle |
|---|---|---|
| flutter_riverpod | 2.6.1 | État et injection de dépendances |
| drift / drift_dev | 2.31.0 | SQLite typé, requêtes réactives, génération de code |
| sqlcipher_flutter_libs | 0.6.8 | SQLCipher natif (Android, iOS, Linux) |
| sqlite3 | 2.9.4 | Liaison FFI (`open.overrideFor`) |
| flutter_secure_storage | 10.3.4 | Jetons et clé de base (Keystore et Keychain) |
| connectivity_plus | 7.3.2 | Détection du retour du réseau |
| http | 1.6.0 | Client HTTP |
| uuid | 4.6.0 | UUID v4 côté client (`id`, `change_id`, `device_id`) |
| path_provider, path, intl | 2.1.6, 1.9.1, 0.20.3 | Fichiers et l10n |
| build_runner (dev) | 2.15.1 | Génération drift |
| integration_test (dev) | SDK | Test de bout en bout contre l'API réelle |

## Architecture

```
lib/
  config/        AppConfig (URL de l'API via --dart-define)
  domain/        modèles et règles pures, sans Flutter ni base de données
                 enums (valeurs du contrat), referral_rules (transitions),
                 registration (consentement obligatoire), reference_data (référentiels
                 servis par l'API : codes de signes, information de consentement, contenus
                 publiés), follow_up (« À jour » / « À suivre », affichage seulement)
  data/
    api/         dto, ApiTransport, HttpAuthApi, HttpFaniloApi
                 interfaces AuthApi, SyncApi, InteractionApi, ReferenceApi
    auth/        AuthRepository (session, refresh, usage hors ligne)
    local/       tables drift, AppDatabase, EntityStore (JSON ↔ lignes), connexion chiffrée
    repositories/OutboxRepository, LocalRepository (écritures métier et outbox, en transaction)
    reference/   ReferenceRepository (référentiels : API puis copie locale)
    sync/        SyncService (push et pull), SyncScheduler (réseau et minuterie)
    secure/      SecureStore (abstraction de flutter_secure_storage)
    demo/        DemoSeeder (données fictives, debug uniquement)
  ui/            providers.dart (graphe Riverpod), patient_overview.dart (vue d'ensemble d'une
                 patiente), theme.dart (palette), app.dart (AuthGate), screens/, widgets/
  l10n/          app_fr.arb (source des chaînes) et gen/ (généré)
integration_test/ e2e_test.dart (API réelle, SQLCipher réel, cible Linux)
linux/           projet de bureau (développement et tests de bout en bout)
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
de grosses cibles tactiles (boutons de 56 px minimum), des messages courts et une icône à côté de
chaque libellé. Voir « Interface de l'agent » ci-dessous.

## Interface de l'agent (refonte de novembre 2026)

Elle suit la maquette « Application Agent – Suivi Terrain » de l'écosystème FANILO : vert forêt
(`#1F5E3F`), fonds crème et menthe, rouge doux pour les alertes, orange pour « À suivre », cartes
arrondies (16 px) à ombre douce. Palette et thème : `lib/ui/theme.dart`. Le logo (silhouette, feuilles
et arc de soleil) est dessiné en vecteurs (`lib/ui/widgets/logo.dart`), sans image embarquée. Pas de
police embarquée : celle du système (Roboto sur Android), en graisses fortes.

Écran principal (`HomeScreen`) : trois onglets en bas, **Accueil · Mes visites · Alerter**, et la mention
« FANILO ne remplace pas un professionnel de santé. » au-dessus de la barre.

- **Accueil** : salutation, carte de synchronisation (« Données à jour · Dernière synchro : 08:30 », ou
  nombre de modifications en attente, refus, erreurs, bouton « Synchroniser »), deux grandes actions
  (« Nouvelle patiente », « Visite du jour »), raccourcis (Alertes, Références, Conflits), puis
  « Mes patientes » avec recherche, initiales, mois de grossesse et pastille **À jour** (vert) ou
  **À suivre** (orange).
- **Mes visites** : patientes « À suivre » d'abord, puis celles dont une CPN arrive dans les 7 jours,
  avec « Commencer la visite ».
- **Alerter** : signalement de signes (cases à cocher larges, message hors ligne très visible).

Fiche patiente : en-tête (initiales, nom, âge, site, code), bandeau « Alerte importante … En attente
d'accusé de réception » avec « Voir l'alerte », boutons « Visite du jour » et « Alerter », puis les
onglets **Suivi** (prochain rappel « CPN 4 : dans 7 jours (12 nov. 2026) », grossesse et calendrier CPN,
référence), **Alertes** (lecture seule) et **Historique** (consentements, références).

**« À jour » / « À suivre »** (`lib/domain/follow_up.dart`, règles d'affichage seulement) : « À suivre »
si une alerte attend un accusé de réception (`open` ou `escalated`), si une CPN prévue a une date
passée, ou si une CPN est manquée sans CPN réalisée après elle. Les dates viennent toujours du serveur ;
l'application ne fait que les comparer à la date du jour.

**Mois de grossesse** (« Grossesse · 3 mois ») : approximation pour l'affichage (jours écoulés depuis
la date des dernières règles **saisie par l'AC**, divisés par 30,4). Rien n'est affiché sans cette date
ou si elle est incohérente. Ce nombre ne sert à aucune date, aucun calendrier ni aucune décision.

### Visite du jour (`visit_flow_screen.dart`)

Liste guidée pour une patiente, en quatre étapes :

1. **Enregistrement de la visite** : « J'ai vu la patiente. Elle est d'accord pour la visite. » Sans
   consentement RENY actif, rien ne peut être saisi (les étapes 2 à 4 restent verrouillées).
2. **Signes de danger ?** « Oui » ouvre le signalement (mêmes règles : en ligne uniquement, aucun envoi
   différé, aucune sévérité) ; « Non » passe à la suite.
3. **Conseils donnés** : contenus publiés par le serveur (`GET /contents/published?module=reny`, module
   `common` inclus, français de préférence), copie locale pour le hors-ligne, bandeau DÉMO si un
   contenu n'est pas `validated`. Sans copie, l'étape est facultative.
4. **Planification du prochain RDV** : CPN fournies par le serveur. Une CPN due (en retard ou du jour)
   peut être marquée réalisée ou manquée, par l'outbox comme sur la fiche. La prochaine CPN s'affiche en
   « Prochain rappel ». Aucune date n'est calculée.

En bas : « Enregistrer la visite » (exige les étapes 1 et 2) et « Alerter le CSB si nécessaire »
(toujours actif, ouvre le signalement).

**Limite assumée** : le contrat d'API n'a **pas** d'entité « visite à domicile ». Les étapes 1 à 3 sont
donc une **liste de contrôle locale**, ni enregistrée ni envoyée au serveur (l'écran l'indique).
« Enregistrer la visite » ferme la liste et lance une synchronisation. Seuls partent au serveur les CPN
marquées (outbox) et un éventuel signalement (`/interactions/ask`). Aucun endpoint n'a été ajouté.

Les contenus publiés sont rafraîchis après chaque synchronisation (au plus une fois par heure, ou à
chaque synchronisation manuelle) et à l'ouverture d'une visite s'il y a du réseau, dans
`reference_cache` (clé `contents:reny`). Ce rafraîchissement est séparé de celui des référentiels de
sécurité : son échec n'a aucun effet.

### Captures d'écran

```bash
flutter test test/screenshots \
  --dart-define=FANILO_SHOTS_DIR=/tmp/fanilo-shots \
  --dart-define=FANILO_FONTS_DIR=$FLUTTER_ROOT/bin/cache/artifacts/material_fonts
```

Les données sont fictives. Sans ces options, le test est ignoré.

## Base locale

Les tables miroir (`beneficiaries`, `beneficiary_identities`, `consents`, `pregnancies`, `anc_visits`,
`referrals`, `alerts`) portent toutes `version` (dernière version serveur connue, 0 si l'entité n'a
jamais été synchronisée) et `deleted_at` (suppression logique). Les dates sont stockées en texte, telles
qu'échangées avec l'API, pour éviter toute conversion de fuseau horaire.

Table en lecture seule : `sites` (pull uniquement, sert au choix du site destinataire d'une
référence hors ligne).

Tables techniques :

- `outbox` : `change_id` (UUID v4, clé primaire), `entity`, `op`, `id`, `base_version`, `data` (JSON),
  `status` (`pending` ou `rejected`), `attempts`, `last_error`, `seq` (ordre de saisie),
  `next_attempt_at` (backoff) ;
- `sync_conflicts` : modifications locales écartées lors d'un conflit, conservées pour revue ;
- `sync_state` : curseur de pull, `device_id`, date et erreur de la dernière synchronisation ;
- `reference_cache` : dernière copie reçue des référentiels (`sign-codes:<module>`,
  `consent-information`), en JSON brut, avec sa date.

Schéma en version 2. La migration 1 → 2 crée `sites` et `reference_cache` et **oublie le curseur** :
les anciennes versions ignoraient les sites, le pull suivant repart donc de zéro pour les recevoir
(sans écraser les modifications en attente).

Chaque écriture métier (enregistrement, retrait de consentement, déclaration de grossesse, CPN réalisée
ou manquée, création ou transition de référence) met à jour la table miroir **et** ajoute l'entrée d'outbox dans la
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
   - `rejected` : l'entrée reste dans l'outbox avec le statut `rejected` et le message d'erreur
     (`error.message (error.code)`), qui s'affiche sur l'accueil et dans l'écran « Conflits ».
     L'utilisateur peut la réessayer, ce qui lui attribue un **nouveau** `change_id` puisque le
     serveur mémorise le refus, ou l'abandonner. **Abandonner remet la donnée dans l'état du
     serveur** : si l'entité n'a jamais été confirmée (`version = 0`), la ligne locale est supprimée ;
     sinon le curseur est remis à zéro et une synchronisation est lancée, dont le pull complet
     remplace la donnée locale. Si d'autres modifications de la même entité restent dans l'outbox,
     elles la réconcilieront et rien d'autre n'est fait.
   - 422 sur tout le lot (enveloppe refusée) : conformément au contrat, le lot n'est pas renvoyé tel
     quel. Ses entrées passent en `rejected` avec le message du serveur.
   - Erreur réseau, réponse 5xx ou résultat absent : l'entrée reste en attente, `attempts` augmente de
     1 et `next_attempt_at` suit un backoff exponentiel (5 s × 2ⁿ⁻¹, plafonné à 30 min).
2. **Pull** depuis le curseur, page par page. Les données et le nouveau curseur sont écrits dans la
   **même transaction**. Une entité qui a une modification locale en attente n'est pas écrasée : le push
   suivant la réconciliera, par un conflit si nécessaire. Les entités inconnues sont ignorées. Les
   `site` sont enregistrés dans `sites` (lecture seule, comme `alert`).
3. **Référentiels** : après un pull réussi, `GET /reference/sign-codes?module=reny` et
   `GET /reference/consent-information` sont appelés (au plus une fois par heure, ou à chaque
   synchronisation manuelle) et la réponse remplace la copie locale. Hors ligne, en 503 (référentiel
   non servi) ou si la réponse est malformée, la copie précédente reste en vigueur. Les écrans
   « Signaler des signes » et « Enregistrement » les rafraîchissent aussi à l'ouverture s'il y a du
   réseau. Ces appels n'influencent pas le résultat de la synchronisation.

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
- La base `fanilo.sqlite` s'ouvre dans un isolat d'arrière-plan. La bibliothèque SQLite est remplacée
  par SQLCipher : `openCipherOnAndroid` sur Android, `libsqlcipher_flutter_libs_plugin.so` sur Linux
  (iOS : liaison statique). La clé est ensuite appliquée par `PRAGMA key = "x'…'"` (clé brute, sans
  dérivation).
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

**Ce qui a été vérifié pour de vrai sur Linux** (bureau, SQLCipher 4.10 compilé par le plugin) :

- ouverture par SQLCipher (`PRAGMA cipher_version` non vide) dans l'application et dans le test de
  bout en bout ;
- le fichier `fanilo.sqlite` n'a pas d'en-tête SQLite et `sqlite3` (Python) répond « file is not a
  database » ;
- relance de l'application : la clé est relue dans le trousseau (libsecret) et la base existante
  s'ouvre, migration 1 → 2 comprise.

**Ce qui n'est PAS vérifié** :

- l'ouverture réelle par SQLCipher sur un appareil ou un émulateur Android, ou sur iOS (l'APK debug
  compile et embarque `libsqlcipher.so`, mais n'a pas été lancé : aucune image d'émulateur installée) ;
- le comportement de `flutter_secure_storage` sur appareil (perte de la clé après une réinitialisation
  du Keystore, par exemple, qui rendrait la base illisible).

Les tests de logique (`flutter test`) utilisent une base drift **en mémoire non chiffrée**
(`NativeDatabase.memory()`) avec la `libsqlite3.so.0` du système.
Sur appareil, il faut vérifier au minimum : le premier lancement, un redémarrage (la clé est relue), la
copie du fichier `fanilo.sqlite` puis sa lecture avec `sqlite3`, qui doit échouer avec « file is not a
database », et le lancement sur Android 7 (contournement
`applyWorkaroundToOpenSqlCipherOnOldAndroidVersions`).

## Sécurité médicale

- **Signaler des signes** : le formulaire n'est fait que de cases à cocher de codes. La liste vient de
  `GET /reference/sign-codes` (copie locale hors ligne) ; **aucune liste n'est codée dans
  l'application** : sans copie, l'écran demande de synchroniser et rappelle de contacter le CSB. Un
  bandeau « DÉMO » reste affiché tant que le serveur renvoie `is_demo: true` ou un `status` autre que
  `validated`. L'envoi part vers
  `POST /interactions/ask` en JSON (`module`, `beneficiary_id?`, `sign_codes`), **uniquement en ligne**.
  Hors ligne, rien n'est mis en file d'attente et un message demande de contacter directement le CSB
  selon la procédure locale. L'écran n'affiche que les orientations (`actions`), le contenu renvoyé
  par le serveur, la mention de l'alerte (« en attente d'accusé de réception », sans aucune promesse de
  prise en charge) et l'avertissement. Il n'affiche jamais de diagnostic ni de sévérité.
- Le calendrier CPN n'est **jamais** calculé dans l'application : il arrive du serveur après la
  déclaration de la grossesse. La date prévue d'accouchement n'est pas calculée non plus. Le serveur
  ne génère le calendrier que si la date des dernières règles (ou le terme) est connue ; sinon la
  fiche l'indique. « Dates de la grossesse » (grossesse en cours) permet de renseigner ou corriger
  après coup les dernières règles, le terme prévu **saisi** par l'AC et la source des dates : upsert
  `pregnancy` par l'outbox. Si la grossesse n'a encore aucune visite, le serveur génère alors le
  calendrier, reçu au pull suivant. L'application applique seulement le même garde-fou de saisie que
  le serveur (dernières règles ni futures ni de plus de 320 jours, terme après les dernières règles).
- **Consentement** : pour chaque portée, l'écran affiche le résumé et la version servis par
  `GET /reference/consent-information` ; une portée sans information servie ne peut pas être cochée,
  et la version enregistrée dans `information_version` est celle de la portée. Bandeau DÉMO si une
  information n'est pas `validated`. Sans copie locale (jamais synchronisé), l'enregistrement est
  impossible.
- **Alertes** : l'application n'affiche jamais la sévérité. Elle affiche le statut (« Ouverte »,
  « Escaladée »…), « En attente d'accusé de réception » tant que personne ne l'a reçue, et les dates de
  signalement et d'accusé de réception. Elle n'affiche pas l'échéance interne (`due_at`), pour ne rien
  laisser entendre d'un délai de prise en charge.
- **Orientations** : libellés pour l'énumération fermée du contrat (`refer_csb`,
  `refer_reference_facility`, `refer_community_agent`, `transfer_counselor`).
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
- `test/data/reference_and_sites_test.dart` : pull des sites (forme réelle relevée sur l'API), sites en
  lecture seule, création de référence (outbox, `from_site_id`, site inconnu ou inactif refusé),
  référentiels (cache, hors ligne, 503, réponse malformée, délai minimal, bandeau DÉMO), contenus
  publiés (cache séparé, copie gardée en cas d'échec), abandon d'un
  refus (rechargement serveur, suppression locale, autre modification en attente), 422 sur le lot,
  format réel de `error` d'un refus.
- `test/data/migration_test.dart` : migration du schéma 1 → 2.
- `test/data/pregnancy_dates_test.dart` : dates renseignées après coup (upsert sur la version
  serveur, calendrier reçu au pull), fusion avec une création non envoyée, garde-fous de saisie,
  grossesse non active refusée.
- `test/domain/follow_up_test.dart` : « À jour » / « À suivre » (alerte, CPN en retard, CPN manquée puis
  rattrapée), CPN du jour, écart en jours, mois de grossesse (affichage), âge, initiales, sélection des
  contenus publiés (module, `common`, langue, statuts).
- `test/ui/visit_flow_test.dart` : pastilles et raisons sur l'accueil, recherche, onglet « Mes
  visites », visite complète (CPN en retard marquée réalisée par l'outbox, liste de contrôle non
  envoyée), visite sans consentement, « Oui » hors ligne (aucun envoi) et en ligne, fiche (bandeau
  d'alerte, onglets, prochain rappel), alertes sans sévérité.
- `test/screenshots/screens_test.dart` : captures (voir ci-dessus), ignoré par défaut.
- `test/ui/widgets_test.dart` : enregistrement (l'identité reste inaccessible avant le consentement,
  information servie affichée, version enregistrée), signes hors ligne et en ligne, absence de
  référentiel, nouvelle référence, saisie des dates d'une grossesse sans calendrier, indicateur de
  l'accueil.
- `integration_test/e2e_test.dart` : voir « Test de bout en bout ».

## Vérifié de bout en bout (9 novembre 2026, Linux, API locale réelle)

Avec `flutter test integration_test -d linux` (application réelle, SQLCipher réel, API PostgreSQL
locale, compte `ac.a1`) :

1. connexion (`/auth/login`, `/auth/me`) ;
2. synchronisation : 7 sites reçus par `/sync/pull`, référentiels mis en cache ;
3. enregistrement avec consentement oral RENY, information `demo-0.1` servie par l'API ; code
   `FAN-XXXXXX` reçu dans `server_data` ;
4. déclaration de grossesse **sans** date des dernières règles : acceptée, aucun calendrier, la fiche
   l'indique ; puis saisie de la date avec « Dates de la grossesse » et synchro : le serveur génère le
   calendrier, qui revient et s'affiche (« CPN 1 … ») ;
5. création d'une référence vers « CSB II Démo Bongolava A » : appliquée par le serveur (statut
   `proposed`, `from_site_id` = zone de l'AC) ;
6. signalement de `SIGN_DEMO_01` en ligne : orientation « structure de référence », mention
   « Alerte transmise », aucune sévérité affichée ; l'alerte (`DEMO-RENY-001`, `is_demo`) revient par
   la synchro ;
7. outbox vide à la fin ; fichier de base sans en-tête SQLite.

L'application elle-même (`build/linux/x64/debug/bundle/fanilo_mobile`, clé dans le trousseau) a aussi
été lancée deux fois : création de la base chiffrée, puis réouverture et migration.

## Limites connues

- **Android non lancé** : l'APK debug compile, mais aucune image système d'émulateur n'est installée
  dans le SDK ; ni l'ouverture SQLCipher ni `flutter_secure_storage` n'ont été vérifiées sur Android.
  iOS n'a pas été compilé.
- Les **sites** reçus sont tous ceux que le serveur renvoie dans `/sync/pull` (7 pour `ac.a1`, y
  compris hors de son district) ; l'écran propose les sites actifs, CSB d'abord, sauf le site de l'AC.
- Abandonner un refus sur une entité connue du serveur relance un **pull complet** (curseur remis à
  zéro). C'est simple et sûr, mais plus coûteux qu'un rechargement ciblé (le contrat n'a pas de pull
  par entité).
- Sans aucune copie des référentiels (premier lancement jamais synchronisé), l'enregistrement et le
  signalement de signes sont impossibles ; la connexion initiale, en ligne, les récupère.
- Le statut « en ligne » repose sur `connectivity_plus`, qui ne garantit pas l'accès à l'API (portail
  captif, forfait épuisé). Les erreurs sont gérées par la synchronisation.
- Le libellé malgache (`label_mg`, `summary_mg`) est reçu et conservé mais pas encore affiché
  (interface en français uniquement).
- Les fichiers générés (`*.g.dart`, `lib/l10n/gen/`) sont présents dans le dépôt. Après une modification
  des tables, relancer `build_runner`.
