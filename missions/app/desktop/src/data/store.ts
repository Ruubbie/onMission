// Local-first record store + sync with the mission API (POST /v1/sync, last writer wins on updatedAt).
// Everything lives in localStorage (in the Windows app that is the app's own WebView2 profile).
import { useSyncExternalStore } from "react";
import seed from "./seed-records.json";
import { MAIN_SETTINGS_ID, type Collection, type Rec, type Setting } from "./types";

const KEY = "onmission.store.v1";
const AUTH_KEY = "onmission.auth.v1";
export const DEFAULT_API = "https://api.92-5-233-11.sslip.io";

interface State { records: Record<string, Rec>; dirty: Record<string, true>; cursor: string | null; pendingFiles: Record<string, true> }
export interface Auth { url: string; token?: string; email?: string; name?: string }
export interface SyncStatus { state: "local" | "idle" | "syncing" | "error"; lastSync?: string; message?: string }

const now = () => new Date().toISOString();
export const uuid = () => crypto.randomUUID().toLowerCase();

function load<T>(key: string, fallback: T): T {
  try { const s = localStorage.getItem(key); return s ? { ...fallback, ...JSON.parse(s) } : fallback; } catch { return fallback; }
}

let state: State = load(KEY, { records: {}, dirty: {}, cursor: null, pendingFiles: {} });
let auth: Auth = load(AUTH_KEY, { url: DEFAULT_API });
let status: SyncStatus = { state: auth.token ? "idle" : "local" };
let version = 0;
const listeners = new Set<() => void>();

if (Object.keys(state.records).length === 0) {
  // Starter plan, same ids as the server seed, so nothing doubles. Marked dirty in case the server was never seeded.
  for (const r of (seed as { records: Rec[] }).records) { state.records[r.id] = r; state.dirty[r.id] = true; }
}

let saveTimer: number | undefined;
function changed(persist = true) {
  version++;
  listeners.forEach((l) => l());
  if (persist) { clearTimeout(saveTimer); saveTimer = window.setTimeout(() => localStorage.setItem(KEY, JSON.stringify(state)), 250); }
}
const subscribe = (l: () => void) => { listeners.add(l); return () => listeners.delete(l); };

/** Re-renders on any store change. Cheap enough for a few thousand records. */
export function useStore() { useSyncExternalStore(subscribe, () => version); return { auth, status }; }

export function list<T = Record<string, unknown>>(collection: Collection): Rec<T>[] {
  return Object.values(state.records).filter((r) => r.collection === collection && !r.deletedAt) as Rec<T>[];
}
export function get<T = Record<string, unknown>>(id: string | undefined): Rec<T> | undefined {
  const r = id ? state.records[id] : undefined;
  return r && !r.deletedAt ? (r as Rec<T>) : undefined;
}
export const allRecords = () => Object.values(state.records).filter((r) => !r.deletedAt);

export function put<T extends object>(collection: Collection, data: T, id = uuid()): Rec<T> {
  const r: Rec<T> = { id, collection, updatedAt: now(), deletedAt: null, data };
  state.records[id] = r as Rec; state.dirty[id] = true;
  changed(); scheduleSync();
  return r;
}
export function patch<T extends object>(rec: Rec<T>, p: Partial<T>) { return put(rec.collection, { ...rec.data, ...p }, rec.id); }
export function remove(rec: Rec<unknown>) {
  const r = state.records[rec.id]; if (!r) return;
  state.records[rec.id] = { ...r, updatedAt: now(), deletedAt: now() }; state.dirty[rec.id] = true;
  changed(); scheduleSync();
}
export function restore(rec: Rec<unknown>) { put(rec.collection, rec.data as object, rec.id); }

export function settings(): Rec<Setting> {
  return get<Setting>(MAIN_SETTINGS_ID) ?? { id: MAIN_SETTINGS_ID, collection: "settings", updatedAt: "", data: { key: "main", departureDate: "2027-01-05", supportTargetMonthlyCents: 100000, supportMinimumMonthlyCents: 75000, currency: "EUR", nzdPerEur: 1.85 } };
}

// ---------- API ----------

export class ApiError extends Error { constructor(public status: number, message: string) { super(message); } }

async function api(path: string, init: RequestInit = {}, a: Auth = auth): Promise<Response> {
  const headers = new Headers(init.headers);
  if (a.token) headers.set("Authorization", `Bearer ${a.token}`);
  if (init.body && typeof init.body === "string") headers.set("Content-Type", "application/json");
  const res = await fetch(a.url.replace(/\/$/, "") + path, { ...init, headers });
  if (!res.ok) {
    let msg = `Server answered ${res.status}`;
    try { msg = (await res.json()).error?.message ?? msg; } catch { /* not json */ }
    throw new ApiError(res.status, msg);
  }
  return res;
}

const device = () => ({ name: `${navigator.platform.startsWith("Win") ? "Windows" : "Browser"} app`, platform: navigator.platform.startsWith("Win") ? "windows" : "web", appVersion: "0.1.0" });

export async function login(url: string, email: string, password: string, setup?: { secret: string; name: string }) {
  const a = { url };
  const body = setup ? { setupSecret: setup.secret, email, password, name: setup.name, device: device() } : { email, password, device: device() };
  const res = await (await api(setup ? "/v1/auth/setup" : "/v1/auth/login", { method: "POST", body: JSON.stringify(body) }, a)).json();
  auth = { url, token: res.token, email: res.user?.email ?? email, name: res.user?.name };
  localStorage.setItem(AUTH_KEY, JSON.stringify(auth));
  state.cursor = null; status = { state: "idle" }; changed();
  await sync();
}

