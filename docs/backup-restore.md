# Runbook: backup and isolated restore (drill)

**Gate status: BLOCKED.** No external device exists; same-disk snapshots are explicitly not
disaster recovery. Until the drill below succeeds on external hardware, do not invite real
collaborators or treat recordings as durable (architecture section 11; PRD risk 1).

## Two tools, pick the backup step that fits

- **`scripts/backup.sh` / `scripts/restore.sh`** (the portable pair). Run from the Compose
  directory. `backup.sh [dir]` stops `api`/`worker`, writes a transaction-consistent `pg_dump`
  (`database.dump`), a `tar.gz` of the storage directory, a `manifest.txt` (format, timestamp,
  server version) and a `SHA256SUMS` checksum file into a new directory, then restarts the
  services. It refuses to overwrite an existing directory. `restore.sh <dir> --yes` verifies the
  checksums and manifest format, rejects unsafe tar entries, rebuilds the database and storage in a
  **clean** stack, and leaves writers stopped until you run `docker compose up -d api worker`. The
  output is **plaintext** — encrypt it before moving it off the host.
- **`infra/backup/backup.sh` / `restore.sh`** (restic). The same idea with restic-encrypted,
  de-duplicated snapshots and retention, aimed at the owner's external disk. See
  `infra/backup/README.md`.

Either way, a backup only counts once a **restore has been tested** — the drill below.

## Prerequisites (owner)

- One external disk (2-4 TB; a second rotated disk is preferred) + a second for offsite rotation.
- restic installed on the host (`~/bin/restic`), repository passphrase stored offline as well.

## Routine (after hardware exists)

1. `bash infra/backup/backup.sh` daily with `RESTIC_REPOSITORY` on the attached disk.
2. Periodically unplug the disk and rotate it to a trusted alternate location.
3. Weekly: `restic check` (part of the script) and sampled restores.
4. Monthly: full drill below, timed, to a **temporary** environment.

## Full drill (acceptance)

1. Create known sample data: project with two variants/revisions, timed-lyrics placeholder,
   comments placeholder, membership roles, one E2EE envelope fixture when Phase 3 exists.
2. Run the backup against the external disk.
3. Simulate total loss: stop the stack; rename `$STACK_ROOT/db` and `$STACK_ROOT/storage`.
4. Restore with `bash infra/backup/restore.sh` (isolated verification) and additionally boot the
   full stack against the restored data on replacement hardware/namespace.
5. Verify: user/project IDs, every original checksum, revision lineage, membership roles, key
   envelope rows, and (Phase 3) recovery-code access from a separate device.
6. Record wall-clock restore time; that becomes the documented RTO. Offsite RPO equals the time
   since the last physical rotation.

## Functional drill already performed (2026-10-13, same device - NOT DR)

`backup.sh` (drill override) produced a snapshot of the live deployment; `restore.sh` restored it
into a throwaway container and passed count + checksum verification. This proves the tooling;
it does **not** satisfy the gate. Evidence is recorded in PR #10.
