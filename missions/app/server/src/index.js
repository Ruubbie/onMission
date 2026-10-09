// Mission App API: sync + file storage for the iPhone app and the Windows helper.
// Cloudflare Worker + D1 (records, accounts) + R2 (files). Contract: ../api/openapi.yaml
//
//   GET    /v1/health                     no login
//   POST   /v1/auth/setup                 first account, needs SETUP_SECRET
//   POST   /v1/auth/login                 email + password -> device token
//   POST   /v1/auth/logout | /password    GET /v1/me    GET/DELETE /v1/devices[/id]
//   POST   /v1/sync                       push changes, pull everything after cursor
//   GET/PUT/DELETE /v1/records/:collection[/:id]
//   PUT/GET/HEAD/DELETE /v1/files/:id     GET /v1/files
//   GET    /v1/summary | /v1/export
//
// Secret: SETUP_SECRET. Vars: APP_VERSION, MAX_FILE_MB.

const COLLECTIONS = new Set([
  "tasks", "checklists", "partners", "gifts", "budget", "sellItems", "packing", "notes", "documents", "contacts", "newsletters", "settings",
]);
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const ISO_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const MAX_CHANGES = 500;
const MAX_DATA_BYTES = 256 * 1024;
const MAX_FUTURE_MS = 5 * 60e3;          // client clocks further ahead than this are clamped
const TOMBSTONE_DAYS = 180;
const PBKDF2_ITERATIONS = 100_000;       // the maximum Workers allows
const LOGIN_LIMIT = 10;                  // failed logins per email per 15 minutes
const OPEN_TASK = (s) => s !== "done" && s !== "skipped";

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    try {
      return await route(request, env);
    } catch (err) {
      if (err instanceof HttpError) return error(err.status, err.code, err.message);
      console.error(err);
      return error(500, "server_error", "Something went wrong on the server.");
    }
  },

  // Daily: forget old tombstones and old failed-login rows.
  async scheduled(_event, env) {
    await prune(env, new Date());
  },
};

// ---------- routing ----------

async function route(request, env) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const method = request.method;

  if (path === "/v1/health" && method === "GET") {
    return json({ ok: true, version: env.APP_VERSION || "1.0.0", time: now() });
  }
  if (path === "/v1/auth/setup" && method === "POST") return setup(request, env);
  if (path === "/v1/auth/login" && method === "POST") return login(request, env);

  const auth = await authenticate(request, env);

  if (path === "/v1/auth/logout" && method === "POST") {
    await env.DB.prepare("UPDATE devices SET revoked_at = ? WHERE id = ?").bind(now(), auth.device.id).run();
    return empty();
  }
  if (path === "/v1/auth/password" && method === "POST") return changePassword(request, env, auth);
  if (path === "/v1/me" && method === "GET") {
    return json({ user: publicUser(auth.user), space: auth.space, device: publicDevice(auth.device, auth.device.id) });
  }
  if (path === "/v1/devices" && method === "GET") return listDevices(env, auth);
  let m = path.match(/^\/v1\/devices\/([^/]+)$/);
  if (m && method === "DELETE") return revokeDevice(env, auth, decodeURIComponent(m[1]));

  if (path === "/v1/sync" && method === "POST") return sync(request, env, auth);

  m = path.match(/^\/v1\/records\/([^/]+)(?:\/([^/]+))?$/);
  if (m) {
    const collection = m[1];
    if (!COLLECTIONS.has(collection)) throw new HttpError(404, "unknown_collection", `No collection "${collection}".`);
    if (!m[2] && method === "GET") return listRecords(env, auth, collection, url.searchParams.get("includeDeleted") === "true");
    if (m[2]) {
      const id = m[2];
      if (!UUID_RE.test(id)) throw new HttpError(400, "invalid_id", "Record ids are lowercase UUIDs.");
      if (method === "GET") return getRecord(env, auth, collection, id);
      if (method === "PUT") return putRecord(request, env, auth, collection, id);
      if (method === "DELETE") return deleteRecord(env, auth, collection, id);
    }
  }

  if (path === "/v1/files" && method === "GET") return listFiles(env, auth);
  m = path.match(/^\/v1\/files\/([^/]+)$/);
  if (m) {
    const id = m[1];
    if (!UUID_RE.test(id)) throw new HttpError(400, "invalid_id", "File ids are lowercase UUIDs.");
    if (method === "PUT") return putFile(request, env, auth, id);
    if (method === "GET" || method === "HEAD") return getFile(request, env, auth, id, method === "HEAD");
    if (method === "DELETE") return deleteFile(env, auth, id);
  }

  if (path === "/v1/summary" && method === "GET") return summary(env, auth, url);
  if (path === "/v1/export" && method === "GET") return exportAll(env, auth);

  throw new HttpError(404, "not_found", "No such endpoint.");
}