export async function logout() {
  try { await api("/v1/auth/logout", { method: "POST" }); } catch { /* token may already be gone */ }
  auth = { url: auth.url }; localStorage.setItem(AUTH_KEY, JSON.stringify(auth));
  status = { state: "local" }; changed(false);
}

export function setApiUrl(url: string) { auth = { ...auth, url }; localStorage.setItem(AUTH_KEY, JSON.stringify(auth)); changed(false); }

let syncing: Promise<void> | null = null;
let syncTimer: number | undefined;
function scheduleSync() { if (!auth.token) return; clearTimeout(syncTimer); syncTimer = window.setTimeout(() => void sync(), 2000); }

export function sync(): Promise<void> {
  if (!auth.token) return Promise.resolve();
  if (!syncing) syncing = doSync().finally(() => { syncing = null; });
  return syncing;
}

async function doSync() {
  status = { ...status, state: "syncing" }; changed(false);
  try {
    await uploadPendingFiles();
    for (let round = 0; round < 50; round++) {
      const ids = Object.keys(state.dirty).slice(0, 500);
      const sent = new Map(ids.map((id) => [id, state.records[id]?.updatedAt]));
      const changes = ids.map((id) => state.records[id]).filter(Boolean).map(({ id, collection, updatedAt, deletedAt, data }) => ({ id, collection, updatedAt, deletedAt: deletedAt ?? null, data }));
      const res = await (await api("/v1/sync", { method: "POST", body: JSON.stringify({ cursor: state.cursor, changes }) })).json();
      if (res.resetRequired) { state.cursor = null; continue; }
      const stillSame = (id: string) => state.records[id]?.updatedAt === sent.get(id);
      for (const a of res.accepted ?? []) if (stillSame(a.id)) delete state.dirty[a.id];
      for (const r of res.rejected ?? []) {
        if (!stillSame(r.id)) continue;
        delete state.dirty[r.id];
        if (r.current) state.records[r.id] = r.current;
        else if (r.reason !== "stale") console.warn("Sync rejected", r);
      }
      for (const r of (res.changes ?? []) as Rec[]) {
        const local = state.records[r.id];
        if (!local || !state.dirty[r.id] || local.updatedAt <= r.updatedAt) {
          state.records[r.id] = { id: r.id, collection: r.collection, updatedAt: r.updatedAt, deletedAt: r.deletedAt ?? null, data: r.data };
          delete state.dirty[r.id];
        }
      }
      state.cursor = res.cursor ?? state.cursor;
      changed();
      if (!res.hasMore && ids.length < 500) break;
    }
    status = { state: "idle", lastSync: now() };
  } catch (e) {
    if (e instanceof ApiError && e.status === 401) { auth = { url: auth.url }; localStorage.setItem(AUTH_KEY, JSON.stringify(auth)); }
    status = { state: auth.token ? "error" : "local", lastSync: status.lastSync, message: e instanceof Error ? e.message : String(e) };
  }
  changed(false);
}

if (auth.token) { setTimeout(() => void sync(), 300); setInterval(() => void sync(), 5 * 60_000); }
window.addEventListener("online", () => void sync());

// ---------- Files (document vault) ----------
// Bytes are kept in the browser Cache so they open offline, and uploaded to /v1/files/{id} when logged in.

const FILE_CACHE = "onmission-files";
const fileKey = (id: string) => `/files/${id}`;

async function sha256(buf: ArrayBuffer) {
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", buf))].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function addFile(file: File) {
  const id = uuid();
  const buf = await file.arrayBuffer();
  const hash = await sha256(buf);
  const cache = await caches.open(FILE_CACHE);
  await cache.put(fileKey(id), new Response(buf, { headers: { "Content-Type": file.type || "application/octet-stream", "X-File-Name": encodeURIComponent(file.name) } }));
  state.pendingFiles[id] = true; changed(); scheduleSync();
  return { fileId: id, fileName: file.name, mimeType: file.type || "application/octet-stream", sizeBytes: file.size, sha256: hash };
}

async function uploadPendingFiles() {
  const cache = await caches.open(FILE_CACHE);
  for (const id of Object.keys(state.pendingFiles)) {
    const res = await cache.match(fileKey(id));
    if (!res) { delete state.pendingFiles[id]; continue; }
    const buf = await res.arrayBuffer();
    await api(`/v1/files/${id}`, { method: "PUT", body: buf, headers: { "Content-Type": res.headers.get("Content-Type")!, "X-File-Name": res.headers.get("X-File-Name") ?? "", "X-Sha256": await sha256(buf) } });
    delete state.pendingFiles[id]; changed();
  }
}

/** Returns an object URL for the file, from the local cache or else downloaded (and then cached). */
export async function openFile(fileId: string): Promise<string> {
  const cache = await caches.open(FILE_CACHE);
  let res = await cache.match(fileKey(fileId));
  if (!res) {
    const dl = await api(`/v1/files/${fileId}`);
    await cache.put(fileKey(fileId), dl.clone());
    res = dl;
  }
  return URL.createObjectURL(await res.blob());
}
export async function hasLocalFile(fileId: string) { return !!(await (await caches.open(FILE_CACHE)).match(fileKey(fileId))); }

// ---------- Backup ----------

export function exportBackup() {
  return JSON.stringify({ exportedAt: now(), records: Object.values(state.records) }, null, 2);
}
export function importBackup(json: string) {
  const recs: Rec[] = JSON.parse(json).records ?? [];
  for (const r of recs) {
    const local = state.records[r.id];
    if (!local || local.updatedAt < r.updatedAt) { state.records[r.id] = r; state.dirty[r.id] = true; }
  }
  changed(); scheduleSync();
  return recs.length;
}
