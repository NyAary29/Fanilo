# Passer de la démonstration à de vrais utilisateurs

Deux étapes bien distinctes :

1. **Essai avec de vraies personnes, en local** (formation, test d'utilisabilité avec des AC,
   un CSB ou des volontaires) : possible dès maintenant, sans données de santé réelles.
2. **Pilote réel** (vraies patientes) : seulement après les validations du cahier des
   charges (§15, §18). Tant qu'elles manquent, FANILO **refuse** de démarrer en production.

## 1. Essai local avec de vraies personnes

1. **Repartir de zéro** (garde les comptes, les sites et les contenus) :
   ```bash
   cd services/api && set -a && . ../../.env && set +a
   uv run python -m app.modules.devseed --purge
   ```
2. **Créer les vrais sites** : dashboard → compte `admin` → « Sites ». Créer les CSB
   réellement concernés, puis leurs zones communautaires (rattachées au CSB).
3. **Créer un compte par personne** : « Utilisateurs » → identifiant personnel (ex.
   `rakoto.ac`), rôle, site, **mot de passe d'au moins 12 caractères** remis en main propre.
   Un compte par personne : l'audit trace qui fait quoi.
4. **Désactiver les comptes de démonstration** : « Utilisateurs » → désactiver `ac.a1`,
   `chef.csb.a`, etc. (garder seulement un `admin` personnel).
5. **Masquer les boutons de comptes démo** à la connexion :
   ```bash
   scripts/dev.sh stop && FANILO_SHOW_DEMO_ACCOUNTS=false FANILO_LAN=1 scripts/dev.sh start
   ```
   `FANILO_LAN=1` rend l'API et le dashboard joignables par les téléphones et postes du
   même Wi-Fi (à l'adresse IP du PC affichée au démarrage).
6. **Applications Android** : installer l'APK sur les téléphones avec l'adresse du PC :
   ```bash
   cd apps/mobile  && flutter build apk --debug --dart-define=FANILO_API_URL=http://<IP-du-PC>:8000
   cd apps/femmes  && flutter build apk --debug --dart-define=FANILO_API_URL=http://<IP-du-PC>:8000
   ```
   Fichiers produits : `build/app/outputs/flutter-apk/app-debug.apk` (à copier sur le
   téléphone, puis l'installer). Le mode debug est nécessaire tant que le serveur n'a pas
   de HTTPS.
7. **Prévenir les participantes** que tout est en mode **DÉMO** : messages fictifs, aucun
   avis médical, ne pas saisir de vraie information de santé.

## 2. Pilote réel : ce qui manque (hors code)

| À fournir | Par qui | Où cela se branche |
|---|---|---|
| Liste validée des signes de danger et règles d'orientation | Responsable clinique | `services/rules/rulesets/` (nouveau fichier `status: validated`) |
| Contenus validés **en malgache** (et audio) | Équipe contenus + responsable clinique | Dashboard → « Contenus » (brouillon → validation par un 2ᵉ responsable) |
| Calendrier CPN du Ministère | Responsable clinique | `services/api/config/anc_schedule*.yaml` |
| Textes de consentement et d'information (app agent et app femmes) | Juriste + responsable clinique | `consent_information*.yaml`, `public_information*.yaml` |
| Procédure d'urgence locale (numéros, centres) | DRSP / SDSP | `apps/femmes/lib/config/emergency.dart` |
| Relecture des textes malgaches de l'interface | Locuteurs natifs | `apps/*/lib/l10n/app_mg.arb` |
| Évaluation de la reconnaissance vocale sur de vraies voix | Équipe IA | `docs/ia/benchmark-asr-malgache.md` |
| Hébergement, HTTPS, sauvegardes, opérateur SMS/appels | Direction + technique | `docs/exploitation.md` §5 |

En production (`FANILO_ENVIRONMENT=production`), l'API refuse les fichiers `demo` : une
fois les validations obtenues, il suffit de pointer les variables `FANILO_*_PATH` vers les
fichiers validés.
