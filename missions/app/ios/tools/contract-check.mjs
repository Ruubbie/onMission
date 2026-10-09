// Checks that what the iPhone app sends matches the API contract (app/api/openapi.yaml), against a running server.
// Every record below is shaped exactly as Shared/Model/Models.swift (`known`) and Shared/Sync/*.swift build them.
//
//   cd app/server && npm run dev                          (in one terminal; see server/README.md)
//   node tools/contract-check.mjs                          (from the ios folder)
//   BASE_URL=http://localhost:8787 SETUP_SECRET=dev-setup-secret EMAIL=test@example.com PASSWORD="correct horse battery" node tools/contract-check.mjs
//
// It creates the account with the setup secret if the server is empty, otherwise logs in. Uses fresh ids, so it can be re-run.
import { randomUUID, createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const BASE = (process.env.BASE_URL || "http://localhost:8787").replace(/\/$/, "");
const SETUP_SECRET = process.env.SETUP_SECRET || "dev-setup-secret";
const EMAIL = process.env.EMAIL || "test@example.com";
const PASSWORD = process.env.PASSWORD || "correct horse battery";
const here = dirname(fileURLToPath(import.meta.url));

let failures = 0;
const ok = (cond, label, extra = "") => {
  console.log(`${cond ? "PASS" : "FAIL"}  ${label}${extra ? "  " + extra : ""}`);
  if (!cond) failures++;
};

async function call(method, path, { token, json, body, headers = {} } = {}) {
  const h = { ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  if (json !== undefined) { h["Content-Type"] = "application/json"; body = JSON.stringify(json); }
  const res = await fetch(BASE + path, { method, headers: h, body });
  const buf = method === "HEAD" ? Buffer.alloc(0) : Buffer.from(await res.arrayBuffer());
  let data = null;
  try { data = buf.length ? JSON.parse(buf.toString("utf8")) : null; } catch { data = null; }
  return { status: res.status, headers: res.headers, data, buf };
}

// Same as Swift TimeFormat.string (ISO 8601, UTC, milliseconds) and DayFormat.string (yyyy-MM-dd).
const stamp = (d = new Date()) => d.toISOString();
const day = (offsetDays = 0) => new Date(Date.now() + offsetDays * 864e5).toISOString().slice(0, 10);
const sha256 = (buf) => createHash("sha256").update(buf).digest("hex");
// Same as API.percentEncoded: everything but A-Z a-z 0-9 - . _ ~ is %-encoded.
const percentEncoded = (s) => [...Buffer.from(s, "utf8")]
  .map((b) => (/[A-Za-z0-9\-._~]/.test(String.fromCharCode(b)) ? String.fromCharCode(b) : "%" + b.toString(16).toUpperCase().padStart(2, "0")))
  .join("");
const id = () => randomUUID().toLowerCase();

// ---- 1. Log in like SyncEngine.login ----
let token;
{
  const setup = await call("POST", "/v1/auth/setup", {
    json: { setupSecret: SETUP_SECRET, email: EMAIL, password: PASSWORD, name: "Ruben", device: { name: "Setup", platform: "other" } },
  });
  ok([201, 409].includes(setup.status), "account exists (setup 201 or 409)", `status ${setup.status}`);
  const r = await call("POST", "/v1/auth/login", {
    json: { email: EMAIL, password: PASSWORD, device: { name: "Contract check iPhone", platform: "ios", appVersion: "1.0" } },
  });
  ok(r.status === 200 && typeof r.data?.token === "string", "POST /v1/auth/login returns a token", `status ${r.status}`);
  token = r.data.token;
  ok(r.data.device?.platform === "ios", "device registered with platform ios");
}

// ---- 2. One record per collection, shaped as each model's `known` (empty text and false flags left out) ----
const ids = Object.fromEntries(["tasks", "checklists", "partners", "gifts", "budget", "sellItems", "packing", "notes", "documents", "contacts", "newsletters"].map((c) => [c, id()]));
const fileId = id();
const fileBytes = Buffer.from("%PDF-1.4\n% On Mission contract check " + new Date().toISOString() + "\n");
const SETTINGS_ID = "60a98c2f-4004-58e7-bcc2-c88a62377933";
const link = (collection) => ({ collection, id: ids[collection] });

const data = {
  tasks: { title: "Scan passport", notes: "Both pages", status: "todo", area: "visa", priority: "high", dueDate: day(3),
           remindAt: stamp(new Date(Date.now() + 864e5)), checklistId: ids.checklists, order: 1728412345.678,
           links: [link("documents")] },
  checklists: { title: "Carry on the flight", description: "At the border", area: "travel", phase: "departure-week", order: 3 },
  partners: { name: "Anna de Vries", email: "anna@example.com", phone: "+31 6 12345678", stage: "giving", monthlyCents: 2500,
              currency: "EUR", startDate: day(-10), prayer: true, newsletter: true, lastContactAt: day(-2), nextFollowUp: day(5),
              notes: "Met after church", category: "A", nextStep: "Send card", birthday: "1990-04-12" },
  gifts: { partnerId: ids.partners, amountCents: 2500, currency: "EUR", date: day(-1), recurring: true, via: "bank transfer" },
  budget: { kind: "expense", label: "Working Holiday Visa fee", category: "visa", amountCents: 77000, currency: "NZD",
            recurrence: "once", date: day(10), phase: "setup", order: 0 },
  sellItems: { name: "Bike", status: "listed", askingCents: 15000, currency: "EUR", platform: "Marktplaats",
               listingUrl: "https://example.com/bike", location: "Shed" },
  packing: { name: "Rain jacket", bag: "carry-on", category: "clothes", quantity: 1, packed: false, weightGrams: 450, order: 2 },
  notes: { title: "Pray for the visa", body: "That it comes in time.", area: "visa", kind: "prayer", answeredAt: day(0) },
  documents: { title: "Passport", kind: "passport", fileId, fileName: "Paspoort – scan é.pdf", mimeType: "application/pdf",
               sizeBytes: fileBytes.length, sha256: sha256(fileBytes), number: "NX1234567", issuedAt: "2020-03-01",
               expiresAt: "2030-03-01", offline: true, notes: "Valid long enough" },
  contacts: { name: "YWAM Queenstown", role: "Staff coordinator", organisation: "YWAM", email: "hello@example.org" },
  newsletters: { title: "Newsletter 1", number: 1, status: "sent", plannedDate: day(-5), sentAt: stamp(), body: "# Hello", webUrl: "https://example.com/1" },
};
const settingsData = { key: "main", departureDate: "2027-01-05", supportTargetMonthlyCents: 100000, supportMinimumMonthlyCents: 75000,
                       currency: "EUR", nzdPerEur: 1.85, averageGiftCents: 2500 };

// ---- 3. Upload the vault file first (SyncEngine.uploadFiles: HEAD, then PUT with Content-Type, X-File-Name, X-Sha256) ----
{
  const head = await call("HEAD", `/v1/files/${fileId}`, { token });
  ok(head.status === 404, "HEAD before upload says 404 (upload needed)", `status ${head.status}`);
  const bad = await call("PUT", `/v1/files/${fileId}`, {
    token, body: fileBytes, headers: { "Content-Type": "application/pdf", "X-Sha256": "0".repeat(64) },
  });
  ok(bad.status === 400 && bad.data?.error?.code === "checksum_mismatch", "a wrong X-Sha256 is refused (header is checked)");
  const put = await call("PUT", `/v1/files/${fileId}`, {
    token, body: fileBytes,
    headers: { "Content-Type": "application/pdf", "X-File-Name": percentEncoded(data.documents.fileName), "X-Sha256": sha256(fileBytes) },
  });
  ok(put.status === 201, "PUT /v1/files/{fileId} stores the file", `status ${put.status}`);
  ok(put.data?.fileName === data.documents.fileName, "X-File-Name round-trips (percent-encoded non-ASCII)", JSON.stringify(put.data?.fileName));
  ok(put.data?.sha256 === sha256(fileBytes) && put.data?.sizeBytes === fileBytes.length, "server sha256 and size match the record's");
  const head2 = await call("HEAD", `/v1/files/${fileId}`, { token });
  ok(head2.status === 200, "HEAD after upload says 200 (upload skipped next time)");
  const get = await call("GET", `/v1/files/${fileId}`, { token });
  ok(get.status === 200 && sha256(get.buf) === data.documents.sha256, "GET returns the same bytes (DocumentFiles.store checksum passes)");
}

// ---- 4. Push everything in one POST /v1/sync, as SyncEngine.collectChanges builds it ----
const now = stamp();
const changes = Object.entries(data).map(([collection, d]) => ({ id: ids[collection], collection, updatedAt: now, deletedAt: null, data: d }));
changes.push({ id: SETTINGS_ID, collection: "settings", updatedAt: now, deletedAt: null, data: settingsData });
// A tombstone, as Store.delete + collectChanges send it: last data along, deletedAt = updatedAt = now.
const goneId = id();
const goneData = { title: "Delete me", status: "todo", area: "other", priority: "normal", order: 0 };
{
  const first = await call("POST", "/v1/sync", { token, json: { cursor: null, changes: [{ id: goneId, collection: "tasks", updatedAt: stamp(new Date(Date.now() - 1000)), deletedAt: null, data: goneData }], limit: 500 } });
  ok(first.status === 200 && first.data.accepted.length === 1, "record to delete later was stored");
}
changes.push({ id: goneId, collection: "tasks", updatedAt: now, deletedAt: now, data: goneData });

let cursor = null;
{
  const r = await call("POST", "/v1/sync", { token, json: { cursor: null, changes, limit: 500 } });
  ok(r.status === 200, "POST /v1/sync accepted the request", `status ${r.status}`);
  const rejected = r.data?.rejected ?? [];
  ok(rejected.length === 0, `all ${changes.length} changes accepted (one per collection + settings + tombstone)`,
     rejected.length ? JSON.stringify(rejected.map((x) => [x.id, x.reason, x.message])) : `accepted ${r.data.accepted.length}`);
  for (const key of ["cursor", "hasMore", "resetRequired", "serverTime", "changes", "accepted", "rejected"]) {
    ok(key in (r.data ?? {}), `SyncResponse has "${key}"`);
  }
  ok(typeof r.data.cursor === "string", "cursor is a string (stored as String? in UserDefaults)");
}

// ---- 5. Pull everything back like a second device and compare data byte for byte ----
{
  const pulled = new Map();
  let more = true;
  while (more) {
    const r = await call("POST", "/v1/sync", { token, json: { cursor, changes: [], limit: 500 } });
    for (const rec of r.data.changes) pulled.set(rec.id, rec);
    cursor = r.data.cursor;
    more = r.data.hasMore;
  }
  for (const c of changes) {
    const rec = pulled.get(c.id);
    const same = rec && JSON.stringify(sortKeys(rec.data)) === JSON.stringify(sortKeys(c.data));
    ok(same && rec.updatedAt === c.updatedAt && (rec.deletedAt ?? null) === c.deletedAt,
       `${c.collection}${c.deletedAt ? " (tombstone)" : ""} comes back unchanged`, rec ? "" : "missing");
  }
  const t = pulled.get(goneId);
  ok(t && typeof t.deletedAt === "string", "tombstone arrives with deletedAt (other devices delete it)");
}

// ---- 6. Stale conflict: an older edit loses and the server copy comes back in `current` ----
{
  const older = stamp(new Date(Date.now() - 60_000));
  const r = await call("POST", "/v1/sync", {
    token, json: { cursor, changes: [{ id: ids.tasks, collection: "tasks", updatedAt: older, deletedAt: null, data: { ...data.tasks, title: "Old edit" } }], limit: 500 },
  });
  const rej = r.data?.rejected?.[0];
  ok(rej?.reason === "stale" && rej?.current?.data?.title === data.tasks.title,
     "older edit is rejected as stale with the server's current record (app replaces its copy)");
}

// ---- 7. A tombstone that loses to a newer server edit brings the record back ----
{
  const older = stamp(new Date(Date.now() - 60_000));
  const r = await call("POST", "/v1/sync", {
    token, json: { cursor, changes: [{ id: ids.notes, collection: "notes", updatedAt: older, deletedAt: older, data: data.notes }], limit: 500 },
  });
  const rej = r.data?.rejected?.[0];
  ok(rej?.reason === "stale" && rej?.current && rej.current.deletedAt === null, "a late delete is rejected stale; current is live (app restores it)");
}

// ---- 8. The bundled seed (Resources/seed-records.json) pushed as-is ----
{
  const seed = JSON.parse(readFileSync(resolve(here, "../OnMission/Resources/seed-records.json"), "utf8"));
  const r = await call("POST", "/v1/sync", { token, json: { cursor, changes: seed.records, limit: 1 } });
  const invalid = (r.data?.rejected ?? []).filter((x) => x.reason !== "stale");
  const stale = (r.data?.rejected ?? []).filter((x) => x.reason === "stale");
  ok(r.status === 200 && invalid.length === 0, `seed: ${seed.records.length} records, none invalid`,
     `accepted ${r.data?.accepted?.length}, stale ${stale.length} (stale = server already has a newer edit; fine)`);
  const allIdsOk = seed.records.every((x) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(x.id));
  ok(allIdsOk, "seed ids are lowercase UUIDs");
  const settings = seed.records.find((x) => x.collection === "settings");
  ok(settings?.id === SETTINGS_ID, "seed settings use MissionSettings.mainID");
}

// ---- 9. Devices list decodes into API.Device (id, name, platform, lastSeenAt, current) ----
{
  const r = await call("GET", "/v1/devices", { token });
  const me = r.data?.devices?.find((d) => d.current);
  ok(r.status === 200 && me && typeof me.id === "string" && me.platform === "ios" && "lastSeenAt" in me, "GET /v1/devices has the current device");
}

// ---- 10. Old file deleted after a replace (deleteOldServerFiles), and logout ----
{
  const del = await call("DELETE", `/v1/files/${fileId}`, { token });
  ok(del.status === 204, "DELETE /v1/files/{fileId} works");
  const out = await call("POST", "/v1/auth/logout", { token });
  ok(out.status === 204, "POST /v1/auth/logout");
  const after = await call("GET", "/v1/me", { token });
  ok(after.status === 401 && typeof after.data?.error?.message === "string", "a logged-out token gets 401 with an error message");
}

console.log(failures ? `\n${failures} check(s) failed.` : "\nAll checks passed.");
process.exit(failures ? 1 : 0);

function sortKeys(v) {
  if (Array.isArray(v)) return v.map(sortKeys);
  if (v && typeof v === "object") return Object.fromEntries(Object.keys(v).sort().map((k) => [k, sortKeys(v[k])]));
  return v;
}
