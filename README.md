# FANILO

Assistant vocal de santé maternelle (**RENY**) et adolescente (**TANORA**) en malgache parlé, pour les femmes, les adolescentes, les agents communautaires (AC) et les centres de santé de base (CSB) à Madagascar.

> ⚠️ **FANILO ne pose aucun diagnostic, ne prescrit rien et ne remplace jamais un professionnel de santé.**
> Les contenus et règles de démonstration présents dans ce dépôt ne sont **pas validés cliniquement**. Voir [docs/securite-medicale.md](docs/securite-medicale.md).

Projet porté par Havanana Impact. Développement : Creatic. Statut : **pré-pilote, en développement**.

## Structure

```text
services/api/     Backend FastAPI (Python 3.12, PostgreSQL)
services/rules/   Moteur de règles médicales déterministe (sans IA)
docs/             Exigences, sécurité médicale, IA, architecture
apps/             (à venir) application Flutter AC, dashboard React
```

## Démarrage rapide (backend)

Prérequis : [uv](https://docs.astral.sh/uv/). Il installe lui-même Python 3.12.

```bash
cp .env.example .env            # puis adapter les valeurs
cd services/api
uv sync
uv run uvicorn app.main:app --reload
# http://localhost:8000/health  ·  http://localhost:8000/docs
```

### Avec Docker (développement)

```bash
cp .env.example .env
docker compose up --build
```

## Tests et qualité

```bash
cd services/api   && uv run pytest && uv run ruff check .
cd services/rules && uv run pytest && uv run ruff check .
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
- [Benchmark ASR malgache](docs/ia/benchmark-asr-malgache.md)

## Limites connues

- La reconnaissance vocale du malgache **n'a pas encore été évaluée** sur un corpus réel. Aucune performance n'est revendiquée.
- Aucun contenu médical validé n'est encore intégré.
- Licence open source à définir.