// ---------- auth ----------

async function setup(request, env) {
  const body = await readJson(request);
  if (!env.SETUP_SECRET || !(await safeEqual(String(body.setupSecret || ""), env.SETUP_SECRET))) {
    throw new HttpError(403, "forbidden", "Wrong setup secret.");
  }
  const existing = await env.DB.prepare("SELECT 1 FROM users LIMIT 1").first();
  if (existing) throw new HttpError(409, "already_set_up", "An account already exists. Log in instead.");

  const email = String(body.email || "").trim().toLowerCase();
  const name = String(body.name || "").trim().slice(0, 100);
  if (!EMAIL_RE.test(email)) throw new HttpError(400, "invalid_email", "That email address doesn't look right.");
  if (!name) throw new HttpError(400, "invalid_name", "Name is required.");
  checkPassword(body.password);

  const user = { id: crypto.randomUUID(), email, name };
  const space = { id: crypto.randomUUID(), name: `${name}'s mission`, role: "owner" };
  const t = now();
  await env.DB.batch([
    env.DB.prepare("INSERT INTO users (id, email, name, password_hash, created_at) VALUES (?, ?, ?, ?, ?)")
      .bind(user.id, email, name, await hashPassword(body.password), t),
    env.DB.prepare("INSERT INTO spaces (id, name, created_at) VALUES (?, ?, ?)").bind(space.id, space.name, t),
    env.DB.prepare("INSERT INTO memberships (space_id, user_id, role) VALUES (?, ?, 'owner')").bind(space.id, user.id),
  ]);
  const { token, device } = await createDevice(env, user.id, body.device);
  return json({ token, user, space, device }, 201);
}

async function login(request, env) {
  const body = await readJson(request);
  const email = String(body.email || "").trim().toLowerCase();
  const since = new Date(Date.now() - 15 * 60e3).toISOString();
  const fails = await env.DB.prepare("SELECT COUNT(*) AS n FROM login_failures WHERE email = ? AND at > ?").bind(email, since).first();
  if (fails.n >= LOGIN_LIMIT) throw new HttpError(429, "too_many_attempts", "Too many failed logins. Wait 15 minutes.");

  const user = await env.DB.prepare("SELECT * FROM users WHERE email = ?").bind(email).first();
  const ok = user ? await verifyPassword(String(body.password || ""), user.password_hash) : false;
  if (!ok) {
    await env.DB.prepare("INSERT INTO login_failures (email, at) VALUES (?, ?)").bind(email, now()).run();
    throw new HttpError(401, "invalid_login", "Email or password is wrong.");
  }
  await env.DB.prepare("DELETE FROM login_failures WHERE email = ?").bind(email).run();
  const space = await spaceFor(env, user.id);
  const { token, device } = await createDevice(env, user.id, body.device);
  return json({ token, user: publicUser(user), space, device });
}

async function changePassword(request, env, auth) {
  const body = await readJson(request);
  if (!(await verifyPassword(String(body.currentPassword || ""), auth.user.password_hash))) {
    throw new HttpError(401, "invalid_login", "Current password is wrong.");
  }
  checkPassword(body.newPassword);
  const stmts = [env.DB.prepare("UPDATE users SET password_hash = ? WHERE id = ?").bind(await hashPassword(body.newPassword), auth.user.id)];
  if (body.revokeOthers === true) {
    stmts.push(env.DB.prepare("UPDATE devices SET revoked_at = ? WHERE user_id = ? AND id != ? AND revoked_at IS NULL")
      .bind(now(), auth.user.id, auth.device.id));
  }
  await env.DB.batch(stmts);
  return empty();
}

