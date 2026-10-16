# The Archive - self-host kit

> This repository is the **operator kit** for The Archive: the Compose stack, installer, backup
> scripts and documentation. The server runs from prebuilt container images
> (`ghcr.io/expensiverest/thearchive-api`, `-worker`); the application source is not in this
> repository. Licensed under FSL-1.1-Apache-2.0 (see `LICENSE`). The API description is in
> `api/openapi.yaml`.

A self-contained kit for running The Archive on your own machine using prebuilt images from GHCR
rather than building from source. The full operator guide is
[`docs/self-hosting.md`](docs/self-hosting.md); this file is the quick
reference.

| File                 | Purpose                                                                 |
| -------------------- | ----------------------------------------------------------------------- |
| `compose.yaml`       | The stack: `postgres` (private), `api`, `worker`. Uses GHCR images.     |
| `.env.example`       | Configuration template; `install.sh` writes the real `.env`.            |
| `install.sh`         | Checks Docker, generates secrets, starts the stack and seeds the owner. |
| `upgrade.sh`         | Backs up, pulls a new tag, restarts, health-checks, prints rollback.    |
| `Caddyfile`          | Optional automatic HTTPS config (Caddy).                                |
| `compose.caddy.yaml` | Optional overlay that adds the Caddy service.                           |

## Requirements

- Linux host with Docker Engine and the Compose plugin (`docker compose`).
- ~2 GiB RAM free for the stack and disk for your audio.
- For public HTTPS: a domain and a way to reach the host (Caddy here, or a Cloudflare Tunnel).

## Install

```bash
git clone https://github.com/expensiverest/thearchive-selfhost.git
cd thearchive-selfhost
bash install.sh
```

`install.sh` asks for the first owner's email and name, generates a strong `POSTGRES_PASSWORD`,
writes `.env` with mode 600, pulls the images, waits for the API to be healthy and runs the server
CLI (`node services/api/src/cli.ts create-owner --email … --name …`) to create the first account. It
prints a one-time password — save it.

To pin a version, set `ARCHIVE_VERSION` (for example `v0.1.0`); the default is `latest`.

## Public HTTPS

Either put the host behind a Cloudflare Tunnel (nothing else exposed), or use the bundled Caddy
overlay:

```bash
# set DOMAIN and ACME_EMAIL in .env first
docker compose --env-file .env -f compose.yaml -f compose.caddy.yaml up -d
```

Then set `PUBLIC_BASE_URL=https://$DOMAIN` in `.env`, restart the api service and set the same URL
in the app. See `docs/self-hosting.md` for Cloudflare Tunnel and Tailscale options.

## Upgrade

```bash
bash upgrade.sh v0.2.0     # or: bash upgrade.sh   (uses ARCHIVE_VERSION from .env)
```

The script takes a backup first (unless `SKIP_BACKUP=1`), pulls the tag, restarts the stack and
health-checks it. If the API does not become healthy it prints the rollback command. A downgrade
that leaves the database with migrations the old code does not know is refused at startup; restore
the pre-upgrade backup, then pin the previous tag.

## Backups

Use `scripts/backup.sh` and `scripts/restore.sh` (see
`docs/backup-restore.md`). A backup only counts once a restore has been tested.

## Notes

- PostgreSQL is never published on the host; only the API port is (default `127.0.0.1:8130`).
- The API applies migrations automatically on start.
- Never commit `.env`; it holds the database password and any SMTP credentials.
- The operator can read content on their server; end-to-end encryption is not implemented yet.
