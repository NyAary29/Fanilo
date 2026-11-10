# FANILO Femmes & Adolescentes

Application Flutter **anonyme** (sans compte, sans connexion) pour les femmes enceintes (module
**RENY**) et les adolescentes (module **TANORA**) à Madagascar. Elle suit le panneau « Application
Mobile – Femmes & Adolescentes » de la maquette de l'écosystème FANILO et est codée contre
`docs/api-publique.md` (préfixe `/public`).

> FANILO ne remplace pas un professionnel de santé. Il ne diagnostique pas, ne prescrit pas et ne
> promet aucune prise en charge (`docs/securite-medicale.md`). Cette mention est affichée sur chaque
> écran.

## Écrans

| Écran | Rôle |
|---|---|
| Accueil au premier lancement | « Tsy mila kaonty » (pas de compte), rien d'identifiant gardé, audio jamais conservé, conduite en cas d'urgence, résumés de `GET /public/information` (`reny`, `tanora`, `voice_processing`), choix MG/FR |
| Accord pour la voix | « Ekena / J'accepte » ou « Tsy izao / Pas maintenant ». Sans accord, le texte et les menus restent utilisables, le micro affiche un cadenas |
| « Aiza ianao no monina ? » | Choix facultatif d'un CSB (`GET /public/sites`), gardé seulement sur le téléphone, envoyé comme `site_id` pour orienter la question |
| Trano (accueil) | Logo, « Salama ! », gros bouton micro « Tsindrio ary miteny » (appui pour commencer, nouvel appui pour envoyer, 60 s au plus), cartes RENY (rose) et TANORA (menthe), champ « Soraty ny fanontanianao » |
| Réponse (transcription) | Question vocale : « Izao no reninay / Nous avons compris : » suivi de la transcription. Si `transcript` est nul : « Votre voix n'a pas pu être transcrite » et, s'il y a un `follow_up`, « Votre question est quand même transmise à un conseiller, la réponse sera dans Mes questions » (sinon : réessayer ou écrire). L'audio n'étant pas conservé par le serveur, l'application ne promet pas qu'un conseiller « écoutera » |
| Réponse | Bandeau DÉMO si `is_demo` ou contenu non validé ; **grand bloc rouge** « Mandehana any amin'ny tobim-pahasalamana akaiky indrindra » dès que `urgent = true`, quel que soit `outcome` (signe de danger reconnu ou seulement suspecté) ; contenu ; si `follow_up` : « Nalefa tany amin'ny mpanolotsaina », réponse à retrouver dans « Ny fanontaniako », aucun délai garanti ; avertissement |
| Fampahalalana | Menus par module (`GET /public/menus`), gros boutons numérotés, lecture du contenu et de `audio_url` s'il existe |
| Ny fanontaniako | Tickets gardés sur le téléphone ; état relu sur le serveur (`pending` / `answered`, réponse du conseiller). « Nohamarinina tamin'ny HH:mm / Vérifié à HH:mm » ; si le serveur ne répond pas : « Tsy afaka mifandray amin'ny serveur / Impossible de joindre le serveur » avec « Réessayer » (le dernier état connu reste affiché). Étiquette « Vaovao / Nouveau » sur les réponses reçues. « Fafao » (une question) et « Fafao daholo » (toutes) appellent `DELETE` puis effacent localement |
| Vonjy maika | Bouton toujours présent dans la barre du haut : consigne générique, CSB choisi s'il y en a un, « FANILO ne peut appeler personne », procédure locale **[À VALIDER]** (`lib/config/emergency.dart`, constante `kLocalEmergencyProcedure`) |
| Réglages | Langue, retrait ou don de l'accord pour la voix, changement ou effacement du CSB |

## Réception des réponses du conseiller

`lib/ui/ticket_status.dart` (`TicketStatusController`, `TicketStatusPoller`) relit l'état de toutes
les questions suivies :

- au démarrage de l'application ;
- au retour au premier plan (`AppLifecycleState.resumed`) ; rien n'est relu en arrière-plan ;
- à l'ouverture de « Ny fanontaniako » ;
- juste après l'envoi d'une question suivie par un conseiller ;
- toutes les 15 s tant que l'application est au premier plan (quel que soit l'onglet) ;
- en tirant la liste vers le bas, ou avec le bouton d'actualisation.