async function authenticate(request, env) {
  const header = request.headers.get("Authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token) throw new HttpError(401, "unauthorized", "Log in first.");
  const device = await env.DB.prepare("SELECT * FROM devices WHERE token_hash = ? AND revoked_at IS NULL")
    .bind(await sha256Hex(token)).first();
  if (!device) throw new HttpError(401, "unauthorized", "This device is logged out. Log in again.");
  const user = await env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(device.user_id).first();
  const space = await spaceFor(env, user.id);
  // Note when a device was last used, at most every 5 minutes to save writes.
  if (!device.last_seen_at || Date.parse(device.last_seen_at) < Date.now() - 5 * 60e3) {
    await env.DB.prepare("UPDATE devices SET last_seen_at = ? WHERE id = ?").bind(now(), device.id).run();
  }
  return { user, device, space };
}

async function spaceFor(env, userId) {
  const row = await env.DB.prepare(
    "SELECT s.id, s.name, m.role FROM memberships m JOIN spaces s ON s.id = m.space_id WHERE m.user_id = ? ORDER BY s.created_at LIMIT 1"
  ).bind(userId).first();
  if (!row) throw new HttpError(403, "no_space", "This account has no space.");
  return { id: row.id, name: row.name, role: row.role };
}

async function createDevice(env, userId, info = {}) {
  const token = "mt_" + base64url(crypto.getRandomValues(new Uint8Array(32)));
  const platform = ["ios", "windows", "web", "other"].includes(info?.platform) ? info.platform : "other";
  const row = {
    id: crypto.randomUUID(),
    name: String(info?.name || "Unnamed device").slice(0, 100),
    platform,
    app_version: info?.appVersion ? String(info.appVersion).slice(0, 40) : null,
    created_at: now(),
    last_seen_at: now(),
  };
  await env.DB.prepare(
    "INSERT INTO devices (id, user_id, token_hash, name, platform, app_version, created_at, last_seen_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
  ).bind(row.id, userId, await sha256Hex(token), row.name, row.platform, row.app_version, row.created_at, row.last_seen_at).run();
  return { token, device: publicDevice(row, row.id) };
}

async function listDevices(env, auth) {
  const { results } = await env.DB.prepare(
    "SELECT * FROM devices WHERE user_id = ? AND revoked_at IS NULL ORDER BY created_at"
  ).bind(auth.user.id).all();
  return json({ devices: results.map((d) => publicDevice(d, auth.device.id)) });
}

async function revokeDevice(env, auth, id) {
  const res = await env.DB.prepare("UPDATE devices SET revoked_at = ? WHERE id = ? AND user_id = ? AND revoked_at IS NULL")
    .bind(now(), id, auth.user.id).run();
  if (!res.meta.changes) throw new HttpError(404, "not_found", "No such device.");
  return empty();
}

function checkPassword(pw) {
  if (typeof pw !== "string" || pw.length < 10) throw new HttpError(400, "weak_password", "Use a password of at least 10 characters.");
  if (pw.length > 200) throw new HttpError(400, "weak_password", "That password is too long.");
}

async function hashPassword(password, salt = crypto.getRandomValues(new Uint8Array(16)), iterations = PBKDF2_ITERATIONS) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations }, key, 256);
  return `pbkdf2$${iterations}$${base64url(salt)}$${base64url(new Uint8Array(bits))}`;
}

async function verifyPassword(password, stored) {
  const [kind, iter, salt] = stored.split("$");
  if (kind !== "pbkdf2") return false;
  return safeEqual(await hashPassword(password, fromBase64url(salt), Number(iter)), stored);
}

// ---------- records and sync ----------

