#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# FANILO — environnement LOCAL de développement / démonstration.
#
#   scripts/dev.sh start    # base, migrations, données de démo, IA, API, dashboard, tâches
#   scripts/dev.sh stop     # arrête les services (la base est conservée)
#   scripts/dev.sh status   # état des services
#   scripts/dev.sh logs [api|ai|dashboard|tasks]
#   scripts/dev.sh smoke    # test de bout en bout contre l'API locale
#   scripts/dev.sh reset    # SUPPRIME la base locale (données de démo comprises)
#
# Options (variables d'environnement) :
#   FANILO_LAN=1                   expose l'API et le dashboard sur le réseau local
#                                  (téléphone, autres postes sur le même Wi-Fi)
#   FANILO_SHOW_DEMO_ACCOUNTS=false  masque les boutons de comptes démo à la connexion
#   FANILO_AI_ASR_BACKEND=none     désactive la reconnaissance vocale (whisper par défaut, ou « ctc ») ;
#                                  télécharge torch + le modèle au premier lancement
#
# Prérequis : docker (compose v2), uv, node >= 22. Données FICTIVES uniquement :
# ne jamais utiliser ce script ni le .env généré en production.
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/.dev"
LOGS="$STATE/logs"
PIDS="$STATE/pids"
API_PORT="${FANILO_API_PORT:-8000}"
AI_PORT="${FANILO_AI_PORT:-8001}"
DASHBOARD_PORT="${FANILO_DASHBOARD_PORT:-5174}"
TASKS_INTERVAL="${FANILO_TASKS_INTERVAL:-60}"
export PATH="$HOME/.local/bin:$PATH"
LAN="${FANILO_LAN:-0}"
ASR_BACKEND="${FANILO_AI_ASR_BACKEND:-}"
BIND=127.0.0.1
PUBLIC_HOST=localhost
if [ "$LAN" = "1" ]; then
  BIND=0.0.0.0
  PUBLIC_HOST="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [ -n "$PUBLIC_HOST" ] || PUBLIC_HOST=localhost
fi
AI_EXTRA=()

mkdir -p "$LOGS" "$PIDS"
cd "$ROOT"

