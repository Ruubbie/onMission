#!/usr/bin/env node
// Seed / import Ruben's starter dataset into the Mission App API (see ../../api/openapi.yaml).
//
//   node seed/seed.mjs --url http://localhost:8787 --token TOKEN [--dry-run] [--file seed/seed-data.json]
//   API_URL=... API_TOKEN=... node seed/seed.mjs
//
// Node 22+, no dependencies.
//
// - Every record id is a deterministic UUIDv5 of "<collection>:<key>" in SEED_NAMESPACE, so re-running
//   never duplicates. The shared settings record is uuidv5("settings:main") (printed below).
// - data.checklistId, data.parentTaskId, data.contactId (a key) and data.links[] ({collection, key})
//   are resolved to those ids.
// - updatedAt is fixed in the past (SEED_UPDATED_AT). The server is last-writer-wins on updatedAt, so
//   anything Ruben edited in the app is newer and wins; seeding again only fills in what is missing.
//   Records already on the server with the same timestamp come back as rejected (stale): that's expected.
// - --dry-run validates every record against the collection schemas and prints a summary; nothing is sent.

import { createHash } from "node:crypto";
import { readFileSync, realpathSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

const SEED_UPDATED_AT = "2026-10-08T00:00:00.000Z";
const BATCH = 200;
// = uuidv5(URL namespace 6ba7b811-9dad-11d1-80b4-00c04fd430c8, "https://api.rubenonmission.nl/seed").
// Never change it: every seeded id (and the settings:main id the apps use) depends on it.
const SEED_NAMESPACE = "5d2e260a-4981-59b8-9217-421fb993f1d5";

// ---------- UUIDv5 ----------
const uuidBytes = (u) => Buffer.from(u.replace(/-/g, ""), "hex");
export function uuidv5(name, namespace = SEED_NAMESPACE) {
  const h = createHash("sha1").update(uuidBytes(namespace)).update(Buffer.from(name, "utf8")).digest();
  const b = h.subarray(0, 16);
  b[6] = (b[6] & 0x0f) | 0x50;
  b[8] = (b[8] & 0x3f) | 0x80;
  const x = b.toString("hex");
  return `${x.slice(0, 8)}-${x.slice(8, 12)}-${x.slice(12, 16)}-${x.slice(16, 20)}-${x.slice(20)}`;
}
export const seedId = (collection, key) => uuidv5(`${collection}:${key}`);

// ---------- Schemas (mirrors components.schemas in openapi.yaml) ----------
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const TS_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
const COLLECTIONS = ["tasks", "checklists", "partners", "budget", "sellItems", "packing", "notes", "documents", "contacts", "settings"];
const AREA = ["visa", "admin", "finance", "support", "newsletter", "selling", "packing", "housing", "health", "insurance", "church", "travel", "ywam", "personal", "other"];

const str = { type: "string" }, int = { type: "integer" }, num = { type: "number" }, bool = { type: "boolean" };
const uuid = { type: "uuid" }, date = { type: "date" }, ts = { type: "timestamp" };
const en = (...values) => ({ type: "string", enum: values });
const area = { type: "string", enum: AREA };
const common = {
  links: { type: "links" },
  tags: { type: "array", items: str },
  fileIds: { type: "array", items: uuid },
  order: num,
};
const S = {
  tasks: { required: ["title", "status"], props: {
    title: str, notes: str, status: en("todo", "doing", "waiting", "done", "skipped"), area,
    priority: en("low", "normal", "high"), dueDate: date, remindAt: ts, completedAt: ts,
    checklistId: uuid, parentTaskId: uuid, waitingOn: str, sourceUrl: str } },
  checklists: { required: ["title"], props: {
    title: str, description: str, area, phase: en("now", "before-departure", "departure-week", "arrival", "ongoing"), archived: bool } },
  partners: { required: ["name", "stage"], props: {
    name: str, contactId: uuid, email: str, phone: str, church: str,
    stage: en("idea", "to-ask", "asked", "thinking", "committed", "giving", "declined", "paused"),
    monthlyCents: int, oneOffCents: int, currency: str, startDate: date, prayer: bool, newsletter: bool,
    lastContactAt: date, nextFollowUp: date, thankedAt: date, notes: str } },
  budget: { required: ["kind", "label", "amountCents", "currency"], props: {
    kind: en("income", "expense", "saving"), label: str, category: str, amountCents: int, currency: str,
    recurrence: en("once", "monthly", "yearly"), date, phase: en("setup", "monthly"), paid: bool, notes: str } },
  sellItems: { required: ["name", "status"], props: {
    name: str, status: en("decide", "to-list", "listed", "reserved", "sold", "given-away", "keep", "store"),
    askingCents: int, soldCents: int, currency: str, platform: str, listingUrl: str, buyer: str,
    pickupDate: date, location: str, notes: str } },
  packing: { required: ["name"], props: {
    name: str, bag: en("checked", "carry-on", "personal", "ship", "buy-there", "leave"), category: str,
    quantity: int, packed: bool, weightGrams: int, notes: str } },
  notes: { required: ["title"], props: {
    title: str, body: str, area, pinned: bool, kind: en("note", "prayer", "journal", "meeting", "idea"), answeredAt: date } },
  documents: { required: ["title", "kind"], props: {
    title: str, kind: en("passport", "visa", "insurance", "ticket", "id", "bank", "medical", "diploma", "reference", "contract", "receipt", "letter", "other"),
    fileId: uuid, fileName: str, mimeType: str, sizeBytes: int, sha256: str, number: str,
    issuedAt: date, expiresAt: date, offline: bool, notes: str } },
  contacts: { required: ["name"], props: {
    name: str, role: str, organisation: str, email: str, phone: str, address: str, notes: str } },
  settings: { required: ["key"], noCommon: true, props: {
    key: str, departureDate: date, supportTargetMonthlyCents: int, supportMinimumMonthlyCents: int,
    currency: str, nzdPerEur: num, value: { type: "any" } } },
};

function checkValue(v, spec, path, errs) {
  const fail = (m) => errs.push(`${path}: ${m}`);
  switch (spec.type) {
    case "any": return;
    case "string": if (typeof v !== "string") return fail("must be a string");
      if (spec.enum && !spec.enum.includes(v)) fail(`must be one of ${spec.enum.join("|")}, got "${v}"`); return;
    case "integer": if (!Number.isSafeInteger(v)) fail("must be an integer"); return;
    case "number": if (typeof v !== "number" || !Number.isFinite(v)) fail("must be a number"); return;
    case "boolean": if (typeof v !== "boolean") fail("must be a boolean"); return;
    case "uuid": if (typeof v !== "string" || !UUID_RE.test(v)) fail(`must be a lowercase uuid, got ${JSON.stringify(v)}`); return;
    case "date": if (typeof v !== "string" || !DATE_RE.test(v) || isNaN(Date.parse(v + "T00:00:00Z"))) fail(`must be YYYY-MM-DD, got ${JSON.stringify(v)}`); return;
    case "timestamp": if (typeof v !== "string" || !TS_RE.test(v) || isNaN(Date.parse(v))) fail(`must be an ISO timestamp with ms, got ${JSON.stringify(v)}`); return;
    case "array": if (!Array.isArray(v)) return fail("must be an array");
      v.forEach((x, i) => checkValue(x, spec.items, `${path}[${i}]`, errs)); return;
    case "links": if (!Array.isArray(v)) return fail("must be an array");
      v.forEach((l, i) => {
        if (!l || typeof l !== "object") return errs.push(`${path}[${i}]: must be an object`);
        checkValue(l.collection, { type: "string", enum: COLLECTIONS }, `${path}[${i}].collection`, errs);
        checkValue(l.id, uuid, `${path}[${i}].id`, errs);
        if (l.label !== undefined) checkValue(l.label, str, `${path}[${i}].label`, errs);
      }); return;
    default: fail(`unknown spec ${spec.type}`);
  }
}

export function validateRecord(r) {
  const errs = [];
  const where = `${r.collection}/${r.id}`;
  if (typeof r.id !== "string" || !UUID_RE.test(r.id)) errs.push(`${where}: id is not a lowercase uuid`);
  if (!COLLECTIONS.includes(r.collection)) errs.push(`${where}: unknown collection`);
  if (typeof r.updatedAt !== "string" || !TS_RE.test(r.updatedAt)) errs.push(`${where}: bad updatedAt`);
  if (!(r.deletedAt === null || r.deletedAt === undefined || TS_RE.test(r.deletedAt))) errs.push(`${where}: bad deletedAt`);
  const schema = S[r.collection];
  if (!schema) return errs;
  if (!r.data || typeof r.data !== "object" || Array.isArray(r.data)) return [...errs, `${where}: data must be an object`];
  for (const k of schema.required) if (r.data[k] === undefined || r.data[k] === null || r.data[k] === "") errs.push(`${where}: data.${k} is required`);
  const props = schema.noCommon ? schema.props : { ...common, ...schema.props };
  for (const [k, v] of Object.entries(r.data)) {
    if (props[k]) checkValue(v, props[k], `${where} data.${k}`, errs);
    // Unknown fields are allowed by the API; we still flag them here to catch typos in the seed file.
    else errs.push(`${where}: data.${k} is not in the ${r.collection} schema (typo?)`);
  }
  const size = Buffer.byteLength(JSON.stringify(r.data));
  if (size > 256 * 1024) errs.push(`${where}: data is ${size} bytes (max 256 KB)`);
  return errs;
}

// ---------- Build records from seed-data.json ----------
export function buildRecords(items) {
  const errs = [];
  const seen = new Set();
  const exists = (collection, key) => seen.has(`${collection}:${key}`);
  for (const it of items) {
    const k = `${it.collection}:${it.key}`;
    if (!it.key || typeof it.key !== "string") errs.push(`${it.collection}: item without key`);
    else if (seen.has(k)) errs.push(`duplicate key ${k}`);
    seen.add(k);
  }
  const ref = (collection, key, where) => {
    if (typeof key !== "string") { errs.push(`${where}: key must be a string`); return key; }
    if (!exists(collection, key)) errs.push(`${where}: no ${collection} record with key "${key}"`);
    return seedId(collection, key);
  };
  const records = items.map((it) => {
    const where = `${it.collection}:${it.key}`;
    const data = structuredClone(it.data ?? {});
    if (data.checklistId !== undefined) data.checklistId = ref("checklists", data.checklistId, `${where} checklistId`);
    if (data.parentTaskId !== undefined) data.parentTaskId = ref("tasks", data.parentTaskId, `${where} parentTaskId`);
    if (data.contactId !== undefined) data.contactId = ref("contacts", data.contactId, `${where} contactId`);
    if (Array.isArray(data.links)) {
      data.links = data.links.map((l, i) => {
        const out = { collection: l.collection, id: ref(l.collection, l.key, `${where} links[${i}]`) };
        if (l.label) out.label = l.label;
        return out;
      });
    }
    if (it.collection === "settings" && data.key !== it.key) errs.push(`${where}: data.key must equal the item key`);
    return { id: seedId(it.collection, it.key), collection: it.collection, updatedAt: SEED_UPDATED_AT, deletedAt: null, data };
  });
  const ids = new Set();
  for (const r of records) {
    if (ids.has(r.id)) errs.push(`uuid collision ${r.id}`);
    ids.add(r.id);
    errs.push(...validateRecord(r));
  }
  return { records, errors: errs };
}

// ---------- Push ----------
async function push(records, url, token) {
  const base = url.replace(/\/+$/, "");
  let accepted = 0;
  const rejected = {};
  const rejectedIds = [];
  for (let i = 0; i < records.length; i += BATCH) {
    const changes = records.slice(i, i + BATCH);
    const res = await fetch(`${base}/v1/sync`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      // No cursor: the pulled changes in the response are ignored; we only care about accepted/rejected.
      body: JSON.stringify({ changes, limit: 1 }),
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`POST /v1/sync -> HTTP ${res.status}: ${text.slice(0, 500)}`);
    let body;
    try { body = JSON.parse(text); } catch { throw new Error(`POST /v1/sync returned non-JSON: ${text.slice(0, 200)}`); }
    accepted += Array.isArray(body.accepted) ? body.accepted.length : 0;
    for (const r of body.rejected ?? []) {
      rejected[r.reason ?? "unknown"] = (rejected[r.reason ?? "unknown"] ?? 0) + 1;
      if (r.reason !== "stale") rejectedIds.push(`${r.id} (${r.reason}${r.message ? ": " + r.message : ""})`);
    }
    console.log(`  batch ${i / BATCH + 1}: sent ${changes.length}`);
  }
  return { accepted, rejected, rejectedIds };
}

function countBy(records) {
  const c = {};
  for (const r of records) c[r.collection] = (c[r.collection] ?? 0) + 1;
  return c;
}

async function main() {
  const here = dirname(fileURLToPath(import.meta.url));
  const { values } = parseArgs({
    options: {
      url: { type: "string" }, token: { type: "string" }, file: { type: "string" },
      "dry-run": { type: "boolean", default: false }, help: { type: "boolean", short: "h" },
    },
  });
  if (values.help) {
    console.log("Usage: node seed/seed.mjs --url http://localhost:8787 --token TOKEN [--dry-run] [--file seed-data.json]\nEnv: API_URL, API_TOKEN");
    return;
  }
  const file = resolve(values.file ?? `${here}/seed-data.json`);
  const items = JSON.parse(readFileSync(file, "utf8"));
  if (!Array.isArray(items)) throw new Error(`${file} must contain an array of {collection, key, data}`);

  const { records, errors } = buildRecords(items);
  const counts = countBy(records);
  console.log(`Seed file: ${file}`);
  console.log(`Records: ${records.length}`);
  for (const [c, n] of Object.entries(counts)) console.log(`  ${c.padEnd(11)} ${n}`);
  console.log(`settings:main id: ${seedId("settings", "main")}`);
  console.log(`updatedAt for all records: ${SEED_UPDATED_AT}`);

  if (errors.length) {
    console.error(`\n${errors.length} validation error(s):`);
    for (const e of errors) console.error(`  - ${e}`);
    process.exitCode = 1;
    return;
  }
  console.log("Validation: OK");

  if (values["dry-run"]) {
    const tasks = records.filter((r) => r.collection === "tasks");
    const withDue = tasks.filter((t) => t.data.dueDate).sort((a, b) => a.data.dueDate.localeCompare(b.data.dueDate));
    console.log(`\nDry run, nothing sent. Tasks with a due date: ${withDue.length}/${tasks.length}` +
      (withDue.length ? ` (first ${withDue[0].data.dueDate}, last ${withDue.at(-1).data.dueDate})` : ""));
    return;
  }

  const url = values.url ?? process.env.API_URL;
  const token = values.token ?? process.env.API_TOKEN;
  if (!url || !token) {
    console.error("\nMissing --url/--token (or API_URL/API_TOKEN). Use --dry-run to only validate.");
    process.exitCode = 2;
    return;
  }
  console.log(`\nPushing to ${url} in batches of ${BATCH}...`);
  const { accepted, rejected, rejectedIds } = await push(records, url, token);
  const nRejected = Object.values(rejected).reduce((a, b) => a + b, 0);
  console.log(`Accepted: ${accepted}`);
  console.log(`Rejected: ${nRejected}${nRejected ? " " + JSON.stringify(rejected) : ""}`);
  if (rejected.stale) console.log("  (stale = the server already has this record at the same or a newer updatedAt, e.g. your own edits; left untouched)");
  for (const r of rejectedIds) console.log(`  - ${r}`);
  if (rejectedIds.length) process.exitCode = 1;
}

const isMain = (() => { try { return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url)); } catch { return false; } })();
if (isMain) {
  main().catch((e) => { console.error(e.message ?? e); process.exitCode = 1; });
}
