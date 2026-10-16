# Privacy policy

**Last updated: 2026-10-15.** This is the privacy policy for The Archive (the mobile app and
server software in this repository). It is a template: each server is run by its own operator, so
the operator of the server you connect to is the data controller for the data on that server. See
[For self-hosters](#for-self-hosters).
Contact: `danielanderson@myglassflow.com`

## The short version

- The app itself collects nothing. It has no analytics, no telemetry, no advertising, and no
  third-party trackers.
- Everything you create is sent only to the server you choose to connect to. That server is run by
  the person or organisation who invited you (the operator), not by the makers of the app.
- The operator can see the content stored on their server, unless a project uses optional
  end-to-end encryption, which is **not implemented yet**.
- You can delete your account from inside the app.

## What the app does and does not do

**The app does not collect or send anything to the app's authors.** It makes no network requests
except to the server you explicitly configure. There is no account with the app's authors, no
crash reporting, and no usage analytics.

**The app stores on your device:** the server address and identity, your session token (in the
system Keychain / secure store), and any files you choose to download for offline use. Deleting
the app removes this local data.

A **demo mode** runs entirely on built-in sample data with no network and no account; nothing you
do in demo mode is sent anywhere or saved to a server.

## What the server stores

If you connect to a server and sign in, that server stores the data needed to run your workspace:

| Data                                           | Why                                      |
| ---------------------------------------------- | ---------------------------------------- |
| Email address                                  | Sign-in and invitations                  |
| Display name                                   | Show who did what                        |
| Password (salted Argon2id hash, never plain)   | Authentication                           |
| Device name                                    | Distinguish your devices in settings     |
| Audio files and revisions                      | Your music workspace content             |
| Lyrics, notes, comments, titles, filenames     | Your music workspace content             |
| Session and invitation records (hashed tokens) | Keep you signed in; invite collaborators |
| Storage usage and quota                        | Show your usage and enforce limits       |

Server logs are structured and redact tokens and creative content; the software is designed not to
log titles, lyrics, notes or filenames.

## Who can see your data

- **You**, and the collaborators you share a project with (owner, editor, reviewer, listener).
- **The server operator**, who controls the hardware and can access the database and files. For
  standard (non-encrypted) projects the operator holds the plaintext by design. Optional
  end-to-end encryption is planned but **not implemented yet**; until it lands, no project is
  hidden from its operator.
- Nobody else. The app's authors receive nothing.

## Retention and deletion

- Data stays on the server until you or the operator deletes it.
- **You can delete your account in the app** (Settings → Security → Delete account). You are asked
  to confirm your password. If you own a project that still has other active members, deletion is
  refused until you transfer ownership or remove those members. On success, your sessions are
  revoked and your data is deleted; where records must be kept for audit integrity, personal
  fields are anonymised instead of the whole row being removed.
- Ask the operator for anything else (backups, server-wide records).

## Children

The app is not directed at children and the operator does not knowingly let them create accounts.

## Changes

This policy may change with the software. The operator should publish their own version with their
contact details and the date it took effect.

## For self-hosters

If you run The Archive for other people, you are the data controller for their data and this
document is a template. Before you open your server to anyone:

1. Replace `danielanderson@myglassflow.com` above with a monitored address, and set the "Last updated"
   date.
2. Add your identity (name or organisation) and where the server is hosted.
3. Describe how long you keep data and backups, and how a user asks you to delete it.
4. State that you, as operator, can access content on your server; do not promise more privacy
   than the software provides. Do not claim end-to-end encryption — it is not implemented.
5. If you serve users in a jurisdiction with specific rules (GDPR, CCPA, …), add the rights those
   users have and your lawful basis for processing.
6. Publish the policy at a stable URL reachable from your server or your invite page.

The self-contained HTML version of this template is
[`privacy-policy.html`](privacy-policy.html); edit the same placeholders there.