info() { printf '\033[1;36m▶ %s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

port_free() { ! (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

require() {
  command -v docker >/dev/null || die "docker introuvable."
  docker compose version >/dev/null 2>&1 || die "docker compose (v2) introuvable."
  command -v uv >/dev/null || die "uv introuvable : curl -LsSf https://astral.sh/uv/install.sh | sh"
  command -v node >/dev/null || die "node introuvable (>= 22 requis)."
  local major; major="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$major" -ge 22 ] || die "node >= 22 requis (trouvé : $(node -v))."
}

ensure_env() {
  if [ ! -f .env ]; then
    info "Création de .env (secrets générés, mode démo local)"
    local db_port=5432
    while ! port_free "$db_port"; do db_port=$((db_port + 1)); done
    local secret key
    secret="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
    key="$(cd services/api && uv run -q python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())')"
    sed -e "s|^FANILO_SECRET_KEY=.*|FANILO_SECRET_KEY=$secret|" \
        -e "s|^FANILO_DATA_ENCRYPTION_KEY=.*|FANILO_DATA_ENCRYPTION_KEY=$key|" \
        -e "s|^FANILO_ALLOW_DEMO_CONTENT=.*|FANILO_ALLOW_DEMO_CONTENT=true|" \
        -e "s|^FANILO_LOG_FORMAT=.*|FANILO_LOG_FORMAT=text|" \
        -e "s|^FANILO_CORS_ORIGINS=.*|FANILO_CORS_ORIGINS=http://localhost:$DASHBOARD_PORT,http://127.0.0.1:$DASHBOARD_PORT|" \
        -e "s|localhost:5432/fanilo|localhost:$db_port/fanilo|" \
        -e "s|^# FANILO_DB_PORT=.*|FANILO_DB_PORT=$db_port|" \
        .env.example > .env
    grep -q '^FANILO_DB_PORT=' .env || echo "FANILO_DB_PORT=$db_port" >> .env
  fi
  if [ ! -f apps/dashboard/.env.local ]; then
    printf 'VITE_API_URL=http://localhost:%s\nVITE_USE_MOCKS=false\n' "$API_PORT" > apps/dashboard/.env.local
  fi
  set -a; # shellcheck disable=SC1091
  . ./.env; set +a
}

running() { [ -f "$PIDS/$1" ] && kill -0 "$(cat "$PIDS/$1")" 2>/dev/null; }

launch() { # nom, dossier, commande...
  local name="$1" dir="$2"; shift 2
  if running "$name"; then ok "$name déjà démarré"; return; fi
  # exec : le PID enregistré est celui du service, chef de son propre groupe
  # (setsid), ce qui permet de l'arrêter avec tous ses processus enfants.
  (cd "$dir" && exec setsid nohup "$@" > "$LOGS/$name.log" 2>&1 < /dev/null) &
  echo $! > "$PIDS/$name"
}

wait_http() { # url, nom, [secondes]
  for _ in $(seq 1 "${3:-60}"); do
    curl -fsS -o /dev/null "$1" 2>/dev/null && { ok "$2 prêt : $1"; return; }
    sleep 1
  done
  die "$2 ne répond pas ($1) — voir $LOGS"
}

start() {
  require
  ensure_env
  # Reconnaissance vocale : variable d'environnement, sinon .env, sinon whisper.
  # Avec une clé OpenAI dans .env : OpenAI pour la voix et la compréhension (secours
  # local Whisper et mots-clés). Sans clé : modèles locaux uniquement.
  if [ -n "${FANILO_AI_OPENAI_API_KEY:-}" ]; then
    ASR_BACKEND="${ASR_BACKEND:-${FANILO_AI_ASR_BACKEND:-openai}}"
    export FANILO_AI_NLU_BACKEND="${FANILO_AI_NLU_BACKEND:-openai}"
  else
    ASR_BACKEND="${ASR_BACKEND:-${FANILO_AI_ASR_BACKEND:-whisper}}"
  fi
  [ "$ASR_BACKEND" != "none" ] && AI_EXTRA=(--extra asr)
  info "PostgreSQL (docker, port ${FANILO_DB_PORT:-5432})"
  docker compose up -d db >/dev/null
  for _ in $(seq 1 60); do
    docker compose exec -T db pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1 && break
    sleep 1
  done
  info "Dépendances Python et Node"
  (cd services/rules && uv sync -q)
  (cd services/ai && uv sync -q "${AI_EXTRA[@]}")
  if [ "$ASR_BACKEND" != "none" ] && ! command -v ffmpeg >/dev/null; then
    die "ffmpeg est requis pour la reconnaissance vocale (sudo apt install ffmpeg)."
  fi
  (cd services/api && uv sync -q)
  [ -d apps/dashboard/node_modules ] || (cd apps/dashboard && npm ci --silent)
  info "Migrations et données de démonstration"
  (cd services/api && uv run -q alembic upgrade head && uv run -q python -m app.modules.devseed)

  for p in "$AI_PORT" "$API_PORT" "$DASHBOARD_PORT"; do
    port_free "$p" || running ai || running api || running dashboard || die "Port $p déjà utilisé."
  done
  info "Démarrage des services"
  FANILO_AI_ASR_BACKEND="$ASR_BACKEND" \
    launch ai services/ai uv run "${AI_EXTRA[@]}" uvicorn app.main:app --host 127.0.0.1 --port "$AI_PORT"
  FANILO_AI_SERVICE_URL="http://127.0.0.1:$AI_PORT" \
  FANILO_CORS_ORIGINS="$FANILO_CORS_ORIGINS,http://$PUBLIC_HOST:$DASHBOARD_PORT" \
    launch api services/api uv run uvicorn app.main:app --host "$BIND" --port "$API_PORT" --reload
  VITE_API_URL="http://$PUBLIC_HOST:$API_PORT" VITE_DEMO_ACCOUNTS="${FANILO_SHOW_DEMO_ACCOUNTS:-true}" \
    launch dashboard apps/dashboard npx vite --host "$BIND" --port "$DASHBOARD_PORT" --strictPort
  # Tâches planifiées (cron en production) : escalade des alertes, rappels.
  launch tasks services/api bash -c "while true; do
      uv run -q python -m app.modules.alerts.cli escalate || true
      uv run -q python -m app.modules.reny.cli send-due-reminders || true
      sleep $TASKS_INTERVAL; done"

  [ "$ASR_BACKEND" != "none" ] && info "Chargement du modèle vocal (premier lancement : téléchargement, plusieurs minutes)"
  wait_http "http://127.0.0.1:$AI_PORT/health" "Service IA" 900
  wait_http "http://127.0.0.1:$API_PORT/health" "API"
  wait_http "http://127.0.0.1:$DASHBOARD_PORT/" "Dashboard"
  cat <<EOF

  FANILO tourne en local (données FICTIVES, contenus de DÉMONSTRATION) :
    Dashboard   http://$PUBLIC_HOST:$DASHBOARD_PORT
    API         http://$PUBLIC_HOST:$API_PORT   (documentation : /docs)
    Voix (ASR)  $ASR_BACKEND · compréhension : ${FANILO_AI_NLU_BACKEND:-lexicon}
    Mobile      cd apps/mobile && flutter run --dart-define=FANILO_API_URL=http://$PUBLIC_HOST:$API_PORT

  Comptes de démo (mot de passe : fanilo-demo-2026)
    admin · donnees · technique · responsable · responsable2
    conseiller · conseiller.tnr · chef.csb.a · chef.csb.b · chef.csb.c
    ac.a1 · ac.b1 · ac.c1   (agents : simulateur web + application mobile)

  Journaux : scripts/dev.sh logs api   ·   Arrêt : scripts/dev.sh stop
EOF
}

stop() {
  for name in tasks dashboard api ai; do
    if running "$name"; then
      kill -- "-$(cat "$PIDS/$name")" 2>/dev/null || kill "$(cat "$PIDS/$name")" 2>/dev/null || true
      ok "$name arrêté"
    fi
    rm -f "$PIDS/$name"
  done
  docker compose stop db >/dev/null 2>&1 && ok "PostgreSQL arrêté (données conservées)" || true
}

status() {
  for name in ai api dashboard tasks; do
    if running "$name"; then ok "$name (pid $(cat "$PIDS/$name"))"; else printf '  %s arrêté\n' "$name"; fi
  done
  docker compose ps db --format '  db : {{.Status}}' 2>/dev/null || true
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) status ;;
  logs) tail -n 100 -f "$LOGS/${2:-api}.log" ;;
  smoke) ensure_env; (cd services/api && uv run -q python ../../scripts/smoke_e2e.py --api "http://127.0.0.1:$API_PORT") ;;
  reset)
    read -r -p "Supprimer définitivement la base locale FANILO ? [o/N] " answer
    [ "$answer" = "o" ] || exit 0
    stop; docker compose down -v; ok "Base locale supprimée" ;;
  *) sed -n '2,14p' "$0"; exit 1 ;;
esac
