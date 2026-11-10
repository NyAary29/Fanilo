#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# FANILO — préparer le téléphone Android branché en USB.
#
#   scripts/phone.sh            # liaison USB + installation des 2 apps (si besoin)
#   scripts/phone.sh link       # seulement la liaison USB (après avoir débranché)
#   scripts/phone.sh install    # reconstruit et réinstalle les 2 apps
#
# Le téléphone doit avoir le « débogage USB » activé. L'API doit tourner
# (scripts/dev.sh start). La liaison `adb reverse` fait voir au téléphone le
# serveur du PC sous http://localhost:8000 ; elle se perd à chaque débranchement.
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb}"
API_URL="http://localhost:8000"

info() { printf '\033[1;36m▶ %s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

[ -x "$ADB" ] || die "adb introuvable ($ADB)."

device() {
  "$ADB" start-server >/dev/null 2>&1
  local id
  id="$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  if [ -z "$id" ]; then
    if "$ADB" devices | grep -q unauthorized; then
      die "Téléphone non autorisé : acceptez « Autoriser le débogage USB » sur l'écran du téléphone, puis relancez."
    fi
    die "Aucun téléphone détecté : branchez le câble USB (débogage USB activé), puis relancez."
  fi
  echo "$id"
}

link() {
  local id="$1"
  "$ADB" -s "$id" reverse tcp:8000 tcp:8000 >/dev/null
  curl -fsS -m 3 "$API_URL/health" >/dev/null || die "L'API ne répond pas : lancez d'abord scripts/dev.sh start"
  ok "Téléphone $id relié au serveur du PC ($API_URL)"
}

install_app() { # id, dossier, nom
  local id="$1" dir="$2" name="$3" apk="$ROOT/$2/build/app/outputs/flutter-apk/app-debug.apk"
  if [ "${FORCE_BUILD:-0}" = "1" ] || [ ! -f "$apk" ]; then
    info "Compilation de l'app $name (quelques minutes la première fois)"
    (cd "$ROOT/$dir" && flutter build apk --debug --dart-define=FANILO_API_URL="$API_URL" >/dev/null)
  fi
  "$ADB" -s "$id" install -r "$apk" >/dev/null
  ok "App $name installée"
}

ID="$(device)"
case "${1:-all}" in
  link) link "$ID" ;;
  install) FORCE_BUILD=1 install_app "$ID" apps/mobile "agent"; FORCE_BUILD=1 install_app "$ID" apps/femmes "femmes"; link "$ID" ;;
  all) install_app "$ID" apps/mobile "agent"; install_app "$ID" apps/femmes "femmes"; link "$ID" ;;
  *) sed -n '2,12p' "$0"; exit 1 ;;
esac
