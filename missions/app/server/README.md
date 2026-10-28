# Mission App API

The server behind the iPhone app and the Windows helper. It keeps every task, checklist, partner, budget line, sell item, packing item, note, contact and document in sync between your devices, and stores your important files (passport scan, tickets, insurance policy) so you can't lose them.

- **Contract:** [`../api/openapi.yaml`](../api/openapi.yaml). Both apps are built against it.
- **Runs on:** your own server (Ubuntu, behind nginx). The code is written for the Workers runtime (`wrangler`): its `DB` is a SQLite database and `FILES` a file store, both on the server's own disk.
- **Address:** `https://api.hesent.me`

## What's in this folder

| Path | What it is |
| --- | --- |
| `src/index.js` | The whole server, one file, no dependencies |
| `migrations/` | Database tables (SQLite) |
| `wrangler.toml` | Runtime settings: the database, the file store, the daily clean-up |
| `test/api.test.mjs` | End-to-end tests (28 tests: auth, devices, sync, conflicts, files, summary, export, the public routes for hesent.me) |
| `seed/seed.mjs`, `seed/seed-data.json` | Starter data: 12 checklists, 100 tasks with due dates, packing list, document placeholders, settings |
| `tools/gateway.mjs` | Command-line gateway: list, add, change and delete records (what Claude uses when you ask it to change something) |

## How sync works (short)

Each app keeps its own local database and works offline. On sync it sends what changed locally and gets back everything that changed on the server since its last sync. When two devices edited the same item, the latest edit wins. Deleting keeps a "deleted" marker for 180 days so other devices hear about it. Details are in the contract.

Your main settings (departure date, support target) live in the `settings` record with id `60a98c2f-4004-58e7-bcc2-c88a62377933` and `data.key = "main"`. The apps should use that id so every device edits the same record. The server reads the newest `settings` record with `key = "main"`.

## Letters on hesent.me

A newsletter shows on hesent.me (`/nl/brieven/`, `/en/letters/`) once it is `sent` and has `public: true` ("Show on hesent.me" in the web app's letter editor). It shows in Dutch once it has `title`, and in English once it has `titleEn`; the other words follow the same pattern (`subtitle`/`subtitleEn`, `body`/`bodyEn`, `note`, `nextTime`, `prayers`). Its photos are files (`PUT /v1/files/{id}`) listed in `photos` with a caption per language; the first one leads. `GET /v1/public/photos/{id}` serves a photo without a login, but only while an online letter uses it.

## Messages from hesent.me

The giving page (`/nl/geven/`, `/en/give/`) has a form to send Ruben a message. `POST /v1/public/message` puts it on the partner with that email (or a new one on "On my list", tagged `website`): the message goes on top of their `siteMessages` (and, with the date, on top of their notes), `replyWaiting` is set, and the follow-up is set to today with "Reply to their message from hesent.me". The apps put such a person first under "Waiting on you" with the message, whatever their stage, until Ruben replies or marks it answered; the iPhone app also notifies as soon as a sync brings one in. Nothing is emailed.

## Put it online

The API runs on your own server, behind nginx at `https://api.hesent.me`. After changing the code here: copy this folder to the server, apply any new files in `migrations/` to the database, and restart the API. Then open `https://api.hesent.me/v1/health`; you should see `"ok":true`, and `https://api.hesent.me/v1/public/summary` should answer without a login (a 401 there means the server still runs code from before the public routes).

The sign-up and the message form on hesent.me are limited per visitor, by the IP nginx passes on. Keep this line in the API's `location` block, or every visitor counts as the same one: `proxy_set_header X-Real-IP $remote_addr;`

The first time only:

1. Set `SETUP_SECRET` on the server to a long random string (keep it in your password manager).
2. Create your account (once; afterwards this endpoint refuses). On Windows PowerShell:
   ```
   curl.exe -X POST https://api.hesent.me/v1/auth/setup -H "Content-Type: application/json" -d "{\"setupSecret\":\"YOUR-SECRET\",\"email\":\"you@example.com\",\"password\":\"a long password\",\"name\":\"Ruben\",\"device\":{\"name\":\"Setup\",\"platform\":\"windows\"}}"
   ```
   Copy the `token` from the answer.
3. Load the starter checklists and tasks:
   ```
   node seed/seed.mjs --url https://api.hesent.me --token THE-TOKEN
   ```
   Safe to run again later: it never overwrites something you changed in the app.
4. Log in from the iPhone app and the Windows helper with your email and password.

## Day to day

- **Lost a device?** In either app, open Devices and remove it (or `DELETE /v1/devices/{id}`). Its login stops working at once.
- **Backup:** `GET /v1/export` gives everything as one JSON file. Files are listed, not included; they stay on the server. Good habit: download one before you fly.
- **Forgot your password?** There's no email reset (no mail server needed). Change it from a device that's still logged in. If none is, ask a Claude thread to reset it in the database on the server.

## Change things by asking Claude

`tools/gateway.mjs` is a small command-line client for this API. Claude Code uses it (see `.claude/skills/mission-data/`) when you say things like "add a task to book the flight by 1 December" or "Anneke pledged €40 a month". Changes go through the API, so your devices get them on their next sync.

Log in once in a terminal in this folder; it asks for your password and saves a device token in `~/.missie/gateway.json`:

```
node tools/gateway.mjs login --url https://api.hesent.me --profile live
```

The gateway shows up as "Claude gateway" under Devices; remove it there to cut its access. Run `node tools/gateway.mjs` for all commands.

## Develop and test locally

```
npm install
echo SETUP_SECRET="dev-setup-secret" > .dev.vars
npm run dev            # http://localhost:8787, local database and files
npm test               # in a second terminal
```

Tests start from an empty local database the first time and can be re-run. More than about five runs within 15 minutes trips the login limit (10 failed logins per 15 minutes); wait or delete `.wrangler/`.

## Security in brief

- Passwords are hashed with PBKDF2-SHA256 (100,000 rounds). Device tokens are stored only as hashes.
- Every record and file belongs to a space; today that's just yours. Sharing later (with a mentor or parent, read-only or editor) only needs a new membership row, and the apps won't change.
- Data and files stay on your own server. Files are private and are only served to a logged-in device, except the photos of a letter you put on hesent.me.
