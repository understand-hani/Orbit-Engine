#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
DB_PATH="$REPO_DIR/data/infra_agent.db"
ENV_PATH="$REPO_DIR/backend/.env"
BACKUP_PATH="/tmp/orbit-engine-before-demo-clear-$(date '+%Y%m%d-%H%M%S').db"

if ! command -v sqlite3 >/dev/null 2>&1; then
    printf 'sqlite3 is required but was not found.\n' >&2
    exit 1
fi

if [[ ! -f "$DB_PATH" ]]; then
    printf 'Database not found: %s\n' "$DB_PATH" >&2
    exit 1
fi

cp "$DB_PATH" "$BACKUP_PATH"

sqlite3 "$DB_PATH" <<'SQL'
BEGIN IMMEDIATE;
DELETE FROM checkins;
DELETE FROM user_contexts;
COMMIT;
SQL

if [[ "$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='user_context_records';")" == "1" ]]; then
    sqlite3 "$DB_PATH" "DELETE FROM user_context_records;"
fi

if [[ -f "$ENV_PATH" ]]; then
    env_tmp="$(mktemp)"
    awk '
        BEGIN { replaced = 0 }
        /^APP_ENV=/ {
            print "APP_ENV=development"
            replaced = 1
            next
        }
        { print }
        END {
            if (!replaced) {
                print "APP_ENV=development"
            }
        }
    ' "$ENV_PATH" > "$env_tmp"
    mv "$env_tmp" "$ENV_PATH"
fi

remaining_checkins="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM checkins;")"
remaining_contexts="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM user_contexts;")"

printf 'Orbit Engine demo state cleared.\n'
printf 'Database: %s\n' "$DB_PATH"
printf 'Backup: %s\n' "$BACKUP_PATH"
printf 'Remaining check-ins: %s\n' "$remaining_checkins"
printf 'Remaining user contexts: %s\n' "$remaining_contexts"
printf 'Restart the backend and force-quit/reopen the iOS app.\n'