Quand une question passe à « répondu » : annonce « Nahazo valiny ianao / Vous avez une réponse »
(bouton « Jereo / Voir ») si la liste n'est pas déjà à l'écran, et pastille sur l'onglet avec le
nombre de **nouvelles** réponses. Ouvrir la liste les marque comme lues : seul l'identifiant
(`question_id`) des réponses lues est gardé, jamais la réponse.

## Modèle d'anonymat

- **Aucun compte, aucun jeton d'authentification, aucun nom ni numéro de téléphone.**
- Le téléphone ne garde que (`shared_preferences`, `lib/data/local/local_store.dart`) :
  - les **tickets** des questions suivies par un conseiller : `question_id`, `token`, `module` et date,
    **jamais** le texte de la question, la transcription ou la réponse (un téléphone est souvent
    partagé, en particulier par des adolescentes). La réponse du conseiller est relue sur le serveur
    à chaque affichage et ne reste qu'en mémoire ;
  - les identifiants des réponses déjà vues (pour la pastille « nouvelles réponses ») ;
  - l'accord pour la voix (version de l'information acceptée et date), la langue, le CSB choisi
    (identifiant et nom) et le fait que l'accueil a été vu.
- Pas de base de données ni de chiffrement local : rien d'identifiant ni de médical n'est stocké. Le
  jeton d'un ticket ne permet que de relire ou d'effacer la question correspondante. Les tests
  vérifient qu'aucune autre clé n'est écrite et que le texte des questions n'apparaît pas dans le
  stockage.
- L'audio est enregistré dans un fichier temporaire, lu, puis **effacé** avant même la réponse du
  serveur ; le serveur le transcrit en mémoire et ne le garde pas. Sans accord pour la voix, rien
  n'est enregistré ni envoyé (le client refuse aussi l'envoi audio sans `voice_consent`).
- Le champ texte est vidé après l'envoi.

## Démarrage

```bash
flutter pub get          # régénère aussi lib/l10n/gen (generate: true)
flutter analyze
flutter test             # unitaires et widgets, avec une fausse API (lib/data/api/fake_public_api.dart)
flutter build apk --debug
```

Versions vérifiées : Flutter 3.47.6 (Dart 3.13.5), Android Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0.

URL de l'API : `--dart-define=FANILO_API_URL=...`. Par défaut : `http://10.0.2.2:8000` sur Android
(émulateur) et `http://localhost:8000` ailleurs. Le HTTP en clair n'est autorisé que dans le
manifeste **debug**. `--dart-define=FANILO_FAKE_API=true` remplace l'API par la fausse API locale
(contenus FICTIFS marqués DÉMO, réponse fictive du conseiller après deux relectures) pour parcourir
les écrans sans serveur.

### Sur un téléphone Android relié en USB

```bash
adb reverse tcp:8000 tcp:8000      # le téléphone voit l'API du poste sur localhost:8000
flutter run -d R83L40RWDJY --dart-define=FANILO_API_URL=http://localhost:8000
```

Identifiant d'application : `mg.fanilo.femmes`, nom affiché « FANILO ». Le micro est demandé au
premier appui sur le bouton micro, après l'accord pour la voix et le choix du module, avec un message
d'explication.

### Sur Linux (poste de développement)

```bash
flutter run -d linux --dart-define=FANILO_API_URL=http://localhost:8000
```

L'enregistrement sur Linux passe par `parecord` (PulseAudio/PipeWire) et produit du WAV ; sur
Android, AAC dans un conteneur MP4 (`.m4a`, `audio/mp4`). Les deux types sont acceptés par l'API.
La lecture des `audio_url` utilise `just_audio`, qui n'a pas d'implémentation Linux : le bouton
« Henoy » affiche alors une erreur simple (aucun contenu de démonstration n'a d'audio aujourd'hui).

### Test de bout en bout contre l'API réelle (Linux)

```bash
# API démarrée sur :8000, données de démonstration chargées, FANILO_ALLOW_DEMO_CONTENT=true
flutter test integration_test -d linux --dart-define=FANILO_API_URL=http://localhost:8000
```

`integration_test/real_api_test.dart` vérifie les référentiels, le refus de l'audio sans
`voice_consent` (422 `consent_required`), puis pilote l'interface : question écrite TANORA → suivi
conseiller → « En attente » → retour à l'accueil → le compte de démonstration `responsable` répond
(`POST /interactions/{id}/review`) → la relecture périodique annonce « Vous avez une réponse » avec
la pastille → « Voir » → « Répondu » et la réponse ; question RENY « mandeha ra aho » : le bloc
d'urgence doit suivre la décision `urgent` du serveur (avertissement « ATTENTION (API) » dans la
sortie si le serveur ne la signale pas) ; question vocale (WAV de silence généré : transcription ou
message « non transcrite ») ; « Tout effacer » puis vérification du 404 côté serveur. Il crée et efface des questions **fictives**. Compte modifiable avec
`--dart-define=FANILO_E2E_REVIEWER=...` et `FANILO_E2E_PASSWORD=...`. Attention à la limite de
30 questions par heure et par adresse IP (`FANILO_PUBLIC_ASK_PER_HOUR`).

