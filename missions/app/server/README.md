# Mission App API

The server behind the iPhone app and the Windows helper. It keeps every task, checklist, partner, budget line, sell item, packing item, note, contact and document in sync between your devices, and stores your important files (passport scan, tickets, insurance policy) so you can't lose them.

- **Contract:** [`../api/openapi.yaml`](../api/openapi.yaml). Both apps are built against it.
- **Runs on:** Cloudflare Workers (same free account as your newsletter site), with D1 for data and R2 for files, both in the EU.
- **Address:** `https://api.rubenonmission.nl`
- **Cost:** €0 at your size. D1 and Workers are free. R2 is free up to 10 GB, but Cloudflare asks for a payment card before you can switch R2 on.

## What's in this folder

| Path | What it is |
| --- | --- |
| `src/index.js` | The whole server, one file, no dependencies |
| `migrations/` | Database tables (D1 / SQLite) |
| `wrangler.toml` | Cloudflare settings |
| `test/api.test.mjs` | End-to-end tests (19 tests: auth, devices, sync, conflicts, files, summary, export) |
| `seed/seed.mjs`, `seed/seed-data.json` | Starter data: 12 checklists, 100 tasks with due dates, packing list, document placeholders, settings |

## How sync works (short)

Each app keeps its own local database and works offline. On sync it sends what changed locally and gets back everything that changed on the server since its last sync. When two devices edited the same item, the latest edit wins. Deleting keeps a "deleted" marker for 180 days so other devices hear about it. Details are in the contract.

Your main settings (departure date, support target) live in the `settings` record with id `60a98c2f-4004-58e7-bcc2-c88a62377933` and `data.key = "main"`. The apps should use that id so every device edits the same record. The server reads the newest `settings` record with `key = "main"`.

## Put it online (one evening, after the website is live)

You need Node.js 18+ and the Cloudflare account from the website setup. In a terminal in this folder:

1. Install and log in:
   ```
   npm install
   npx wrangler login
   ```
2. Create the database in the EU and put the `database_id` it prints into `wrangler.toml`:
   ```
   npx wrangler d1 create missionapp --jurisdiction=eu
   ```
3. Switch on R2 in the Cloudflare dashboard (*R2 Object Storage*, add a card), then create the bucket:
   ```
   npx wrangler r2 bucket create missionapp-files --jurisdiction=eu
   ```
4. Set the one-time setup secret (make up a long random string, keep it in your password manager):
   ```
   npx wrangler secret put SETUP_SECRET
   ```
5. Create the tables and deploy:
   ```
   npm run deploy
   ```
6. In Cloudflare: *Workers & Pages* > `missionapp-api` > *Settings* > *Domains & Routes* > add `api.rubenonmission.nl`.
7. Check it: open `https://api.rubenonmission.nl/v1/health` in a browser. You should see `"ok":true`.
8. Create your account (once; afterwards this endpoint refuses). On Windows PowerShell:
   ```
   curl.exe -X POST https://api.rubenonmission.nl/v1/auth/setup -H "Content-Type: application/json" -d "{\"setupSecret\":\"YOUR-SECRET\",\"email\":\"you@example.com\",\"password\":\"a long password\",\"name\":\"Ruben\",\"device\":{\"name\":\"Setup\",\"platform\":\"windows\"}}"
   ```
   Copy the `token` from the answer.
9. Load the starter checklists and tasks:
   ```
   node seed/seed.mjs --url https://api.rubenonmission.nl --token THE-TOKEN
   ```
   Safe to run again later: it never overwrites something you changed in the app.
10. Log in from the iPhone app and the Windows helper with your email and password.

## Day to day

- **Lost a device?** In either app, open Devices and remove it (or `DELETE /v1/devices/{id}`). Its login stops working at once.
- **Backup:** `GET /v1/export` gives everything as one JSON file. Files are listed, not included; they stay in R2. Good habit: download one before you fly.
- **Forgot your password?** There's no email reset (no mail server needed). Change it from a device that's still logged in. If none is, ask a Claude thread to reset it with `wrangler d1 execute`.

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
- Data is in the EU (D1 and R2 with EU jurisdiction). Files are private and are only served to a logged-in device.