async function sync(request, env, auth) {
  const body = await readJson(request);
  const changes = body.changes ?? [];
  if (!Array.isArray(changes)) throw new HttpError(400, "invalid_body", "`changes` must be an array.");
  if (changes.length > MAX_CHANGES) throw new HttpError(413, "too_many_changes", `Send at most ${MAX_CHANGES} changes per call.`);
  const limit = Math.min(Math.max(Number.parseInt(body.limit, 10) || 500, 1), 1000);

  let cursor = 0;
  if (body.cursor !== undefined && body.cursor !== null && body.cursor !== "") {
    cursor = Number(body.cursor);
    if (!Number.isSafeInteger(cursor) || cursor < 0) throw new HttpError(400, "invalid_cursor", "That cursor is not valid. Drop it and sync again.");
  }

  const { accepted, rejected } = await applyChanges(env, auth, changes);

  const space = await env.DB.prepare("SELECT seq, pruned_through_seq FROM spaces WHERE id = ?").bind(auth.space.id).first();
  if (cursor > space.seq) cursor = 0; // cursor from another database (e.g. after a restore): start over
  const resetRequired = cursor > 0 && cursor < space.pruned_through_seq;
  let page = [];
  let hasMore = false;
  if (!resetRequired) {
    const { results } = await env.DB.prepare("SELECT * FROM records WHERE space_id = ? AND seq > ? ORDER BY seq LIMIT ?")
      .bind(auth.space.id, cursor, limit + 1).all();
    hasMore = results.length > limit;
    page = results.slice(0, limit);
  }
  const next = page.length ? page[page.length - 1].seq : cursor;
  return json({
    cursor: String(next),
    hasMore,
    resetRequired,
    serverTime: now(),
    changes: page.map(toRecord),
    accepted,
    rejected,
  });
}

// Validates and stores changes with last-writer-wins on updatedAt. Returns per-change outcome.
async function applyChanges(env, auth, changes) {
  const accepted = [];
  const rejected = [];
  if (!changes.length) return { accepted, rejected, stored: [] };
  if (auth.space.role === "viewer") {
    return { accepted, rejected: changes.map((c) => ({ id: String(c?.id ?? ""), reason: "forbidden", message: "Read-only access." })), stored: [] };
  }

  const nowMs = Date.now();
  const valid = [];
  for (const c of changes) {
    const problem = validateChange(c);
    if (problem) {
      rejected.push({ id: typeof c?.id === "string" ? c.id : String(c?.id ?? ""), reason: "invalid", message: problem });
      continue;
    }
    let updatedAt = new Date(c.updatedAt).toISOString();
    if (Date.parse(updatedAt) > nowMs + MAX_FUTURE_MS) updatedAt = new Date(nowMs).toISOString();
    const deletedAt = c.deletedAt ? new Date(c.deletedAt).toISOString() : null;
    valid.push({ id: c.id, collection: c.collection, updatedAt, deletedAt, data: JSON.stringify(c.data) });
  }

  // Last change per id wins within one batch (a client may send several edits of the same record).
  const byId = new Map();
  for (const v of valid) {
    const prev = byId.get(v.id);
    if (!prev || v.updatedAt >= prev.updatedAt) byId.set(v.id, v);
  }

  const existing = await loadExisting(env, auth.space.id, [...byId.keys()]);
  const toStore = [];
  for (const v of byId.values()) {
    const cur = existing.get(v.id);
    if (cur && cur.collection !== v.collection) {
      rejected.push({ id: v.id, reason: "invalid", message: `This id already belongs to "${cur.collection}".` });
    } else if (!cur || v.updatedAt > cur.updated_at) {
      toStore.push({ ...v, createdAt: cur?.created_at ?? v.updatedAt });
    } else if (v.updatedAt === cur.updated_at && v.data === cur.data && v.deletedAt === cur.deleted_at) {
      accepted.push({ id: v.id, seq: cur.seq }); // same change sent twice (e.g. a retry): nothing to do
    } else {
      rejected.push({ id: v.id, reason: "stale", message: "The server has a newer version.", current: toRecord(cur) });
    }
  }
  if (!toStore.length) return { accepted, rejected, stored: [] };

  // Reserve a block of change numbers, then write everything in one transaction.
  const { seq: last } = await env.DB.prepare("UPDATE spaces SET seq = seq + ? WHERE id = ? RETURNING seq")
    .bind(toStore.length, auth.space.id).first();
  let seq = last - toStore.length;
  const upsert = env.DB.prepare(
    `INSERT INTO records (space_id, id, collection, data, created_at, updated_at, deleted_at, seq, updated_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (space_id, id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at,
       deleted_at = excluded.deleted_at, seq = excluded.seq, updated_by = excluded.updated_by
     WHERE excluded.updated_at > records.updated_at`
  );
  const stmts = [];
  for (const s of toStore) {
    s.seq = ++seq;
    stmts.push(upsert.bind(auth.space.id, s.id, s.collection, s.data, s.createdAt, s.updatedAt, s.deletedAt, s.seq, auth.device.id));
  }
  const results = await env.DB.batch(stmts);
  const stored = [];
  toStore.forEach((s, i) => {
    if (results[i].meta.changes) {
      accepted.push({ id: s.id, seq: s.seq });
      stored.push(s);
    } else {
      // Another device won the race between our read and write.
      rejected.push({ id: s.id, reason: "stale", message: "The server has a newer version." });
    }
  });
  return { accepted, rejected, stored };
}

