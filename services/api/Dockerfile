# syntax=docker/dockerfile:1
# Contexte de build : RACINE du dépôt (l'API dépend de services/rules).
#   docker build -f services/api/Dockerfile .
FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:0.13.7 /uv /bin/uv
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/venv

# Le moteur de règles (dépendance de chemin ../rules) et ses jeux de règles.
COPY services/rules /src/services/rules

WORKDIR /src/services/api
# Dépendances d'abord (cache Docker), sans les outils de dev.
COPY services/api/pyproject.toml services/api/uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project --no-editable

COPY services/api/app ./app
COPY services/api/alembic.ini ./
COPY services/api/alembic ./alembic
# Calendrier CPN, contenus et informations de consentement : configuration versionnée.
COPY services/api/config ./config

# Chemins absolus dans l'image. Les jeux de règles de DÉMO ne sont chargés que si
# FANILO_ALLOW_DEMO_CONTENT=true (interdit en production) : sinon, fallback humain.
ENV FANILO_RULES_RULESET_PATH=/src/services/rules/rulesets/demo/reny_danger_signs.demo.yaml \
    FANILO_RULES_SIGN_CATALOG_PATH=/src/services/rules/rulesets/demo/sign_codes.demo.yaml \
    FANILO_ANC_SCHEDULE_PATH=/src/services/api/config/anc_schedule.demo.yaml \
    FANILO_CONSENT_INFORMATION_PATH=/src/services/api/config/consent_information.demo.yaml \
    PATH="/opt/venv/bin:$PATH"

RUN useradd --system --uid 10001 fanilo && chown -R fanilo /src
USER fanilo
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]
