// The records the site shows, kept in memory. Every change goes straight to the server
// (PUT /v1/records/{collection}/{id}). The server keeps the newest copy per record (last writer
// wins), so a 409 means another device saved later: we take the server copy and say so.

import { api, ApiError } from "./api.js";
import { COLLECTIONS, newId } from "./util.js";

export const SETTINGS_ID = "60a98c2f-4004-58e7-bcc2-c88a62377933";
const DEFAULT_SETTINGS = {
  key: "main",
  departureDate: "2027-01-05",
  supportTargetMonthlyCents: 100000,
  supportMinimumMonthlyCents: 75000,
  currency: "EUR",
  nzdPerEur: 1.85,
};

const cache = new Map(COLLECTIONS.map((c) => [c, new Map()]));
let pending = 0;
let status = { kind: "idle", detail: "" };
const dataListeners = new Set();
const statusListeners = new Set();

function setStatus(kind, detail = "") {
  status = { kind, detail };
  for (const fn of statusListeners) fn(status);
}
function emitData(reason) {
  for (const fn of dataListeners) fn(reason);
}
function noticeToast(message) {
  for (const fn of dataListeners) fn({ type: "notice", message });
}

/** Strips the id and any fields the site keeps only for itself (names starting with "_"). */
function payloadOf(entity) {
  const out = {};
  for (const [k, v] of Object.entries(entity)) {
    if (k === "id" || k.startsWith("_") || v === undefined) continue;
    out[k] = v;
  }
  return out;
}

function fromRecord(record) {
  return { id: record.id, ...record.data };
}

async function put(collection, entity) {
  pending++;
  setStatus("busy", "Saving…");
  try {
    const record = await api.put(`/v1/records/${collection}/${entity.id}`, {
      updatedAt: new Date().toISOString(),
      data: payloadOf(entity),
    });
    cache.get(collection).set(record.id, fromRecord(record));
    return cache.get(collection).get(record.id);
  } finally {
    pending--;
    if (pending === 0 && status.kind === "busy") setStatus("ok", new Date().toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" }));
  }
}

/** Sends the change and handles "another device saved later" (409). */
async function send(collection, entity) {
  try {
    return await put(collection, entity);
  } catch (err) {
    if (err instanceof ApiError && err.status === 409) {
      const current = await api.get(`/v1/records/${collection}/${entity.id}`).catch(() => null);
      if (current) cache.get(collection).set(current.id, fromRecord(current));
      noticeToast("Changed on another device. Showing the newest version.");
      emitData({ type: "remote", collection, id: entity.id });
      return cache.get(collection).get(entity.id) ?? null;
    }
    const offline = err instanceof ApiError && err.status === 0;
    setStatus(offline ? "offline" : "bad", err.message);
    throw err;
  }
}

export const store = {
  /** Loads every collection from the server. */
  async load() {
    setStatus("busy", "Syncing…");
    try {
      const lists = await Promise.all(COLLECTIONS.map((c) => api.get(`/v1/records/${c}`)));
      COLLECTIONS.forEach((c, i) => {
        const map = new Map();
        for (const record of lists[i].records) map.set(record.id, fromRecord(record));
        cache.set(c, map);
      });
      setStatus("ok", new Date().toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" }));
      emitData({ type: "load" });
    } catch (err) {
      const offline = err instanceof ApiError && err.status === 0;
      setStatus(offline ? "offline" : "bad", err.message);
      throw err;
    }
  },

  list(collection) {
    return [...cache.get(collection).values()];
  },
  get(collection, id) {
    return id ? cache.get(collection).get(id) ?? null : null;
  },

  /** Creates a record with a new id. Returns the saved entity. */
  async create(collection, fields) {
    const entity = { id: newId(), ...fields };
    cache.get(collection).set(entity.id, entity);
    const saved = await send(collection, entity);
    return saved ?? entity;
  },

  /** Saves an entity you changed (keeps every field, including ones this site doesn't show). */
  async save(collection, entity) {
    cache.get(collection).set(entity.id, { ...entity });
    await send(collection, entity);
    return cache.get(collection).get(entity.id);
  },

  /** Soft-deletes a record (tombstone on the server). */
  async remove(collection, id) {
    cache.get(collection).delete(id);
    try {
      await api.del(`/v1/records/${collection}/${id}`);
      setStatus("ok", status.detail);
    } catch (err) {
      setStatus(err instanceof ApiError && err.status === 0 ? "offline" : "bad", err.message);
      throw err;
    }
  },

  /** Mission settings: departure date, support target, NZD rate. */
  settings() {
    const s = cache.get("settings").get(SETTINGS_ID);
    return { ...DEFAULT_SETTINGS, ...(s ?? {}), id: SETTINGS_ID };
  },
  async saveSettings(patch) {
    const merged = { ...store.settings(), ...patch, id: SETTINGS_ID };
    await send("settings", merged);
    return store.settings();
  },

  /** Current sync state: { kind: idle|busy|ok|bad|offline, detail }. */
  status() { return status; },
  onStatus(fn) { statusListeners.add(fn); return () => statusListeners.delete(fn); },
  onData(fn) { dataListeners.add(fn); return () => dataListeners.delete(fn); },
  notify: noticeToast,
  reset() {
    for (const c of COLLECTIONS) cache.get(c).clear();
    setStatus("idle", "");
  },
};