function validateChange(c) {
  if (!c || typeof c !== "object" || Array.isArray(c)) return "Each change must be an object.";
  if (typeof c.id !== "string" || !UUID_RE.test(c.id)) return "id must be a lowercase UUID.";
  if (!COLLECTIONS.has(c.collection)) return `Unknown collection "${c.collection}".`;
  if (typeof c.updatedAt !== "string" || !ISO_RE.test(c.updatedAt) || Number.isNaN(Date.parse(c.updatedAt))) {
    return "updatedAt must be an ISO 8601 timestamp.";
  }
  if (c.deletedAt != null && (typeof c.deletedAt !== "string" || Number.isNaN(Date.parse(c.deletedAt)))) {
    return "deletedAt must be an ISO 8601 timestamp or null.";
  }
  if (!c.data || typeof c.data !== "object" || Array.isArray(c.data)) return "data must be a JSON object.";
  if (new TextEncoder().encode(JSON.stringify(c.data)).length > MAX_DATA_BYTES) return "data is larger than 256 KB.";
  return null;
}

async function loadExisting(env, spaceId, ids) {
  const map = new Map();
  for (let i = 0; i < ids.length; i += 90) {
    const chunk = ids.slice(i, i + 90);
    const { results } = await env.DB.prepare(
      `SELECT * FROM records WHERE space_id = ? AND id IN (${chunk.map(() => "?").join(",")})`
    ).bind(spaceId, ...chunk).all();
    for (const r of results) map.set(r.id, r);
  }
  return map;
}

async function listRecords(env, auth, collection, includeDeleted) {
  const { results } = await env.DB.prepare(
    `SELECT * FROM records WHERE space_id = ? AND collection = ? ${includeDeleted ? "" : "AND deleted_at IS NULL"} ORDER BY seq`
  ).bind(auth.space.id, collection).all();
  return json({ records: results.map(toRecord) });
}

async function findRecord(env, auth, collection, id) {
  const row = await env.DB.prepare("SELECT * FROM records WHERE space_id = ? AND id = ? AND collection = ?")
    .bind(auth.space.id, id, collection).first();
  if (!row) throw new HttpError(404, "not_found", "No such record.");
  return row;
}

async function getRecord(env, auth, collection, id) {
  return json(toRecord(await findRecord(env, auth, collection, id)));
}

async function putRecord(request, env, auth, collection, id) {
  const body = await readJson(request);
  const change = { id, collection, updatedAt: body.updatedAt ?? now(), deletedAt: body.deletedAt ?? null, data: body.data };
  const { rejected } = await applyChanges(env, auth, [change]);
  if (rejected.length) {
    const r = rejected[0];
    if (r.reason === "stale") return json(toRecord(await findRecord(env, auth, collection, id)), 409);
    throw new HttpError(r.reason === "forbidden" ? 403 : 400, r.reason, r.message);
  }
  return json(toRecord(await findRecord(env, auth, collection, id)));
}

