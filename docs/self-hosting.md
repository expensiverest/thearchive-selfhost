# Runbook: self-hosting The Archive

How to run The Archive on your own server for a small group of people. It covers the published
images in `` (build-from-source is also possible with `infra/compose/`). For the
owner's own host, see `docs/installation.md`.

The server stores everything you upload. **You, the operator, can read all content on your
server** for standard projects; end-to-end encryption is not implemented yet. Tell your users
that plainly (see `docs/legal/privacy-policy.md`).

## 1. Requirements

- **Hardware:** any always-on Linux box. The stack is small — budget ~2 GiB RAM and as much disk as
  your audio needs. An x86-64 or arm64 machine both work (the published images are multi-arch).
- **Software:** Docker Engine and the Compose plugin (`docker compose`). No Node.js needed on the
  host — the images contain everything.
- **Network:** the API listens on `127.0.0.1:8130` by default. For phones to reach it you need
  either a public HTTPS hostname (Caddy or a Cloudflare Tunnel) or a private network (Tailscale).
  **Public exposure must be HTTPS**; the app refuses plain HTTP except on local/tailnet addresses.
- **A domain** (only if you want public HTTPS).

## 2. Install

```bash
git clone https://github.com/expensiverest/thearchive-selfhost.git
cd thearchive-selfhost
bash install.sh
```

`install.sh` checks Docker, generates a strong database password, writes `.env` (mode 600), pulls
the images, waits for the API to be healthy and creates the first owner with
`node services/api/src/cli.ts create-owner --email … --name …`. Save the one-time password it
prints.

Verify:

```bash
curl -fsS http://127.0.0.1:8130/healthz
curl -fsS http://127.0.0.1:8130/.well-known/music-workspace
```

The discovery response shows the `installation_id`, `server_version` and the `api_base` the app
connects to.

## 3. Give the app a server address

In the app's Connect screen, enter the address:

- Local/tailnet testing: `http://<host-ip>:8130` (plain HTTP is allowed only for local/Tailscale).
- Everyone else: your HTTPS hostname, e.g. `https://music.example.com`.

Set `PUBLIC_BASE_URL` in `.env` to that same public URL so invitation links are correct, then
restart the API: `docker compose --env-file .env -f compose.yaml up -d`.

## 4. Remote access options

Pick one. Do not publish PostgreSQL or the Docker socket.

### a. Caddy (automatic HTTPS, bundled)

Open ports 80 and 443, add a DNS A/AAAA record for your domain, then:

```bash
# in .env: DOMAIN=music.example.com  and  ACME_EMAIL=you@example.com
docker compose --env-file .env -f compose.yaml -f compose.caddy.yaml up -d
```

Caddy obtains and renews a Let's Encrypt certificate and reverse-proxies to `api:8130` over the
private compose network. Keep `API_BIND_ADDR=127.0.0.1` so only Caddy is public.

### b. Cloudflare Tunnel (no open ports)

Good when the host has no public IP or you cannot open ports. Install `cloudflared` on the host,
create a tunnel and point a hostname at the API:

```bash
cloudflared tunnel login
cloudflared tunnel create thearchive
cloudflared tunnel route dns thearchive music.example.com
# config.yml:
#   tunnel: <tunnel-id>
#   credentials-file: /root/.cloudflared/<tunnel-id>.json
#   ingress:
#     - hostname: music.example.com
#       service: http://127.0.0.1:8130
#     - service: http_status:404
cloudflared tunnel run thearchive
```

Then set `PUBLIC_BASE_URL=https://music.example.com` and restart. In the Cloudflare dashboard, add
a **rate-limit rule for `/api/v1/auth/*`** (see section 7).

### c. Tailscale (private, no public hostname)

Best if only a known group uses the server. Install Tailscale on the host and on each device, set
`API_BIND_ADDR` to the host's Tailscale IP (e.g. `100.x.y.z`) and restart. Users connect to
`http://100.x.y.z:8130` over the tailnet; nothing is public. Notes and audio then never leave your
private network. Administration (SSH, Docker) also stays on the tailnet.

## 5. Email for invitations

Invitations are sent by the server. Without SMTP the link is only written to the API log
(`docker compose logs api`). To send real mail, set in `.env`:

```ini
SMTP_URL=smtps://user:password@smtp.example.com:465   # implicit TLS
# or STARTTLS on 587:
# SMTP_URL=smtp://user:password@smtp.example.com:587
MAIL_FROM="The Archive <no-reply@example.com>"
PUBLIC_BASE_URL=https://music.example.com
```

The invitation email contains both an HTTPS link and an app deep link
(`thearchive://connect?server=…&invite=…`). Any SMTP provider works; Resend, Brevo and a plain
mailbox all do. See `docs/email.md` for setup, DNS (SPF/DKIM/DMARC) and testing.

## 6. Backups and upgrades

**Backups** — use the repository scripts `scripts/backup.sh` and `scripts/restore.sh`; details in
`docs/backup-restore.md`. A snapshot only counts once you have restored it successfully.

**Upgrades**

```bash
cd thearchive-selfhost
bash upgrade.sh            # or: bash upgrade.sh 0.2.0
```

`upgrade.sh` backs up, pulls the new tag, restarts and health-checks the stack. On failure it
prints how to roll back. Rolling back past a migration is refused by the server's downgrade guard:
restore the pre-upgrade backup, then pin the old tag.

## 7. Hardening checklist

- [ ] HTTPS everywhere for public access; never expose HTTP to the internet.
- [ ] `API_BIND_ADDR=127.0.0.1` when a reverse proxy/tunnel is in front.
- [ ] Edge rate-limit rule for `/api/v1/auth/*` (Cloudflare: Security → WAF → Rate limiting rules;
      limit sign-in attempts per IP). The API also rate-limits sign-in itself.
- [ ] `.env` is mode 600 and never committed or shared; rotate the SMTP credential if leaked.
- [ ] PostgreSQL and the Docker socket are not published; admin access is SSH/Tailscale only.
- [ ] Automatic security updates for the host and a habit of tracking tagged releases.
- [ ] Backups configured **and restore-tested**; passphrase stored offline.
- [ ] Publish your own privacy policy (see `docs/legal/privacy-policy.md`).

## 8. Troubleshooting

| Symptom                                                    | Likely cause / fix                                                                               |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `docker compose` complains `POSTGRES_PASSWORD is required` | `.env` missing or not passed; run with `--env-file .env` (install.sh does this).                 |
| Postgres restarts, "permission denied"                     | Data dirs not owned by `HOST_UID`; `chown -R 1000:1000 <ARCHIVE_ROOT>`.                          |
| API unhealthy                                              | `docker compose logs api`; check the database password matches `.env`.                           |
| API exits with a migration/downgrade message               | The database is newer than the code; restore the pre-upgrade backup and pin the previous tag.    |
| App says the server is unreachable                         | Address/HTTPS wrong, tunnel down, or firewall blocking; check `curl <url>/healthz` from outside. |
| App says "update the app"                                  | The server's `MIN_APP_VERSION` is newer than the installed app; update or lower the setting.     |
| No invitation emails                                       | SMTP unset or wrong; check `docker compose logs api` for the logged link and the SMTP error.     |
| Worker unhealthy                                           | Stale heartbeat; check `docker compose logs worker` and free disk space.                         |
