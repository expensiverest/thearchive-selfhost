#!/usr/bin/env bash
# The Archive - upgrade an existing self-host install.
#
# Takes a backup, records the current image tags, pulls the target release, restarts the stack and
# waits for health. If anything fails afterwards, it prints the exact rollback command.
#
# Usage:
#   bash upgrade.sh                 # upgrade to the tag in .env (ARCHIVE_VERSION)
#   bash upgrade.sh v0.2.0          # switch to a specific tag and restart
#   SKIP_BACKUP=1 bash upgrade.sh   # skip the pre-upgrade backup (not recommended)
#
# The API refuses to start if the database contains migrations the running code does not know
# (a downgrade); restore from a backup in that case.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
die() {
  printf '\n\033[31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

[ -f .env ] || die ".env not found - run install.sh first."
command -v docker >/dev/null 2>&1 || die "Docker is not installed."

compose() { docker compose --env-file .env -f compose.yaml "$@"; }

# .env stays the source of truth; a tag argument overrides ARCHIVE_VERSION in place.
if [ "${1:-}" != "" ]; then
  say "Pinning ARCHIVE_VERSION=$1 in .env"
  if grep -q '^ARCHIVE_VERSION=' .env; then
    sed -i.bak "s|^ARCHIVE_VERSION=.*|ARCHIVE_VERSION=$1|" .env && rm -f .env.bak
  else
    printf 'ARCHIVE_VERSION=%s\n' "$1" >>.env
  fi
fi

previous="$(grep -E '^ARCHIVE_VERSION=' .env | cut -d= -f2- || true)"
previous="${previous:-latest}"
say "Current tag: $previous"

# --- backup -----------------------------------------------------------------------------------
# Public kit layout keeps scripts/ next to this file; the monorepo keeps it two levels up.
backup_script="$SCRIPT_DIR/scripts/backup.sh"
[ -f "$backup_script" ] || backup_script="$SCRIPT_DIR/../../scripts/backup.sh"
if [ "${SKIP_BACKUP:-}" = "1" ]; then
  say "SKIP_BACKUP=1 - not taking a pre-upgrade backup"
elif [ -x "$backup_script" ] || [ -f "$backup_script" ]; then
  say "Taking a pre-upgrade backup (scripts/backup.sh)"
  if ! bash "$backup_script"; then
    die "the pre-upgrade backup failed; not upgrading. Fix the backup first, or SKIP_BACKUP=1 to override."
  fi
else
  say "WARNING: $backup_script not found - skipping the pre-upgrade backup."
  say "Take a backup before upgrading: docs/backup-restore.md."
fi

# --- pull and restart -------------------------------------------------------------------------
say "Pulling images"
compose pull

say "Recreating containers"
compose up -d

say "Waiting for the API to become healthy"
api_id="$(compose ps -q api)"
status="unknown"
for i in $(seq 1 60); do
  status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$api_id" 2>/dev/null || echo none)"
  [ "$status" = "healthy" ] && break
  [ "$status" = "unhealthy" ] && break
  sleep 2
done

if [ "$status" != "healthy" ]; then
  compose logs --tail 60 api
  cat >&2 <<EOF

Upgrade FAILED: the API is not healthy.

Rollback options:
  1. If the new image is broken, revert the tag and restart:
       sed -i 's|^ARCHIVE_VERSION=.*|ARCHIVE_VERSION=$previous|' .env
       docker compose --env-file .env -f compose.yaml up -d
  2. If the database was migrated and the old code will not start (downgrade guard), restore the
     pre-upgrade backup first, then pin the previous tag:
       see docs/backup-restore.md

Previous tag recorded: $previous
EOF
  exit 1
fi

say "Upgrade complete (tag: $(grep -E '^ARCHIVE_VERSION=' .env | cut -d= -f2-))"
compose ps
