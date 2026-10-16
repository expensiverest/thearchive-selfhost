#!/usr/bin/env bash
# Run from the Compose directory (COMPOSE_FILE/COMPOSE_ENV_FILES work normally).
# Usage: scripts/backup.sh [new-backup-directory]
set -euo pipefail
umask 077
destination=${1:-"backup-$(date -u +%Y%m%dT%H%M%SZ)"}
if [[ -e "$destination" ]]; then echo "Backup destination already exists; refusing overwrite" >&2; exit 1; fi
mkdir -p -- "$destination"
services=$(docker compose ps --status running --services)
running=$(printf '%s\n' "$services" | grep -E '^(api|worker)$' || true)
restart() {
  if [[ -n "$running" ]]; then
    while IFS= read -r service; do docker compose start "$service" >&2; done <<< "$running"
  fi
}
trap restart EXIT
docker compose stop api worker >&2
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom' > "$destination/database.dump"
docker compose run --rm -T --no-deps --entrypoint sh api -c 'tar -czf - -C "$STORAGE_ROOT" .' > "$destination/storage.tar.gz"
printf 'format=thearchive-backup-v1\ncreated_at=%s\nserver_version=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${ARCHIVE_VERSION:-unknown}" > "$destination/manifest.txt"
(cd "$destination" && sha256sum database.dump storage.tar.gz manifest.txt > SHA256SUMS)
echo "Backup complete: $destination (contains private data; encrypt before moving off-host)"
