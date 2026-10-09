// End-to-end tests for the Mission App API (api/openapi.yaml).
// Runs against a live server; uses only Node 22 built-ins.
//
//   BASE_URL=http://localhost:8787 SETUP_SECRET=dev-setup-secret node --test test/
//
// The server may start empty: the first test runs POST /v1/auth/setup, or logs in
// when the account already exists (409). Every test uses fresh UUIDs, so the suite
// can be re-run against the same database.

import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID, createHash } from "node:crypto";

const BASE = (process.env.BASE_URL || "http://localhost:8787").replace(/\/$/, "");
const SETUP_SECRET = process.env.SETUP_SECRET || "dev-setup-secret";
const EMAIL = "test@example.com";
const PASSWORD = "correct horse battery";
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

// ---------- helpers ----------

async function api(method, path, { token, json, body, headers = {} } = {}) {
  const h = { ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  if (json !== undefined) {
    h["Content-Type"] = "application/json";
    body = JSON.stringify(json);
  }
  const res = await fetch(BASE + path, { method, headers: h, body });
  const text = method === "HEAD" ? "" : await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { status: res.status, headers: res.headers, data, text };
}

function expectStatus(res, status, label = "") {
  assert.equal(res.status, status, `${label} expected ${status}, got ${res.status}: ${res.text}`);
}

function assertError(res) {
  assert.equal(typeof res.data?.error?.code, "string", `error body missing code: ${res.text}`);
  assert.equal(typeof res.data?.error?.message, "string", `error body missing message: ${res.text}`);
}

async function login(deviceName, password = PASSWORD) {
  return api("POST", "/v1/auth/login", {
    json: { email: EMAIL, password, device: { name: deviceName, platform: "other", appVersion: "test" } },
  });
}

async function loginOk(deviceName) {
  const r = await login(deviceName);
  expectStatus(r, 200, "login");
  return r.data; // { token, user, space, device }
}

async function sync(token, cursor, changes = [], limit) {
  const json = { cursor: cursor ?? null, changes };
  if (limit) json.limit = limit;
  const r = await api("POST", "/v1/sync", { token, json });
  expectStatus(r, 200, "sync");
  return r.data;
}

// Pull until hasMore is false; returns { cursor, changes }.
async function drain(token, cursor) {
  const all = [];
  for (let i = 0; i < 1000; i++) {
    const r = await sync(token, cursor, [], 1000);
    all.push(...r.changes);
    cursor = r.cursor;
    if (!r.hasMore) return { cursor, changes: all };
  }
  throw new Error("drain did not finish");
}

const iso = (ms) => new Date(ms).toISOString();
const change = (collection, data, updatedAtMs = Date.now(), extra = {}) =>
  ({ id: randomUUID(), collection, updatedAt: iso(updatedAtMs), deletedAt: null, data, ...extra });
const sha256hex = (buf) => createHash("sha256").update(buf).digest("hex");
const stripQuotes = (s) => (s || "").replace(/^W\//, "").replace(/"/g, "");

// Shared state: device A (main) and device B (second device for sync tests).
let A; // session for device A
let B; // session for device B

// ---------- auth ----------

test("health works without auth", async () => {
  const r = await api("GET", "/v1/health");
  expectStatus(r, 200);
  assert.equal(r.data.ok, true);
  assert.equal(typeof r.data.version, "string");
  assert.ok(!Number.isNaN(Date.parse(r.data.time)), "time is a timestamp");
});

test("setup creates the owner account (or it already exists)", async () => {
  const r = await api("POST", "/v1/auth/setup", {
    json: { setupSecret: SETUP_SECRET, email: EMAIL, password: PASSWORD, name: "Ruben",
            device: { name: "Test device A", platform: "other" } },
  });
  if (r.status === 409) {
    A = await loginOk("Test device A");
  } else {
    expectStatus(r, 201, "setup");
    A = r.data;
  }
  assert.equal(typeof A.token, "string");
  assert.ok(A.token.length >= 16);
  assert.equal(A.user.email, EMAIL);
  B = await loginOk("Test device B");
  assert.notEqual(A.token, B.token);
  assert.notEqual(A.device.id, B.device.id);
});

test("setup again returns 409", async () => {
  const r = await api("POST", "/v1/auth/setup", {
    json: { setupSecret: SETUP_SECRET, email: "other@example.com", password: "another password 123", name: "X" },
  });
  expectStatus(r, 409);
  assertError(r);
});

test("401 without token and with a bad token", async () => {
  const none = await api("GET", "/v1/me");
  expectStatus(none, 401, "no token");
  assertError(none);
  const bad = await api("GET", "/v1/me", { token: "not-a-real-token" });
  expectStatus(bad, 401, "bad token");
  const badSync = await api("POST", "/v1/sync", { token: "nope", json: { changes: [] } });
  expectStatus(badSync, 401, "bad token on sync");
});

test("login with wrong password returns 401", async () => {
  const r = await login("Wrong", "definitely the wrong password");
  expectStatus(r, 401);
  assertError(r);
});

test("/v1/me has user, space and device", async () => {
  const r = await api("GET", "/v1/me", { token: A.token });
  expectStatus(r, 200);
  const { user, space, device } = r.data;
  assert.equal(user.email, EMAIL);
  assert.equal(user.name, "Ruben");
  assert.equal(typeof user.id, "string");
  assert.equal(typeof space.id, "string");
  assert.equal(typeof space.name, "string");
  assert.ok(["owner", "editor", "viewer"].includes(space.role));
  assert.equal(device.id, A.device.id);
  assert.equal(typeof device.name, "string");
  assert.equal(typeof device.platform, "string");
  assert.ok(!Number.isNaN(Date.parse(device.createdAt)));
});

test("devices list, and revoking a device makes its token 401", async () => {
  const C = await loginOk("Test device C (to revoke)");
  const list = await api("GET", "/v1/devices", { token: A.token });
  expectStatus(list, 200);
  const ids = list.data.devices.map((d) => d.id);
  assert.ok(ids.includes(A.device.id) && ids.includes(B.device.id) && ids.includes(C.device.id));
  const mine = list.data.devices.find((d) => d.id === A.device.id);
  assert.equal(mine.current, true);
  assert.notEqual(list.data.devices.find((d) => d.id === C.device.id).current, true);

  expectStatus(await api("GET", "/v1/me", { token: C.token }), 200, "C before revoke");
  expectStatus(await api("DELETE", `/v1/devices/${C.device.id}`, { token: A.token }), 204, "revoke");
  expectStatus(await api("GET", "/v1/me", { token: C.token }), 401, "C after revoke");
  const after = await api("GET", "/v1/devices", { token: A.token });
  assert.ok(!after.data.devices.some((d) => d.id === C.device.id), "revoked device still listed");
  expectStatus(await api("DELETE", `/v1/devices/${randomUUID()}`, { token: A.token }), 404, "unknown device");
});

// ---------- sync ----------

test("sync: full download without a cursor", async () => {
  const r = await sync(A.token, null);
  for (const k of ["cursor", "hasMore", "changes", "accepted", "rejected", "serverTime", "resetRequired"]) {
    assert.ok(k in r, `missing ${k}`);
  }
  assert.equal(typeof r.cursor, "string");
  assert.equal(typeof r.hasMore, "boolean");
  assert.equal(r.resetRequired, false);
  assert.ok(Array.isArray(r.changes));
  assert.deepEqual(r.accepted, []);
  assert.deepEqual(r.rejected, []);
  assert.ok(!Number.isNaN(Date.parse(r.serverTime)));
});

test("sync: push on A, pull on B; last writer wins; tombstones propagate", async () => {
  let { cursor: cursorB } = await drain(B.token, null);
  const t0 = Date.now() - 60_000;
  const task = change("tasks", { title: "Apply for Working Holiday Visa", status: "todo", area: "visa" }, t0);

  // A pushes a new task
  const pushA = await sync(A.token, null, [task]);
  assert.equal(pushA.rejected.length, 0, JSON.stringify(pushA.rejected));
  const acc = pushA.accepted.find((a) => a.id === task.id);
  assert.ok(acc && Number.isInteger(acc.seq), "accepted with seq");

  // B pulls it with its cursor
  const pullB = await drain(B.token, cursorB);
  const got = pullB.changes.find((c) => c.id === task.id);
  assert.ok(got, "B received A's task");
  assert.equal(got.collection, "tasks");
  assert.equal(got.data.title, "Apply for Working Holiday Visa");
  assert.equal(got.updatedAt, task.updatedAt);
  assert.equal(got.deletedAt ?? null, null);
  assert.equal(got.updatedBy ?? A.device.id, A.device.id);
  cursorB = pullB.cursor;

  // B pushes an OLDER version -> stale, with the server copy
  const older = { ...task, updatedAt: iso(t0 - 10_000), data: { title: "old title", status: "todo" } };
  const stale = await sync(B.token, cursorB, [older]);
  const rej = stale.rejected.find((x) => x.id === task.id);
  assert.ok(rej, `expected rejection, got ${JSON.stringify(stale)}`);
  assert.equal(rej.reason, "stale");
  assert.equal(rej.current?.data?.title, "Apply for Working Holiday Visa");
  assert.ok(!stale.accepted.some((a) => a.id === task.id));
  cursorB = stale.cursor;

  // B pushes a NEWER version -> wins
  const newer = { ...task, updatedAt: iso(t0 + 10_000), data: { title: "Visa applied", status: "done" } };
  const win = await sync(B.token, cursorB, [newer]);
  assert.ok(win.accepted.some((a) => a.id === task.id), JSON.stringify(win));
  cursorB = win.cursor;
  const rec = await api("GET", `/v1/records/tasks/${task.id}`, { token: A.token });
  expectStatus(rec, 200);
  assert.equal(rec.data.data.title, "Visa applied");
  assert.equal(rec.data.updatedBy ?? B.device.id, B.device.id);

  // A soft-deletes -> B sees a tombstone
  const delAt = iso(t0 + 20_000);
  const del = await sync(A.token, null, [{ ...newer, updatedAt: delAt, deletedAt: delAt }]);
  assert.ok(del.accepted.some((a) => a.id === task.id), JSON.stringify(del));
  const pull2 = await drain(B.token, cursorB);
  const tomb = pull2.changes.find((c) => c.id === task.id);
  assert.ok(tomb, "tombstone pulled");
  assert.ok(tomb.deletedAt && !Number.isNaN(Date.parse(tomb.deletedAt)), "deletedAt set");
});

test("sync: updatedAt far in the future is clamped to server time", async () => {
  const c = change("notes", { title: "time traveller" }, Date.now() + 24 * 3600_000);
  const r = await sync(A.token, null, [c]);
  assert.ok(r.accepted.some((a) => a.id === c.id), JSON.stringify(r.rejected));
  const rec = await api("GET", `/v1/records/notes/${c.id}`, { token: A.token });
  expectStatus(rec, 200);
  const slackMs = 5_000;
  assert.ok(Date.parse(rec.data.updatedAt) <= Date.parse(r.serverTime) + slackMs,
    `updatedAt ${rec.data.updatedAt} not clamped (serverTime ${r.serverTime})`);
});

test("sync: invalid changes are rejected with reason 'invalid', not a 500", async () => {
  const badCollection = change("spaceships", { title: "x" });
  const badId = { ...change("tasks", { title: "x", status: "todo" }), id: "NOT-A-UUID" };
  const upperId = { ...change("tasks", { title: "x", status: "todo" }), id: randomUUID().toUpperCase() };
  const badData = { ...change("tasks", {}), data: "just a string" };
  const arrData = { ...change("tasks", {}), data: [1, 2, 3] };
  const good = change("notes", { title: "valid neighbour" });
  const r = await api("POST", "/v1/sync", {
    token: A.token, json: { changes: [badCollection, badId, upperId, badData, arrData, good] },
  });
  expectStatus(r, 200, "sync with invalid changes");
  for (const bad of [badCollection, badId, upperId, badData, arrData]) {
    const rej = r.data.rejected.find((x) => x.id === bad.id);
    assert.ok(rej, `not rejected: ${JSON.stringify(bad)} -> ${JSON.stringify(r.data.rejected)}`);
    assert.equal(rej.reason, "invalid");
  }
  assert.ok(r.data.accepted.some((a) => a.id === good.id), "valid change in same batch still accepted");
});

test("sync: cursor pagination with limit=2 and hasMore", async () => {
  const { cursor } = await drain(B.token, null);
  const recs = [1, 2, 3].map((n) => change("packing", { name: `item ${n}` }));
  const push = await sync(A.token, null, recs);
  assert.equal(push.accepted.length, 3);

  const p1 = await sync(B.token, cursor, [], 2);
  assert.equal(p1.changes.length, 2);
  assert.equal(p1.hasMore, true);
  const p2 = await sync(B.token, p1.cursor, [], 2);
  assert.equal(p2.changes.length, 1);
  assert.equal(p2.hasMore, false);
  const seen = [...p1.changes, ...p2.changes].map((c) => c.id);
  assert.deepEqual(seen.sort(), recs.map((r) => r.id).sort());
  const seqs = [...p1.changes, ...p2.changes].map((c) => c.seq);
  assert.deepEqual(seqs, [...seqs].sort((a, b) => a - b), "changes oldest first");
  const p3 = await sync(B.token, p2.cursor, [], 2);
  assert.equal(p3.changes.length, 0);
});

test("sync: unknown fields in data roundtrip untouched", async () => {
  const data = {
    title: "Future field test", status: "todo",
    someFutureField: { nested: [1, "two", { three: true }], n: null }, emoji: "🙏 café",
    links: [{ collection: "documents", id: randomUUID(), label: "Passport" }],
  };
  const c = change("tasks", data);
  const r = await sync(A.token, null, [c]);
  assert.ok(r.accepted.some((a) => a.id === c.id));
  const rec = await api("GET", `/v1/records/tasks/${c.id}`, { token: B.token });
  expectStatus(rec, 200);
  assert.deepEqual(rec.data.data, data);
});

// ---------- records REST ----------

test("records: PUT / GET / list / 409 on older / DELETE", async () => {
  const id = randomUUID();
  const t = Date.now() - 30_000;
  const put = await api("PUT", `/v1/records/notes/${id}`, {
    token: A.token, json: { updatedAt: iso(t), data: { title: "REST note", body: "hi", kind: "note" } },
  });
  expectStatus(put, 200, "PUT");
  assert.equal(put.data.id, id);
  assert.equal(put.data.collection, "notes");
  assert.equal(put.data.data.title, "REST note");

  const get = await api("GET", `/v1/records/notes/${id}`, { token: A.token });
  expectStatus(get, 200, "GET");
  assert.equal(get.data.data.body, "hi");

  const list = await api("GET", "/v1/records/notes", { token: A.token });
  expectStatus(list, 200, "list");
  assert.ok(list.data.records.some((r) => r.id === id));

  const old = await api("PUT", `/v1/records/notes/${id}`, {
    token: B.token, json: { updatedAt: iso(t - 5_000), data: { title: "older" } },
  });
  expectStatus(old, 409, "PUT older");
  assert.equal(old.data.id, id);
  assert.equal(old.data.data.title, "REST note", "409 body is the server copy");

  const del = await api("DELETE", `/v1/records/notes/${id}`, { token: A.token });
  expectStatus(del, 200, "DELETE");
  assert.ok(del.data.deletedAt, "tombstone has deletedAt");

  const live = await api("GET", "/v1/records/notes", { token: A.token });
  assert.ok(!live.data.records.some((r) => r.id === id), "deleted record not in live list");
  const withDeleted = await api("GET", "/v1/records/notes?includeDeleted=true", { token: A.token });
  assert.ok(withDeleted.data.records.some((r) => r.id === id), "tombstone in includeDeleted list");
  const getTomb = await api("GET", `/v1/records/notes/${id}`, { token: A.token });
  expectStatus(getTomb, 200, "GET tombstone");
  assert.ok(getTomb.data.deletedAt);

  expectStatus(await api("GET", `/v1/records/notes/${randomUUID()}`, { token: A.token }), 404, "GET missing");
  expectStatus(await api("DELETE", `/v1/records/notes/${randomUUID()}`, { token: A.token }), 404, "DELETE missing");
});

// ---------- files ----------

test("files: upload, HEAD, download, ETag/304, checksum, list, delete", async () => {
  const id = randomUUID();
  const bytes = new Uint8Array(4096).map((_, i) => (i * 31 + 7) & 0xff);
  const sha = sha256hex(bytes);

  const wrong = await api("PUT", `/v1/files/${randomUUID()}`, {
    token: A.token, body: bytes,
    headers: { "Content-Type": "application/pdf", "X-Sha256": "0".repeat(64) },
  });
  expectStatus(wrong, 400, "wrong X-Sha256");

  const put = await api("PUT", `/v1/files/${id}`, {
    token: A.token, body: bytes,
    headers: { "Content-Type": "application/pdf", "X-File-Name": "passport%20scan.pdf", "X-Sha256": sha },
  });
  expectStatus(put, 201, "upload");
  assert.equal(put.data.id, id);
  assert.equal(put.data.sizeBytes, bytes.length);
  assert.equal(put.data.sha256, sha);
  assert.equal(put.data.mimeType, "application/pdf");
  assert.ok(put.data.fileName?.includes("passport"), `fileName: ${put.data.fileName}`);

  expectStatus(await api("HEAD", `/v1/files/${id}`, { token: A.token }), 200, "HEAD");

  const res = await fetch(`${BASE}/v1/files/${id}`, { headers: { Authorization: `Bearer ${B.token}` } });
  assert.equal(res.status, 200);
  assert.match(res.headers.get("content-type") || "", /application\/pdf/);
  const etag = res.headers.get("etag");
  assert.ok(etag, "ETag header present");
  assert.equal(stripQuotes(etag), sha, "ETag is the sha256");
  const down = new Uint8Array(await res.arrayBuffer());
  assert.equal(sha256hex(down), sha, "downloaded bytes identical");

  const cached = await fetch(`${BASE}/v1/files/${id}`, {
    headers: { Authorization: `Bearer ${B.token}`, "If-None-Match": etag },
  });
  assert.equal(cached.status, 304);

  const list = await api("GET", "/v1/files", { token: A.token });
  expectStatus(list, 200, "list files");
  const info = list.data.files.find((f) => f.id === id);
  assert.ok(info, "file listed");
  assert.equal(info.sha256, sha);
  assert.ok(!Number.isNaN(Date.parse(info.uploadedAt)));

  expectStatus(await api("DELETE", `/v1/files/${id}`, { token: A.token }), 204, "delete file");
  expectStatus(await api("HEAD", `/v1/files/${id}`, { token: A.token }), 404, "HEAD after delete");
  expectStatus(await api("GET", `/v1/files/${id}`, { token: A.token }), 404, "GET after delete");
});

// ---------- summary & export ----------

test("summary reflects settings, committed partner and overdue task", async () => {
  const before = await api("GET", "/v1/summary", { token: A.token });
  expectStatus(before, 200, "summary before");
  for (const k of ["today", "tasks", "support", "selling", "packing", "documents"]) assert.ok(k in before.data, k);
  assert.match(before.data.today, /^\d{4}-\d{2}-\d{2}$/);

  const today = Date.parse(before.data.today + "T00:00:00Z");
  const overdueDate = iso(today - 3 * 86400_000).slice(0, 10);
  const settings = change("settings", { key: "main", departureDate: "2027-01-05", supportTargetMonthlyCents: 100000 });
  const partner = change("partners", { name: "Test Partner", stage: "committed", monthlyCents: 2500, currency: "EUR" });
  const task = change("tasks", { title: "Overdue thing", status: "todo", area: "admin", dueDate: overdueDate });
  const r = await sync(A.token, null, [settings, partner, task]);
  assert.equal(r.accepted.length, 3, JSON.stringify(r.rejected));

  const after = await api("GET", "/v1/summary", { token: A.token });
  expectStatus(after, 200, "summary after");
  const b = before.data, a = after.data;
  assert.equal(a.departureDate, "2027-01-05");
  const expectedDays = Math.round((Date.parse("2027-01-05T00:00:00Z") - Date.parse(a.today + "T00:00:00Z")) / 86400_000);
  assert.equal(a.daysToDeparture, expectedDays);
  assert.equal(a.support.targetMonthlyCents, 100000);
  assert.equal(a.support.committedMonthlyCents - b.support.committedMonthlyCents, 2500);
  assert.equal(a.support.partners - b.support.partners, 1);
  assert.ok(Math.abs(a.support.percentOfTarget - (100 * a.support.committedMonthlyCents) / 100000) < 0.5 ||
            Math.abs(a.support.percentOfTarget - a.support.committedMonthlyCents / 100000) < 0.005,
            `percentOfTarget ${a.support.percentOfTarget}`);
  assert.equal(a.tasks.overdue - b.tasks.overdue, 1);
  assert.equal(a.tasks.open - b.tasks.open, 1);
  assert.equal((a.tasks.byArea?.admin ?? 0) - (b.tasks.byArea?.admin ?? 0), 1);
  assert.equal(a.tasks.done - b.tasks.done, 0);
});

test("export contains the records", async () => {
  const c = change("contacts", { name: "Export Test Contact", role: "staff" });
  const s = await sync(A.token, null, [c]);
  assert.ok(s.accepted.some((x) => x.id === c.id));
  const r = await api("GET", "/v1/export", { token: A.token });
  expectStatus(r, 200);
  assert.ok(!Number.isNaN(Date.parse(r.data.exportedAt)));
  assert.ok(Array.isArray(r.data.files));
  const rec = r.data.records.find((x) => x.id === c.id);
  assert.ok(rec, "record in export");
  assert.equal(rec.data.name, "Export Test Contact");
  assert.equal(rec.collection, "contacts");
});

// ---------- password & logout (last) ----------

test("password change (and change it back)", async () => {
  const NEW = "a brand new passphrase";
  const wrong = await api("POST", "/v1/auth/password", {
    token: A.token, json: { currentPassword: "not my password", newPassword: NEW },
  });
  expectStatus(wrong, 401, "wrong current password");

  expectStatus(await api("POST", "/v1/auth/password", {
    token: A.token, json: { currentPassword: PASSWORD, newPassword: NEW },
  }), 204, "change");
  expectStatus(await login("pw-check", NEW), 200, "login with new password");
  expectStatus(await login("pw-check-old", PASSWORD), 401, "old password refused");
  expectStatus(await api("GET", "/v1/me", { token: B.token }), 200, "other device stays logged in");

  expectStatus(await api("POST", "/v1/auth/password", {
    token: A.token, json: { currentPassword: NEW, newPassword: PASSWORD },
  }), 204, "change back");
  expectStatus(await login("pw-check-back", PASSWORD), 200, "original password works again");
});

test("logout revokes only that token", async () => {
  const D = await loginOk("Test device D (logout)");
  expectStatus(await api("GET", "/v1/me", { token: D.token }), 200);
  expectStatus(await api("POST", "/v1/auth/logout", { token: D.token }), 204, "logout");
  expectStatus(await api("GET", "/v1/me", { token: D.token }), 401, "after logout");
  expectStatus(await api("GET", "/v1/me", { token: A.token }), 200, "A still logged in");
});