async function deleteRecord(env, auth, collection, id) {
  const cur = await findRecord(env, auth, collection, id);
  if (!cur.deleted_at) {
    const t = laterThan(cur.updated_at);
    await applyChanges(env, auth, [{ id, collection, updatedAt: t, deletedAt: t, data: JSON.parse(cur.data) }]);
  }
  return json(toRecord(await findRecord(env, auth, collection, id)));
}

// "now", but always after the given timestamp, so a server-side delete beats a slightly-future client edit.
function laterThan(iso) {
  const n = Date.now();
  const t = Date.parse(iso);
  return new Date(n > t ? n : t + 1).toISOString();
}

function toRecord(r) {
  return {
    id: r.id,
    collection: r.collection,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
    deletedAt: r.deleted_at ?? null,
    seq: r.seq,
    updatedBy: r.updated_by ?? null,
    data: JSON.parse(r.data),
  };
}

// ---------- files ----------

async function putFile(request, env, auth, id) {
  if (auth.space.role === "viewer") throw new HttpError(403, "forbidden", "Read-only access.");
  const max = Number(env.MAX_FILE_MB || 50) * 1024 * 1024;
  if (Number(request.headers.get("Content-Length") || 0) > max) throw new HttpError(413, "too_large", `Files can be at most ${env.MAX_FILE_MB || 50} MB.`);
  const bytes = await request.arrayBuffer();
  if (bytes.byteLength > max) throw new HttpError(413, "too_large", `Files can be at most ${env.MAX_FILE_MB || 50} MB.`);
  if (bytes.byteLength === 0) throw new HttpError(400, "empty_file", "The file is empty.");

  const sha256 = hex(await crypto.subtle.digest("SHA-256", bytes));
  const expected = (request.headers.get("X-Sha256") || "").trim().toLowerCase();
  if (expected && expected !== sha256) throw new HttpError(400, "checksum_mismatch", "The upload got damaged on the way. Try again.");

  const mimeType = (request.headers.get("Content-Type") || "application/octet-stream").split(";")[0].trim().slice(0, 100);
  let fileName = request.headers.get("X-File-Name");
  if (fileName) {
    try { fileName = decodeURIComponent(fileName); } catch { /* keep as sent */ }
    fileName = fileName.replace(/[\\/\r\n]/g, "_").slice(0, 255);
  }
  const info = { id, fileName: fileName || null, mimeType, sizeBytes: bytes.byteLength, sha256, uploadedAt: now() };

  await env.FILES.put(fileKey(auth, id), bytes, { httpMetadata: { contentType: mimeType }, sha256 });
  await env.DB.prepare(
    `INSERT INTO files (space_id, id, file_name, mime_type, size_bytes, sha256, uploaded_at) VALUES (?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (space_id, id) DO UPDATE SET file_name = excluded.file_name, mime_type = excluded.mime_type,
       size_bytes = excluded.size_bytes, sha256 = excluded.sha256, uploaded_at = excluded.uploaded_at`
  ).bind(auth.space.id, id, info.fileName, mimeType, info.sizeBytes, sha256, info.uploadedAt).run();
  return json(info, 201);
}

