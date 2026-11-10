#!/usr/bin/env bash
# Enregistre 6 secondes au micro du PC et compare les modèles de transcription.
#   scripts/test-voix.sh            # enregistre puis compare
#   scripts/test-voix.sh fichier    # compare un fichier existant (wav, m4a…)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"
FILE="${1:-}"
if [ -z "$FILE" ]; then
  FILE="$(mktemp --suffix=.wav)"
  trap 'rm -f "$FILE"' EXIT
  printf '\n\033[1;36m🎙  Parlez en malgache pendant 6 secondes, après le BIP…\033[0m\n'
  sleep 1; printf '\a'
  if command -v pw-record >/dev/null; then
    timeout 6 pw-record --rate 16000 --channels 1 "$FILE" || true
  else
    arecord -q -d 6 -f S16_LE -r 16000 -c 1 "$FILE"
  fi
  printf '\033[1;32m✔ Enregistré. Comparaison des modèles (1 à 2 minutes)…\033[0m\n'
fi
set -a; . "$ROOT/.env"; set +a
cd "$ROOT/services/ai"
uv run -q --extra asr python -u -m eval.compare_live "$FILE" 2>&1 | grep --line-buffered -vE "Warning|warn\(|HF_TOKEN|unauthenticated"
