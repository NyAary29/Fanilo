# FANILO

Assistant vocal de santé maternelle (**RENY**) et adolescente (**TANORA**) en malgache parlé, pour les femmes, les adolescentes, les agents communautaires (AC) et les centres de santé de base (CSB) à Madagascar.

> ⚠️ **FANILO ne pose aucun diagnostic, ne prescrit rien et ne remplace jamais un professionnel de santé.**
> Les contenus et règles de démonstration présents dans ce dépôt ne sont **pas validés cliniquement**. Voir [docs/securite-medicale.md](docs/securite-medicale.md).

Projet porté par Havanana Impact. Développement : Creatic. Statut : **pré-pilote, en développement**.

## Structure

```text
services/api/     Backend FastAPI (Python 3.12, PostgreSQL)
services/rules/   Moteur de règles médicales déterministe (sans IA)
services/ai/      Transcription (interface ASR) et classification d'intentions, banc d'évaluation
apps/dashboard/   Interface web CSB, clinique et administration (React + TypeScript)
apps/mobile/      Application de l'agent communautaire (Flutter, hors connexion, SQLCipher)
apps/femmes/      Application anonyme « Femmes & Adolescentes » (Flutter, sans compte)
scripts/          Démarrage local, test de bout en bout, sauvegarde et restauration
docs/             Exigences, contrat d'API, sécurité médicale, IA, interopérabilité, exploitation
```

## Démarrage local (tout en une commande)

Prérequis : Docker (compose v2), [uv](https://docs.astral.sh/uv/), Node 22+ ; Flutter pour le mobile.

```bash
scripts/dev.sh start
```

Le script crée `.env` (secrets générés, mode démo), lance PostgreSQL, applique les
migrations, charge le jeu de démonstration, puis démarre le service IA, l'API, le
dashboard et les tâches planifiées (escalade des alertes, rappels).

- Dashboard : http://localhost:5174, API : http://localhost:8000 (`/docs`)
- Comptes de démo (mot de passe `fanilo-demo-2026`) : `admin`, `donnees`, `responsable`,
  `conseiller`, `chef.csb.a`, `ac.a1`… (liste complète dans [docs/exploitation.md](docs/exploitation.md))
- Mobile agent : `cd apps/mobile && flutter run --dart-define=FANILO_API_URL=http://localhost:8000`
- App femmes (sans compte) : `cd apps/femmes && flutter run --dart-define=FANILO_API_URL=http://localhost:8000` ; API publique décrite dans [docs/api-publique.md](docs/api-publique.md)
- Téléphone Android branché en USB : `adb reverse tcp:8000 tcp:8000` d'abord
- Vérification de bout en bout : `scripts/dev.sh smoke`. Arrêt : `scripts/dev.sh stop`.

Toutes les données et tous les contenus chargés sont **fictifs** et marqués « DÉMO ».

## Tests et qualité

```bash
cd services/api   && uv run pytest && uv run ruff check .
cd services/rules && uv run pytest && uv run ruff check .
cd services/ai    && uv run pytest && uv run ruff check .
cd apps/dashboard && npm test -- --run && npm run lint && npm run build
cd apps/mobile    && flutter analyze && flutter test
cd apps/femmes    && flutter analyze && flutter test
```

La CI GitHub Actions exécute ces mêmes commandes à chaque pull request.

## Configuration

Toute la configuration passe par des variables d'environnement préfixées `FANILO_` (voir [.env.example](.env.example)). En production (`FANILO_ENVIRONMENT=production`), l'API **refuse de démarrer** si :
- `FANILO_SECRET_KEY` est absent ou fait moins de 32 caractères ;
- `FANILO_ALLOW_DEMO_CONTENT=true` ;
- `FANILO_CORS_ORIGINS` contient `*`.

## Documentation

- [Matrice des exigences](docs/exigences.md) : correspondance entre le cahier des charges et les lots techniques
- [Sécurité médicale](docs/securite-medicale.md)
- [Contrat d'API](docs/api-contrat.md) et [architecture](docs/architecture.md)
- [Benchmark ASR malgache](docs/ia/benchmark-asr-malgache.md)
- [Interopérabilité (DHIS2/CommCare)](docs/interoperabilite.md)
- [Installation, exploitation, sauvegarde et reprise](docs/exploitation.md)

## Limites connues

- La reconnaissance vocale du malgache **n'a pas encore été évaluée** sur un corpus réel. Aucune performance n'est revendiquée.
- Aucun contenu médical validé n'est encore intégré : règles, signes, contenus, calendrier CPN,
  information de consentement et menus vocaux sont des fichiers de **démonstration**.
- Canaux IVR/SMS/USSD : simulés dans le dashboard (« Simulateur vocal ») ; aucune passerelle
  opérateur n'est branchée.
- Licence open source à définir.
