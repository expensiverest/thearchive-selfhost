# Security policy

## Reporting a vulnerability

Please report suspected vulnerabilities **privately**. Do not open a public issue, and do not
include exploit details in a pull request.

- **Email:** `danielanderson@myglassflow.com`
- Include: what you found, the affected version/commit, how to reproduce it, and any impact you
  can demonstrate.
- You will get an acknowledgement as soon as the owner reads it. There is no bug-bounty program
  and no guaranteed response time; this is a small self-hosted project.

Please do not test against a server you do not own or operate without written permission. The
owner's deployment (`music.danieldgp.com`) is not available for testing.

## Supported versions

The project is pre-1.0 and evolving. Security fixes are made on `main` and included in the next
tagged release.

| Version                     | Supported                        |
| --------------------------- | -------------------------------- |
| Latest tagged release       | Yes                              |
| `main`                      | Yes (development)                |
| Older tags                  | No                               |
| Forks and modified versions | No — report to whoever runs them |

Self-hosters should track releases and the upgrade notes in
[`docs/self-hosting.md`](docs/self-hosting.md).

## Scope

**In scope**

- The server (`services/api`, `services/worker`): authentication and session handling,
  authorization/roles, tenant and project isolation, upload handling, media serving, the admin
  surface, migrations, and the CLI.
- The mobile client's handling of tokens, server identity and local storage.
- The self-hosting kit (`infra/`) and release workflow, including anything that would leak
  secrets or ship an unsafe image.
- Documentation that gives operators unsafe advice.

**Out of scope**

- The owner's live deployment and its infrastructure (Cloudflare tunnel, Tailscale, host).
- Denial of service beyond the documented rate limits and resource caps.
- Threats already listed as explicit non-goals in
  the threat model — e.g. a compromised device, a
  malicious server operator reading standard (non-E2EE) projects, or traffic analysis.
- Optional end-to-end encryption: it is **not implemented yet** and its design is a written
  prerequisite, not a reviewed feature (Phase 3 gates).

## What we ask of self-hosters

- Treat the server's `.env` and database as secrets; the operator holds the plaintext of standard
  (non-E2EE) projects by design.
- Serve the API only over HTTPS, keep `cloudflared`/Tailscale up to date, and rate-limit
  `/api/v1/auth/*` at the edge (see the Cloudflare note in
  [`docs/self-hosting.md`](docs/self-hosting.md)).
- Take and **restore-test** backups; see [`docs/backup-restore.md`](docs/backup-restore.md).

## No warranty

The software is provided "as is" under the project license (`LICENSE`), without warranty of any
kind. Nothing here is an audit, penetration test or certification.
