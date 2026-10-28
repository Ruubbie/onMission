#!/usr/bin/env node
// Gateway: read and change your mission data from a terminal (or by asking Claude Code, which runs this).
// Everything goes through the API (../../api/openapi.yaml), so the iPhone, Windows and web apps pick changes up on
// their next sync, and last-writer-wins works as usual. Node 22+, no dependencies.
//
//   node tools/gateway.mjs login [--url URL] [--profile NAME]      log in once; saves a device token
//   node tools/gateway.mjs whoami | collections | schema <collection> | summary
//   node tools/gateway.mjs list <collection> [--where k=v] [--where k!=v] [--search text] [--sort field] [--fields a,b] [--deleted]
//   node tools/gateway.mjs get <collection> <id>
//   node tools/gateway.mjs add <collection> <json | @file.json | ->     object, or an array to add many at once
//   node tools/gateway.mjs update <collection> <id> <json | @file | ->  merges fields; a null value removes the field
//   node tools/gateway.mjs delete <collection> <id>                     soft delete (other devices hear about it)
//   node tools/gateway.mjs restore <collection> <id>                    undo a delete
//   node tools/gateway.mjs export [file]
//
// <id> may be the first few characters of an id, as long as only one record matches.
// Every command prints JSON. Every write is appended to ~/.missie/gateway-log.jsonl with the record before and after.
// Settings live in ~/.missie/gateway.json ({ active, profiles: { name: { url, token } } }).
// MISSIE_URL + MISSIE_TOKEN override it; --profile picks another saved login (e.g. "local" vs "live").

import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { randomUUID } from "node:crypto";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

const here = dirname(fileURLToPath(import.meta.url));
const CONTRACT = resolve(here, "../../api/openapi.yaml");
const HOME = join(homedir(), ".missie");
const CONFIG = join(HOME, "gateway.json");
const LOG = join(HOME, "gateway-log.jsonl");
const DEFAULT_URL = "http://localhost:8787";
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

// Collection -> schema name in components.schemas.
const SCHEMA_OF = {
  tasks: "Task", checklists: "Checklist", partners: "Partner", gifts: "Gift", budget: "BudgetEntry",
  sellItems: "SellItem", packing: "PackingItem", notes: "Note", documents: "Document", contacts: "Contact",
  newsletters: "Newsletter", settings: "Setting",
};

class Fail extends Error {}

// ---------- contract ----------

