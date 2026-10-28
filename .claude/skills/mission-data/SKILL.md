---
name: mission-data
description: Read or change Ruben's mission data (tasks, checklists, partners, gifts, budget, sell items, packing, notes, prayer requests, documents, contacts, newsletters, settings such as the departure date) through the gateway. Use whenever Ruben asks to add, change, tick off, move, delete, find or count something in the app, e.g. "add a task to renew my passport by March", "mark the visa medical done", "Jan pledged €50 a month", "what's still unpacked?", "push my departure to 14 Feb".
---

# Mission data gateway

`missions/app/server/tools/gateway.mjs` talks to the Mission App API, so every change syncs to the iPhone, Windows and web apps like an edit made on another device. Never edit the D1 database directly (`wrangler d1 execute`) for record changes: it skips the change numbers and the apps won't pick it up.

Run from `missions/app/server`:

```
node tools/gateway.mjs whoami                     # which server and account; fails with a hint if not logged in
node tools/gateway.mjs schema <collection>        # fields, types and allowed values (read from api/openapi.yaml)
node tools/gateway.mjs list <collection> [--search text] [--where field=value] [--where field!=value] [--sort field[:desc]] [--fields a,b] [--deleted]
node tools/gateway.mjs get <collection> <id>
node tools/gateway.mjs add <collection> '<json object or array>'
node tools/gateway.mjs update <collection> <id> '<json fields>'     # merge; null removes a field
node tools/gateway.mjs delete <collection> <id>                     # soft delete
node tools/gateway.mjs restore <collection> <id>
node tools/gateway.mjs summary                    # dashboard numbers (support %, tasks due, days to go)
node tools/gateway.mjs export backup.json
```

Collections: tasks, checklists, partners, gifts, budget, sellItems, packing, notes, documents, contacts, newsletters, settings. `<id>` may be a unique prefix (8 characters is plenty). Long or quote-heavy JSON: write it to a file in the scratchpad and pass `@path`, or pipe it and pass `-`.

## How to work

1. **Not logged in?** Ask Ruben to run the login himself in a terminal (it asks for his password; never type it for him):
   `node tools/gateway.mjs login --url https://api.hesent.me --profile live` (or `--url http://localhost:8787 --profile local`). `use <profile>` switches; `--profile` picks one per command.
2. **Look before you write.** `list` with `--search` to find the record and to avoid duplicates. Check `schema` when unsure of a field or value.
3. **Map his words to fields.** Money is in cents (`€50` → `5000`) with a `currency` (EUR unless he says NZD). Dates are `YYYY-MM-DD`; resolve "next Friday" against today. Ticking a task off: `status: "done"` plus `completedAt` (ISO timestamp). New tasks need `status: "todo"`. A task in a checklist: set `checklistId` (find the checklist id first). Prayer requests are `notes` with `kind: "prayer"`.
4. **Settings** live in one record, `settings` id `60a98c2f-4004-58e7-bcc2-c88a62377933` (`key: "main"`): departure date, support target/minimum, NZD rate. Update that one; never add a second `main`.
5. **Confirm before big or destructive changes**: deleting, or changing more than ~5 records at once. Show what will change and wait for a yes. Small, clear requests ("add X", "mark Y done") just do.
6. **Report back** in a line or two: what changed, plus the short id. Mention any `warnings` and that deletes can be undone with `restore`.

Every write is logged with before/after in `~/.missie/gateway-log.jsonl`, so an edit can be put back by updating with the `before` values.