### Captures d'écran

```bash
flutter test test/screenshots \
  --dart-define=FANILO_SHOTS_DIR=/chemin/sortie \
  --dart-define=FANILO_FONTS_DIR=$FLUTTER_ROOT/bin/cache/artifacts/material_fonts
```

Rendu avec la fausse API, en polices Roboto et Material Icons du SDK (20 écrans, malgache et
français, dont annonce de réponse, serveur injoignable, transcription et voix non transcrite).

## Langues

Malagasy d'abord (langue par défaut), français ensuite : `lib/l10n/app_mg.arb` et
`lib/l10n/app_fr.arb` (modèle). Le malgache n'étant pas une locale Material/Cupertino, des délégués de
repli chargent les libellés système en français (`lib/ui/app.dart`).

> **Les textes malgaches n'ont pas été relus : ils sont à relire par des locuteurs natifs** avant
> toute diffusion (rappel dans `app_mg.arb`, clé `@@x-review`, et dans les réglages de
> l'application). Les contenus servis par l'API (titres, corps, informations) restent ceux du
> serveur ; s'il n'existe pas de version malgache, le français est affiché.

## Architecture

```
lib/
  config/        AppConfig (URL, fausse API), emergency.dart (procédure locale [À VALIDER])
  data/
    api/         models.dart, public_api.dart (PublicApi, HttpPublicApi, ApiException),
                 fake_public_api.dart (tests et démonstration)
    audio/       voice.dart : VoiceRecorder (record), AudioPlayback (just_audio)
    local/       local_store.dart : tickets, accord voix, CSB, langue
  l10n/          ARB mg et fr, gen/ (généré)
  ui/            app (thème, langues, repli Material), providers (Riverpod), ask_flow,
                 ticket_status (relecture des réponses, pastille, annonce),
                 theme.dart et widgets/logo.dart copiés de apps/mobile, widgets/common.dart
                 (bandeau DÉMO, bloc d'urgence, bouton « Vonjy maika », avertissement),
                 widgets/consent.dart, screens/
```

| Paquet | Rôle |
|---|---|
| flutter_riverpod 2.6 | État et injection |
| http, http_parser | Client de l'API publique (JSON et multipart) |
| shared_preferences | Tickets, accord, CSB, langue |
| record 7 | Enregistrement (Android, Linux) |
| just_audio | Lecture des `audio_url` (Android) |
| path_provider | Fichier audio temporaire (effacé aussitôt) |

## Limites

- Pas de mode hors ligne : sans réseau, la question n'est pas envoyée (message « Pas de connexion »)
  et rien n'est mis en file d'attente, pour ne pas garder le texte sur le téléphone.
- Une utilisatrice anonyme ne peut pas être rappelée : aucune alerte n'est créée, la conduite en cas
  d'urgence est toujours affichée. La procédure locale réelle reste **[À VALIDER]**.
- Les réponses ne sont relues que quand l'application est ouverte au premier plan : pas de
  notification système (elle exigerait un service de notification et un identifiant d'appareil).
- Si le téléphone est perdu ou réinitialisé, les tickets (et donc l'accès aux réponses) sont perdus.
  Une personne qui a accès au téléphone peut lire la réponse du conseiller via « Ny fanontaniako » :
  elle peut l'effacer à tout moment (« Fafao »).
- L'interface n'est pas encore lue à voix haute (pas de synthèse vocale) : seuls les `audio_url`
  publiés sont lus.
- Malgache non relu (voir plus haut). Contenus de démonstration non validés cliniquement.