// Reads the field rules for every collection out of openapi.yaml. The schemas there are written one property per
// line in flow style (`name: { type: string, enum: [a, b] }`), which is all this needs to understand.
function loadSchemas() {
  const lines = readFileSync(CONTRACT, "utf8").split(/\r?\n/);
  const start = lines.findIndex((l) => l === "  schemas:");
  const blocks = {};
  let name = null;
  for (const line of lines.slice(start + 1)) {
    if (/^\S/.test(line) || /^  \S/.test(line)) break;
    const m = line.match(/^    (\w+):\s*$/);
    if (m) { name = m[1]; blocks[name] = []; continue; }
    if (name) blocks[name].push(line);
  }
  const list = (s) => s.split(",").map((x) => x.trim().replace(/^["']|["']$/g, "")).filter(Boolean);
  const enumOf = (n) => { const l = blocks[n]?.find((x) => /^\s+enum: \[/.test(x)); return l ? list(l.match(/\[(.*)\]/)[1]) : null; };
  const area = enumOf("Area");
  const collections = enumOf("Collection");

  const field = (body) => {
    const type = body.match(/^type: (\w+)/)?.[1];
    if (type === "array") return { type: "array", items: field(body.match(/items: \{ (.*?) \}/)?.[1] ?? "") };
    const ref = body.match(/\$ref: "#\/components\/schemas\/(\w+)"/)?.[1];
    if (ref === "Area") return { type: "string", enum: area };
    if (ref === "Date") return { type: "date" };
    if (ref === "Timestamp") return { type: "timestamp" };
    if (ref === "Uuid") return { type: "uuid" };
    if (ref === "Link") return { type: "link" };
    const en = body.match(/enum: \[([^\]]*)\]/)?.[1];
    return { type: type ?? "any", ...(en ? { enum: list(en) } : {}) };
  };
  const propsOf = (n) => {
    const out = {};
    let required = [];
    for (const l of blocks[n] ?? []) {
      const r = l.match(/^\s+required: \[(.*)\]/);
      if (r) required = list(r[1]);
      const p = l.match(/^\s{8,14}(\w+): \{ (.*) \}\s*$/);
      if (p && p[1] !== "items") out[p[1]] = field(p[2]);
    }
    return { required, props: out };
  };
  const common = propsOf("Common").props;
  const schemas = {};
  for (const [c, n] of Object.entries(SCHEMA_OF)) {
    const s = propsOf(n);
    const usesCommon = (blocks[n] ?? []).some((l) => l.includes("#/components/schemas/Common"));
    schemas[c] = { required: s.required, props: usesCommon ? { ...common, ...s.props } : s.props };
  }
  return { schemas, collections: collections ?? Object.keys(SCHEMA_OF) };
}

function check(value, spec, path, errs) {
  const fail = (m) => errs.push(`${path} ${m}`);
  switch (spec.type) {
    case "string":
      if (typeof value !== "string") return fail("must be text");
      if (spec.enum && !spec.enum.includes(value)) fail(`must be one of: ${spec.enum.join(", ")} (got "${value}")`);
      return;
    case "integer": if (!Number.isSafeInteger(value)) fail("must be a whole number (amounts are in cents)"); return;
    case "number": if (typeof value !== "number" || !Number.isFinite(value)) fail("must be a number"); return;
    case "boolean": if (typeof value !== "boolean") fail("must be true or false"); return;
    case "uuid": if (typeof value !== "string" || !UUID_RE.test(value)) fail("must be a lowercase UUID"); return;
    case "date": if (typeof value !== "string" || !DATE_RE.test(value) || Number.isNaN(Date.parse(value))) fail("must be YYYY-MM-DD"); return;
    case "timestamp": if (typeof value !== "string" || Number.isNaN(Date.parse(value)) || !value.includes("T")) fail("must be an ISO timestamp"); return;
    case "array":
      if (!Array.isArray(value)) return fail("must be a list");
      value.forEach((v, i) => check(v, spec.items, `${path}[${i}]`, errs));
      return;
    case "link":
      if (!value || typeof value !== "object" || !value.collection || !UUID_RE.test(value.id ?? "")) fail("must be { collection, id, label? }");
      return;
  }
}

// Returns { errors, warnings } for a full data object.
function validate(collection, data, schemas) {
  const s = schemas[collection];
  const errors = [];
  const warnings = [];
  if (!data || typeof data !== "object" || Array.isArray(data)) return { errors: ["data must be a JSON object"], warnings };
  for (const k of s.required) if (data[k] === undefined || data[k] === null || data[k] === "") errors.push(`${k} is required`);
  for (const [k, v] of Object.entries(data)) {
    if (s.props[k]) check(v, s.props[k], k, errors);
    else warnings.push(`${k} is not in the ${collection} schema; the apps will ignore it`);
  }
  return { errors, warnings };
}

// ---------- config + http ----------

function readConfig() {
  try { return JSON.parse(readFileSync(CONFIG, "utf8")); } catch { return { active: "default", profiles: {} }; }
}

function writeConfig(cfg) {
  mkdirSync(HOME, { recursive: true });
  writeFileSync(CONFIG, JSON.stringify(cfg, null, 2), { mode: 0o600 });
}

function connection(profile) {
  if (process.env.MISSIE_TOKEN) return { url: process.env.MISSIE_URL || DEFAULT_URL, token: process.env.MISSIE_TOKEN, profile: "env" };
  const cfg = readConfig();
  const name = profile || cfg.active || "default";
  const p = cfg.profiles?.[name];
  if (!p?.token) throw new Fail(`Not logged in${name !== "default" ? ` as "${name}"` : ""}. Run: node tools/gateway.mjs login --url ${p?.url || (name === "local" ? DEFAULT_URL : "https://api.hesent.me")}${profile ? ` --profile ${profile}` : ""}`);
  return { ...p, profile: name };
}

async function call(conn, method, path, json) {
  const headers = { Authorization: `Bearer ${conn.token}` };
  if (json !== undefined) headers["Content-Type"] = "application/json";
  let res;
  try {
    res = await fetch(conn.url.replace(/\/$/, "") + path, { method, headers, body: json === undefined ? undefined : JSON.stringify(json) });
  } catch (e) {
    throw new Fail(`Can't reach ${conn.url} (${e.cause?.code || e.message}). Is the server running?`);
  }
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  if (res.status === 401) throw new Fail(`The saved login for "${conn.profile}" no longer works (device removed?). Log in again.`);
  return { status: res.status, data };
}

async function must(conn, method, path, json) {
  const r = await call(conn, method, path, json);
  if (r.status >= 400) throw new Fail(`${method} ${path} -> ${r.status}: ${r.data?.error?.message ?? JSON.stringify(r.data)}`);
  return r.data;
}

function ask(question, hidden = false) {
  return new Promise((done) => {
    const rl = createInterface({ input: process.stdin, output: process.stdout, terminal: process.stdin.isTTY });
    if (hidden && process.stdin.isTTY) rl._writeToOutput = (s) => { if (s.startsWith(question)) process.stdout.write(s); };
    rl.question(question, (a) => { rl.close(); if (hidden && process.stdin.isTTY) process.stdout.write("\n"); done(a); });
  });
}

// ---------- helpers ----------

const stamp = () => new Date().toISOString();
const flat = (r) => ({ id: r.id, ...r.data, ...(r.deletedAt ? { deletedAt: r.deletedAt } : {}) });
const print = (v) => process.stdout.write(JSON.stringify(v, null, 2) + "\n");

function readInput(arg) {
  if (arg === undefined) throw new Fail("Give the data as JSON, @file.json, or - for stdin.");
  const text = arg === "-" ? readFileSync(0, "utf8") : arg.startsWith("@") ? readFileSync(arg.slice(1), "utf8") : arg;
  try { return JSON.parse(text); } catch (e) { throw new Fail(`That isn't valid JSON: ${e.message}`); }
}

function needCollection(c, collections) {
  if (!c) throw new Fail(`Name a collection: ${collections.join(", ")}`);
  if (!SCHEMA_OF[c]) throw new Fail(`No collection "${c}". Pick one of: ${collections.join(", ")}`);
  return c;
}

// Accepts a full id or a unique prefix of one.
async function resolveId(conn, collection, id) {
  if (!id) throw new Fail("Give the record id (or its first few characters).");
  id = id.toLowerCase();
  if (UUID_RE.test(id)) return id;
  const { records } = await must(conn, "GET", `/v1/records/${collection}?includeDeleted=true`);
  const hits = records.filter((r) => r.id.startsWith(id));
  if (hits.length === 1) return hits[0].id;
  if (!hits.length) throw new Fail(`No ${collection} record starts with "${id}".`);
  throw new Fail(`"${id}" matches ${hits.length} ${collection} records; use more characters.`);
}

function log(op, collection, id, before, after) {
  mkdirSync(HOME, { recursive: true });
  appendFileSync(LOG, JSON.stringify({ at: stamp(), op, collection, id, before: before ?? null, after: after ?? null }) + "\n");
}

function guard(collection, data, schemas) {
  const { errors, warnings } = validate(collection, data, schemas);
  if (errors.length) throw new Fail(`Not saved. ${collection}: ${errors.join("; ")}`);
  return warnings;
}

// ---------- commands ----------

const commands = {
  async login(args, opts) {
    const cfg = readConfig();
    const name = opts.profile || cfg.active || "default";
    const url = (opts.url || cfg.profiles?.[name]?.url || DEFAULT_URL).replace(/\/$/, "");
    let token = opts.token;
    if (!token) {
      const email = opts.email || (await ask("Email: "));
      const password = await ask("Password: ", true);
      const res = await fetch(url + "/v1/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password, device: { name: "Claude gateway", platform: "other", appVersion: "gateway" } }),
      }).catch((e) => { throw new Fail(`Can't reach ${url} (${e.cause?.code || e.message}).`); });
      const body = await res.json().catch(() => null);
      if (!res.ok) throw new Fail(`Login failed (${res.status}): ${body?.error?.message ?? "no details"}`);
      token = body.token;
    }
    cfg.profiles = { ...cfg.profiles, [name]: { url, token } };
    cfg.active = name;
    writeConfig(cfg);
    const me = await must({ url, token, profile: name }, "GET", "/v1/me");
    print({ loggedIn: true, profile: name, url, user: me.user?.email ?? me.email, savedTo: CONFIG });
  },

  async use([name]) {
    const cfg = readConfig();
    if (!cfg.profiles?.[name]) throw new Fail(`No saved login "${name}". Saved: ${Object.keys(cfg.profiles ?? {}).join(", ") || "none"}`);
    cfg.active = name;
    writeConfig(cfg);
    print({ active: name, url: cfg.profiles[name].url });
  },

  async whoami(args, opts) {
    const conn = connection(opts.profile);
    print({ profile: conn.profile, url: conn.url, ...(await must(conn, "GET", "/v1/me")) });
  },

  async collections(args, opts, { schemas }) {
    print(Object.fromEntries(Object.entries(schemas).map(([c, s]) => [c, { required: s.required }])));
  },

  async schema([collection], opts, { schemas, collections }) {
    needCollection(collection, collections);
    const s = schemas[collection];
    const describe = (f) => f.type === "array" ? `list of ${describe(f.items)}` : f.enum ? f.enum.join(" | ") : f.type;
    print({ collection, required: s.required, fields: Object.fromEntries(Object.entries(s.props).map(([k, f]) => [k, describe(f)])) });
  },

  async summary(args, opts) {
    print(await must(connection(opts.profile), "GET", "/v1/summary"));
  },

  async list([collection], opts, { collections }) {
    needCollection(collection, collections);
    const conn = connection(opts.profile);
    const { records } = await must(conn, "GET", `/v1/records/${collection}${opts.deleted ? "?includeDeleted=true" : ""}`);
    let rows = records.map(flat);
    for (const w of opts.where ?? []) {
      const m = w.match(/^(\w+)(!?=)(.*)$/);
      if (!m) throw new Fail(`--where wants field=value or field!=value, got "${w}"`);
      const [, k, op, v] = m;
      const hit = (r) => String(r[k] ?? "") === v;
      rows = rows.filter((r) => (op === "=" ? hit(r) : !hit(r)));
    }
    if (opts.search) {
      const q = opts.search.toLowerCase();
      rows = rows.filter((r) => Object.values(r).some((v) => typeof v === "string" && v.toLowerCase().includes(q)));
    }
    if (opts.sort) {
      const [k, dir] = opts.sort.split(":");
      rows.sort((a, b) => String(a[k] ?? "￿").localeCompare(String(b[k] ?? "￿")) * (dir === "desc" ? -1 : 1));
    }
    if (opts.fields) {
      const keep = ["id", ...opts.fields.split(",")];
      rows = rows.map((r) => Object.fromEntries(keep.filter((k) => r[k] !== undefined).map((k) => [k, r[k]])));
    }
    print({ collection, count: rows.length, records: rows });
  },

  async get([collection, id], opts, { collections }) {
    needCollection(collection, collections);
    const conn = connection(opts.profile);
    print(await must(conn, "GET", `/v1/records/${collection}/${await resolveId(conn, collection, id)}`));
  },

  async add([collection, input], opts, { schemas, collections }) {
    needCollection(collection, collections);
    const conn = connection(opts.profile);
    const items = [readInput(input)].flat();
    const warnings = [];
    const changes = items.map((data, i) => {
      const w = guard(collection, data, schemas);
      warnings.push(...w.map((x) => (items.length > 1 ? `#${i + 1}: ${x}` : x)));
      return { id: opts.id && items.length === 1 ? opts.id : randomUUID(), collection, updatedAt: stamp(), deletedAt: null, data };
    });
    const res = await must(conn, "POST", "/v1/sync", { changes, cursor: null, limit: 1 });
    const ok = new Set(res.accepted.map((a) => a.id));
    const added = changes.filter((c) => ok.has(c.id));
    for (const c of added) log("add", collection, c.id, null, c.data);
    print({ added: added.map((c) => ({ id: c.id, ...c.data })), rejected: res.rejected, warnings });
  },

  async update([collection, id, input], opts, { schemas, collections }) {
    needCollection(collection, collections);
    const conn = connection(opts.profile);
    id = await resolveId(conn, collection, id);
    const patch = readInput(input);
    if (!patch || typeof patch !== "object" || Array.isArray(patch)) throw new Fail("update wants a JSON object of fields to change.");
    const cur = await must(conn, "GET", `/v1/records/${collection}/${id}`);
    if (cur.deletedAt) throw new Fail(`That ${collection} record is deleted. Run restore first.`);
    const data = { ...cur.data };
    for (const [k, v] of Object.entries(patch)) { if (v === null) delete data[k]; else data[k] = v; }
    const warnings = guard(collection, data, schemas);
    const r = await call(conn, "PUT", `/v1/records/${collection}/${id}`, { updatedAt: stamp(), data });
    if (r.status === 409) throw new Fail("Another device saved a newer version a moment ago. Read it again and retry.");
    if (r.status >= 400) throw new Fail(`Not saved: ${r.data?.error?.message ?? r.status}`);
    log("update", collection, id, cur.data, r.data.data);
    print({ updated: flat(r.data), changed: Object.keys(patch), warnings });
  },

  async delete([collection, id], opts, { collections }) {
    needCollection(collection, collections);
    const conn = connection(opts.profile);
    id = await resolveId(conn, collection, id);
    const before = await must(conn, "GET", `/v1/records/${collection}/${id}`);
    const after = await must(conn, "DELETE", `/v1/records/${collection}/${id}`);
    log("delete", collection, id, before.data, null);
    print({ deleted: flat(after), undo: `node tools/gateway.mjs restore ${collection} ${id}` });
  },

  async restore([collection, id], opts, { collections }) {
    needCollection(collection, collections);
    const conn = connection(opts.profile);
    id = await resolveId(conn, collection, id);
    const cur = await must(conn, "GET", `/v1/records/${collection}/${id}`);
    if (!cur.deletedAt) return print({ restored: flat(cur), note: "It wasn't deleted." });
    // Must be newer than the delete marker, or last-writer-wins keeps it deleted.
    const t = Math.max(Date.now(), Date.parse(cur.updatedAt) + 1);
    const r = await must(conn, "PUT", `/v1/records/${collection}/${id}`, { updatedAt: new Date(t).toISOString(), deletedAt: null, data: cur.data });
    log("restore", collection, id, null, r.data);
    print({ restored: flat(r) });
  },

  async export([file], opts) {
    const data = await must(connection(opts.profile), "GET", "/v1/export");
    if (!file) return print(data);
    writeFileSync(file, JSON.stringify(data, null, 2));
    print({ savedTo: resolve(file) });
  },
};

// ---------- main ----------

const { values: opts, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    profile: { type: "string" }, url: { type: "string" }, email: { type: "string" }, token: { type: "string" },
    where: { type: "string", multiple: true }, search: { type: "string" }, sort: { type: "string" },
    fields: { type: "string" }, deleted: { type: "boolean" }, id: { type: "string" }, help: { type: "boolean", short: "h" },
  },
});
const [cmd, ...args] = positionals;

try {
  if (!cmd || opts.help || !commands[cmd]) {
    const usage = readFileSync(fileURLToPath(import.meta.url), "utf8").split("\n").slice(1, 22).map((l) => l.replace(/^\/\/ ?/, "")).join("\n");
    process.stdout.write(usage + "\n");
    process.exit(cmd && !commands[cmd] ? 1 : 0);
  }
  if (!existsSync(CONTRACT)) throw new Fail(`Can't find the API contract at ${CONTRACT}.`);
  await commands[cmd](args, opts, loadSchemas());
} catch (e) {
  if (!(e instanceof Fail)) throw e;
  process.stderr.write(JSON.stringify({ error: e.message }) + "\n");
  process.exit(1);
}
