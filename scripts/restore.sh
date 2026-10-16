#!/usr/bin/env bash
# Usage: scripts/restore.sh BACKUP_DIRECTORY --yes
# Restore into a provisioned, clean Compose stack. --yes permits replacing existing data.
set -euo pipefail
umask 077
source_dir=${1:?Usage: restore.sh BACKUP_DIRECTORY --yes}
if [[ ${2:-} != --yes || $# != 2 ]]; then
  echo "Restore replaces database and storage. Re-run with --yes after stopping external access." >&2; exit 1
fi
# Verify exactly the expected files; never execute/source the manifest or trust arbitrary paths.
expected=$(printf '%s\n' database.dump manifest.txt storage.tar.gz | sort)
actual=$(awk '{print $2}' "$source_dir/SHA256SUMS" | sort)
if [[ "$actual" != "$expected" ]]; then echo "Invalid checksum manifest" >&2; exit 1; fi
(cd "$source_dir" && sha256sum --check --strict SHA256SUMS)
if ! grep -qx 'format=thearchive-backup-v1' "$source_dir/manifest.txt"; then echo "Unsupported backup format" >&2; exit 1; fi
tar -tzf "$source_dir/storage.tar.gz" | awk '/^\// || /(^|\/)\.\.(\/|$)/ { bad=1 } END { exit bad }'
# Only regular files/directories are accepted; reject links, devices and other special entries.
tar -tvzf "$source_dir/storage.tar.gz" | awk 'substr($0,1,1)!="-" && substr($0,1,1)!="d" { bad=1 } END { exit bad }'
docker compose exec -T postgres pg_restore --list < "$source_dir/database.dump" > /dev/null
docker compose stop api worker
# Deliberately leave writers stopped on any restore error; never serve a partial restore.
docker compose exec -T postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "drop schema public cascade; create schema public;"'
docker compose exec -T postgres sh -c 'pg_restore --exit-on-error --single-transaction --no-owner --no-acl -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$source_dir/database.dump"
docker compose run --rm -T --no-deps --entrypoint sh api -c '
  test -n "$STORAGE_ROOT" && test "$STORAGE_ROOT" != / && test -d "$STORAGE_ROOT"
  find "$STORAGE_ROOT" -mindepth 1 -delete
  tar -xzf - --no-same-owner -C "$STORAGE_ROOT"
' < "$source_dir/storage.tar.gz"
echo "Restore complete. Check the code version against manifest.txt, then: docker compose up -d api worker"
