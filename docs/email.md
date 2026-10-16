# Runbook: email for invitations

The server needs SMTP only for **invitation emails** (and password-reset style messages if present
later). Without it, invitations still work — the invite link is written to the API log — but users
must be sent the link manually.

## Configuration

Set these in the server's `.env` (the real file, never committed):

```ini
# Implicit TLS (port 465):
SMTP_URL=smtps://user:password@smtp.example.com:465
# STARTTLS (port 587) — note smtp:// (not smtps://):
# SMTP_URL=smtp://user:password@smtp.example.com:587

MAIL_FROM="The Archive <no-reply@example.com>"
PUBLIC_BASE_URL=https://music.example.com   # used to build the invitation link
```

- `MAIL_FROM` is required whenever `SMTP_URL` is set; it must be an address your provider allows
  you to send as (usually the same domain you verified with the provider).
- `PUBLIC_BASE_URL` must match the hostname clients use, or the invite link will point somewhere
  the app cannot reach.
- Passwords with special characters must be URL-encoded in `SMTP_URL` (`@` → `%40`, `:` → `%3A`,
  `/` → `%2F`, and so on).

Apply the change:

```bash
docker compose --env-file .env -f compose.yaml up -d api
docker compose logs -f api      # watch the first invitation attempt
```

The server retries the TCP/TLS connection a few times with a short connect timeout before giving
up, because some relays occasionally hang one connection.

## Providers

Any standard SMTP provider works. Two that are simple to set up:

### Resend

1. Create an account and a **domain**; add the DNS records Resend shows (SPF, DKIM, and the
   return-path CNAME).
2. Create an **API key** for sending, then take the SMTP credentials from Resend's
   "SMTP" section: host `smtp.resend.com`, port `465`, username `resend`, password = the API key.
   ```ini
   SMTP_URL=smtps://resend:<API_KEY>@smtp.resend.com:465
   MAIL_FROM="The Archive <no-reply@yourdomain>"
   ```

### Brevo

1. Create an account and verify a **sender domain** (add the DKIM/SPF records Brevo shows).
2. In SMTP & API → SMTP, copy the host, port, login and key.
   ```ini
   SMTP_URL=smtp://<login>@smtp-relay.brevo.com:587    # STARTTLS
   MAIL_FROM="The Archive <no-reply@yourdomain>"
   ```

### Any other provider / your own mailbox

Use the provider's SMTP host, port and credentials exactly as documented. A personal mailbox
(Gmail, Fastmail, etc.) works for low volume, but provider limits and spam handling make a
transactional provider a better long-term choice.

## DNS (deliverability)

For the domain in `MAIL_FROM`, publish:

- **SPF**: a TXT record authorising the provider (`v=spf1 include:<provider> ~all`).
- **DKIM**: the record the provider gives you, so messages are signed.
- **DMARC**: start with `v=DMARC1; p=none; rua=mailto:<you>@yourdomain` and tighten later.

Without these, invitation mail is likely to land in spam.

## Test

The CLI can send a test message without creating an invitation (the L1 command):

```bash
docker compose --env-file .env -f compose.yaml exec -T api \
  node services/api/src/cli.ts send-test-email --to you@example.com
```

Or send a real invitation from the app and check
`docker compose logs api` for SMTP errors.

## Troubleshooting

| Symptom                         | Fix                                                                              |
| ------------------------------- | -------------------------------------------------------------------------------- |
| Invitations only appear in logs | `SMTP_URL` is empty — set it and recreate the `api` service.                     |
| `535 authentication failed`     | Wrong username/password/key, or the password needs URL-encoding in `SMTP_URL`.   |
| `mail from` address rejected    | `MAIL_FROM` domain not verified with the provider.                               |
| Connection timeout              | Wrong port (465 = `smtps://`, 587 = `smtp://`) or the host blocks outbound SMTP. |
| Mail lands in spam              | Add SPF/DKIM/DMARC (above) and use a matching `MAIL_FROM` domain.                |
| Invite link points at localhost | `PUBLIC_BASE_URL` is unset or wrong; set it to the public hostname and restart.  |
