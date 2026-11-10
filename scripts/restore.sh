#!/usr/bin/env bash
# Restauration d'une sauvegarde chiffrée.
#
#   FANILO_BACKUP_PASSPHRASE=... scripts/restore.sh FICHIER.dump.enc [--into BASE]
#
# Par défaut, restaure dans une base de TEST « fanilo_restore_test » (recréée),
# puis compare quelques comptages avec la base courante : c'est le test de
# restauration documenté. « --into fanilo » remplace la base principale
# (après confirmation) : à réserver à une reprise réelle, services arrêtés.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
: "${FANILO_BACKUP_PASSPHRASE:?définir FANILO_BACKUP_PASSPHRASE}"
FILE="${1:?fichier de sauvegarde attendu}"
TARGET="fanilo_restore_test"
[ "${2:-}" = "--into" ] && TARGET="${3:?nom de base attendu}"
set -a; . ./.env; set +a
[ -f "$FILE.sha256" ] && sha256sum -c "$FILE.sha256" >/dev/null && echo "Empreinte SHA-256 vérifiée."
if [ "$TARGET" = "$POSTGRES_DB" ]; then
  read -r -p "REMPLACER la base principale « $TARGET » ? [o/N] " answer
  [ "$answer" = "o" ] || exit 1
fi
psql() { docker compose exec -T db psql -U "$POSTGRES_USER" -v ON_ERROR_STOP=1 "$@"; }
psql -d postgres -q -c "DROP DATABASE IF EXISTS \"$TARGET\" WITH (FORCE);" -c "CREATE DATABASE \"$TARGET\";"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass env:FANILO_BACKUP_PASSPHRASE -in "$FILE" \
  | docker compose exec -T db pg_restore -U "$POSTGRES_USER" -d "$TARGET" --no-owner --exit-on-error
echo "Restauré dans « $TARGET »."
Q="SELECT (SELECT count(*) FROM users)||' comptes, '||(SELECT count(*) FROM beneficiaries)||' bénéficiaires, '||(SELECT count(*) FROM alerts)||' alertes, '||(SELECT count(*) FROM audit_events)||' événements d''audit, migration '||(SELECT version_num FROM alembic_version)"
echo "  restaurée : $(psql -d "$TARGET" -tA -c "$Q")"
[ "$TARGET" != "$POSTGRES_DB" ] && echo "  courante  : $(psql -d "$POSTGRES_DB" -tA -c "$Q")"