async function getFile(request, env, auth, id, headOnly) {
  const row = await env.DB.prepare("SELECT * FROM files WHERE space_id = ? AND id = ?").bind(auth.space.id, id).first();
  if (!row) {
    if (headOnly) return new Response(null, { status: 404, headers: CORS });
    throw new HttpError(404, "not_found", "No such file.");
  }
  const headers = new Headers(CORS);
  headers.set("Content-Type", row.mime_type);
  headers.set("ETag", `"${row.sha256}"`);
  headers.set("Cache-Control", "private, no-cache");
  headers.set("Content-Disposition", `attachment; filename*=UTF-8''${encodeURIComponent(row.file_name || id)}`);
  headers.set("X-Content-Type-Options", "nosniff");

  const inm = (request.headers.get("If-None-Match") || "").replace(/^W\//, "").replace(/"/g, "");
  if (inm && inm.split(",").map((s) => s.trim()).includes(row.sha256)) return new Response(null, { status: 304, headers });

  headers.set("Content-Length", String(row.size_bytes));
  if (headOnly) return new Response(null, { status: 200, headers });
  const obj = await env.FILES.get(fileKey(auth, id));
  if (!obj) throw new HttpError(404, "not_found", "The file is missing from storage.");
  return new Response(obj.body, { status: 200, headers });
}

async function deleteFile(env, auth, id) {
  if (auth.space.role === "viewer") throw new HttpError(403, "forbidden", "Read-only access.");
  await env.FILES.delete(fileKey(auth, id));
  await env.DB.prepare("DELETE FROM files WHERE space_id = ? AND id = ?").bind(auth.space.id, id).run();
  return empty();
}

async function listFiles(env, auth) {
  return json({ files: await fileInfos(env, auth) });
}

async function fileInfos(env, auth) {
  const { results } = await env.DB.prepare("SELECT * FROM files WHERE space_id = ? ORDER BY uploaded_at").bind(auth.space.id).all();
  return results.map((f) => ({
    id: f.id, fileName: f.file_name, mimeType: f.mime_type, sizeBytes: f.size_bytes, sha256: f.sha256, uploadedAt: f.uploaded_at,
  }));
}

const fileKey = (auth, id) => `${auth.space.id}/${id}`;

// ---------- summary and export ----------

async function summary(env, auth, url) {
  const tz = url.searchParams.get("tz") || "Europe/Amsterdam";
  let today;
  try {
    today = new Intl.DateTimeFormat("en-CA", { timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
  } catch {
    throw new HttpError(400, "invalid_tz", "Unknown time zone.");
  }
  const { results } = await env.DB.prepare(
    "SELECT collection, data, updated_at FROM records WHERE space_id = ? AND deleted_at IS NULL AND collection IN ('tasks','partners','sellItems','packing','documents','settings')"
  ).bind(auth.space.id).all();
  const by = { tasks: [], partners: [], sellItems: [], packing: [], documents: [], settings: [] };
  for (const r of results) by[r.collection].push({ ...safeParse(r.data), _updatedAt: r.updated_at });

  const settings = by.settings.filter((s) => s.key === "main").sort((a, b) => (a._updatedAt < b._updatedAt ? 1 : -1))[0] || {};
  const nzdPerEur = Number(settings.nzdPerEur) || null;
  const toEurCents = (cents, currency) => {
    const n = Number(cents) || 0;
    if (!currency || currency === "EUR") return n;
    if (currency === "NZD" && nzdPerEur) return Math.round(n / nzdPerEur);
    return 0; // unknown rate: leave it out rather than guess
  };
  const addDays = (d, n) => new Date(Date.parse(d + "T00:00:00Z") + n * 864e5).toISOString().slice(0, 10);
  const weekEnd = addDays(today, 7);

  const tasks = { open: 0, overdue: 0, dueThisWeek: 0, done: 0, byArea: {} };
  for (const t of by.tasks) {
    if (!OPEN_TASK(t.status)) { if (t.status === "done") tasks.done++; continue; }
    tasks.open++;
    const area = t.area || "other";
    tasks.byArea[area] = (tasks.byArea[area] || 0) + 1;
    if (typeof t.dueDate === "string") {
      if (t.dueDate < today) tasks.overdue++;
      else if (t.dueDate <= weekEnd) tasks.dueThisWeek++;
    }
  }

  const target = Number.isInteger(settings.supportTargetMonthlyCents) ? settings.supportTargetMonthlyCents : null;
  const minimum = Number.isInteger(settings.supportMinimumMonthlyCents) ? settings.supportMinimumMonthlyCents : null;
  let committed = 0;
  let followUpsDue = 0;
  for (const p of by.partners) {
    if (p.stage === "committed" || p.stage === "giving") committed += toEurCents(p.monthlyCents, p.currency);
    if (typeof p.nextFollowUp === "string" && p.nextFollowUp <= today && p.stage !== "declined") followUpsDue++;
  }

  const left = new Set(["decide", "to-list", "listed", "reserved"]);
  const selling = { itemsLeft: 0, soldCents: 0 };
  for (const s of by.sellItems) {
    if (left.has(s.status)) selling.itemsLeft++;
    if (s.status === "sold") selling.soldCents += toEurCents(s.soldCents, s.currency);
  }

  const horizon = addDays(today, 180);
  const docs = { total: by.documents.length, missingFile: 0, expiringWithin180Days: 0 };
  for (const d of by.documents) {
    if (!d.fileId) docs.missingFile++;
    if (typeof d.expiresAt === "string" && d.expiresAt <= horizon) docs.expiringWithin180Days++;
  }

  const departureDate = typeof settings.departureDate === "string" ? settings.departureDate : null;
  return json({
    today,
    departureDate,
    daysToDeparture: departureDate ? Math.round((Date.parse(departureDate + "T00:00:00Z") - Date.parse(today + "T00:00:00Z")) / 864e5) : null,
    tasks,
    support: {
      committedMonthlyCents: committed,
      targetMonthlyCents: target,
      minimumMonthlyCents: minimum,
      percentOfTarget: target ? Math.round((committed / target) * 1000) / 10 : null,
      partners: by.partners.filter((p) => p.stage !== "declined" && p.stage !== "idea").length,
      followUpsDue,
    },
    selling,
    packing: { total: by.packing.length, packed: by.packing.filter((p) => p.packed === true).length },
    documents: docs,
  });
}

async function exportAll(env, auth) {
  const { results } = await env.DB.prepare("SELECT * FROM records WHERE space_id = ? ORDER BY seq").bind(auth.space.id).all();
  const body = JSON.stringify({ exportedAt: now(), records: results.map(toRecord), files: await fileInfos(env, auth) });
  return new Response(body, {
    headers: {
      ...CORS,
      "Content-Type": "application/json; charset=utf-8",
      "Content-Disposition": `attachment; filename="mission-backup-${now().slice(0, 10)}.json"`,
    },
  });
}

// ---------- maintenance ----------

export async function prune(env, date) {
  const cutoff = new Date(date.getTime() - TOMBSTONE_DAYS * 864e5).toISOString();
  const { results } = await env.DB.prepare(
    "SELECT space_id, MAX(seq) AS max_seq FROM records WHERE deleted_at IS NOT NULL AND deleted_at < ? GROUP BY space_id"
  ).bind(cutoff).all();
  const stmts = [];
  for (const r of results) {
    stmts.push(env.DB.prepare("UPDATE spaces SET pruned_through_seq = MAX(pruned_through_seq, ?) WHERE id = ?").bind(r.max_seq, r.space_id));
    stmts.push(env.DB.prepare("DELETE FROM records WHERE space_id = ? AND deleted_at IS NOT NULL AND deleted_at < ?").bind(r.space_id, cutoff));
  }
  stmts.push(env.DB.prepare("DELETE FROM login_failures WHERE at < ?").bind(new Date(date.getTime() - 864e5).toISOString()));
  await env.DB.batch(stmts);
}

// ---------- helpers ----------

class HttpError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, HEAD, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type, X-File-Name, X-Sha256, If-None-Match",
  "Access-Control-Expose-Headers": "ETag, Content-Disposition",
};

function json(value, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" } });
}
const empty = () => new Response(null, { status: 204, headers: CORS });
const error = (status, code, message) => json({ error: { code, message } }, status);
const now = () => new Date().toISOString();

async function readJson(request) {
  const body = await request.json().catch(() => null);
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new HttpError(400, "invalid_body", "Send a JSON object.");
  return body;
}

function safeParse(s) {
  try { return JSON.parse(s); } catch { return {}; }
}

function publicUser(u) {
  return { id: u.id, email: u.email, name: u.name };
}

function publicDevice(d, currentId) {
  return {
    id: d.id, name: d.name, platform: d.platform, appVersion: d.app_version ?? null,
    createdAt: d.created_at, lastSeenAt: d.last_seen_at ?? null, current: d.id === currentId,
  };
}

async function sha256Hex(text) {
  return hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)));
}

function hex(buf) {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function base64url(bytes) {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64url(s) {
  const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/"));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

// Compares via hashes so the time taken doesn't reveal how much of a secret matched.
async function safeEqual(a, b) {
  const [x, y] = await Promise.all([sha256Hex(a), sha256Hex(b)]);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x.charCodeAt(i) ^ y.charCodeAt(i);
  return diff === 0;
}
