// Talks to the Mission App API (missions/app/api/openapi.yaml). Bearer token per device.
// The token and server address are per browser (localStorage), never sent anywhere else.

export const DEFAULT_API = "https://api.hesent.me";
const KEY_TOKEN = "missie.token";
const KEY_API = "missie.api";
const KEY_DEVICE = "missie.device";

function read(key, fallback = null) {
  try { return localStorage.getItem(key) ?? fallback; } catch { return fallback; }
}
function write(key, value) {
  try {
    if (value == null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch { /* private window: the session simply lasts this visit */ }
}

export const config = {
  get apiUrl() { return (read(KEY_API) || DEFAULT_API).replace(/\/+$/, ""); },
  set apiUrl(v) { write(KEY_API, v ? v.trim().replace(/\/+$/, "") : null); },
  get deviceName() { return read(KEY_DEVICE) || "Web browser"; },
  set deviceName(v) { write(KEY_DEVICE, v || null); },
};

export const session = {
  get token() { return read(KEY_TOKEN); },
  set token(v) { write(KEY_TOKEN, v); },
};

export class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

let onUnauthorized = () => {};
export function setUnauthorizedHandler(fn) { onUnauthorized = fn; }

async function request(method, path, { body, raw, type, headers = {} } = {}) {
  const h = { ...headers };
  if (session.token) h.Authorization = `Bearer ${session.token}`;
  let payload;
  if (raw !== undefined) {
    payload = raw;
    h["Content-Type"] = type || "application/octet-stream";
  } else if (body !== undefined) {
    payload = JSON.stringify(body);
    h["Content-Type"] = "application/json";
  }
  let res;
  try {
    res = await fetch(config.apiUrl + path, { method, headers: h, body: payload });
  } catch {
    throw new ApiError(0, "offline", "Can't reach the server. Check your connection.");
  }
  if (res.status === 204) return null;
  if (!res.ok) {
    let err = {};
    try { err = (await res.json()).error ?? {}; } catch { /* not JSON */ }
    if (res.status === 401 && session.token) onUnauthorized();
    throw new ApiError(res.status, err.code ?? "http", err.message ?? res.statusText);
  }
  return res;
}

async function json(method, path, opts) {
  const res = await request(method, path, opts);
  return res ? res.json() : null;
}

export const api = {
  get: (path) => json("GET", path),
  put: (path, body) => json("PUT", path, { body }),
  post: (path, body) => json("POST", path, { body }),
  del: (path) => request("DELETE", path).then(() => null),
  /** Raw body (file bytes). Returns the parsed JSON answer. */
  upload: (path, file, fileName) => json("PUT", path, {
    raw: file,
    type: file.type,
    headers: { "X-File-Name": encodeURIComponent(fileName) },
  }),
  /** Downloads a file with the login token and returns a Blob. */
  blob: (path) => request("GET", path).then((r) => r.blob()),

  login(email, password) {
    return json("POST", "/v1/auth/login", {
      body: { email, password, device: deviceInfo() },
    });
  },
  setup(setupSecret, email, password, name) {
    return json("POST", "/v1/auth/setup", {
      body: { setupSecret, email, password, name, device: deviceInfo() },
    });
  },
  logout: () => request("POST", "/v1/auth/logout").then(() => null).catch(() => null),
  changePassword: (currentPassword, newPassword) =>
    request("POST", "/v1/auth/password", { body: { currentPassword, newPassword } }).then(() => null),
  me: () => json("GET", "/v1/me"),
  devices: () => json("GET", "/v1/devices"),
  exportAll: () => request("GET", "/v1/export").then((r) => r.blob()),
};

function deviceInfo() {
  return { name: config.deviceName, platform: "web", appVersion: "1.0.0" };
}
