#!/usr/bin/env bash
# Sauvegarde CHIFFRÉE de la base FANILO (pg_dump format custom + AES-256 via openssl).
#
#   FANILO_BACKUP_PASSPHRASE=... scripts/backup.sh [dossier]   (défaut : ./backups)
#
# La phrase secrète ne doit jamais être stockée à côté des sauvegardes.
# Restauration testée par scripts/restore.sh (voir docs/exploitation.md).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
: "${FANILO_BACKUP_PASSPHRASE:?définir FANILO_BACKUP_PASSPHRASE (phrase secrète de chiffrement)}"
set -a; . ./.env; set +a
OUT_DIR="${1:-$ROOT/backups}"
mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"
FILE="$OUT_DIR/fanilo-$(date -u +%Y%m%dT%H%M%SZ).dump.enc"
docker compose exec -T db pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom --no-owner \
  | openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -pass env:FANILO_BACKUP_PASSPHRASE -out "$FILE"
chmod 600 "$FILE"
sha256sum "$FILE" > "$FILE.sha256"
echo "Sauvegarde chiffrée : $FILE ($(du -h "$FILE" | cut -f1))"
