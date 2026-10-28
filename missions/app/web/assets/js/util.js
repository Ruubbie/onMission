// Shared constants and helpers. Enum values match the API contract (missions/app/api/openapi.yaml)
// and the Windows app's Lists / Look classes, so both clients read the same records.

export const COLLECTIONS = [
  "tasks", "checklists", "partners", "gifts", "budget", "sellItems",
  "packing", "notes", "documents", "contacts", "newsletters", "settings",
];

export const AREAS = [
  "visa", "admin", "finance", "support", "newsletter", "selling", "packing", "housing",
  "health", "insurance", "church", "travel", "ywam", "personal", "other",
];
export const TASK_STATUSES = ["todo", "doing", "waiting", "done", "skipped"];
export const PRIORITIES = ["low", "normal", "high"];
export const PARTNER_STAGES = ["idea", "to-ask", "asked", "thinking", "committed", "giving", "declined", "paused"];
export const PARTNER_CATEGORIES = ["", "A", "B", "C", "K"];
export const BUDGET_KINDS = ["expense", "income", "saving"];
export const CURRENCIES = ["EUR", "NZD"];
export const RECURRENCES = ["once", "monthly", "yearly"];
export const BUDGET_PHASES = ["setup", "monthly"];
export const SELL_STATUSES = ["decide", "to-list", "listed", "reserved", "sold", "given-away", "keep", "store"];
export const BAGS = ["checked", "carry-on", "personal", "ship", "buy-there", "leave"];
export const NOTE_KINDS = ["note", "prayer", "journal", "meeting", "idea"];
export const NEWSLETTER_STATUSES = ["idea", "draft", "ready", "sent"];
export const DOC_KINDS = [
  "passport", "visa", "insurance", "ticket", "id", "bank", "medical", "diploma", "reference", "contract", "receipt", "letter", "other",
];

export const LABELS = {
  tasks: "Task", checklists: "Checklist", partners: "Partner", budget: "Budget line", sellItems: "Sell item",
  packing: "Packing item", notes: "Note", documents: "Document", contacts: "Contact", newsletters: "Newsletter issue",
};

export const BAG_LABEL = {
  checked: "Checked bag", "carry-on": "Carry-on", personal: "Personal item", ship: "Ship ahead",
  "buy-there": "Buy in NZ", leave: "Leave behind",
};
export const BAG_LIMIT_KG = { checked: 23, "carry-on": 7 };

// Accent colours by name (Theme/Converters.cs Look)
export const COLOR = {
  yellow: "#D9A13B", pink: "#E5774A", green: "#5C7448", lime: "#EE9AA8", purple: "#A9CCE0",
  sand: "#E9DFCE", grey: "#C9BFB0", paper: "#F4EDE1",
};

export function stageColor(stage) {
  return { idea: "grey", "to-ask": "sand", asked: "yellow", thinking: "purple", committed: "lime", giving: "green", declined: "pink" }[stage] ?? "paper";
}
export function sellColor(status) {
  return { decide: "grey", "to-list": "sand", listed: "yellow", reserved: "purple", sold: "green", "given-away": "lime", keep: "paper" }[status] ?? "pink";
}
export function bagColor(bag) {
  return { checked: "yellow", "carry-on": "green", personal: "purple", ship: "sand", "buy-there": "lime" }[bag] ?? "grey";
}
export function noteKindColor(kind) {
  return { prayer: "purple", journal: "sand", meeting: "green", idea: "lime" }[kind] ?? "yellow";
}
export function docColor(kind) {
  return {
    passport: "purple", id: "purple", visa: "green", insurance: "pink", medical: "pink", ticket: "yellow",
    bank: "lime", receipt: "lime", diploma: "sand", reference: "sand",
  }[kind] ?? "grey";
}
export function areaColor(area) {
  return {
    visa: "purple", admin: "grey", finance: "green", support: "pink", newsletter: "pink", selling: "sand",
    packing: "lime", housing: "sand", health: "pink", insurance: "purple", church: "yellow", travel: "lime",
    ywam: "yellow", personal: "sand", other: "grey",
  }[area] ?? "sand";
}
export function priorityColor(p) {
  return { high: "pink", normal: "sand", low: "grey" }[p] ?? "sand";
}
export function statusColor(s) {
  return { todo: "sand", doing: "yellow", waiting: "purple", done: "green", skipped: "grey" }[s] ?? "sand";
}

// ---------- ids -------------------------------------------------------------------------------

// crypto.randomUUID only exists on https:// and localhost; over plain http:// build a v4 UUID by hand.
export function newId() {
  if (typeof crypto.randomUUID === "function") return crypto.randomUUID();
  const b = crypto.getRandomValues(new Uint8Array(16));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  const h = [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

// ---------- dates (plain yyyy-mm-dd strings, local calendar) -------------------------------------

const pad = (n) => String(n).padStart(2, "0");

export function ymd(d = new Date()) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}
export function todayStr() { return ymd(new Date()); }

// Day index of a yyyy-mm-dd string, DST-free, so differences are whole days.
export function dayIndex(s) {
  const [y, m, d] = s.split("-").map(Number);
  return Date.UTC(y, m - 1, d) / 86400000;
}
export function dayDiff(a, b) { return dayIndex(a) - dayIndex(b); }
export function addDays(s, n) {
  const [y, m, d] = s.split("-").map(Number);
  return ymd(new Date(y, m - 1, d + n));
}
export function parseDay(s) {
  if (!s) return null;
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}
const dayFmt = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", year: "numeric" });
const dayShortFmt = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short" });
const weekdayFmt = new Intl.DateTimeFormat("en-GB", { weekday: "long" });
export function fmtDay(s) { return s ? dayFmt.format(parseDay(s)) : ""; }
export function fmtDayShort(s) { return s ? dayShortFmt.format(parseDay(s)) : ""; }
export function fmtWeekday(s) { return s ? weekdayFmt.format(parseDay(s)).toLowerCase() : ""; }

/** Due date relative to today, as the desktop app shows it: "today", "3 days late", "friday", "12 Nov". */
export function dueText(due, today) {
  if (!due) return "";
  const days = dayDiff(due, today);
  if (days === 0) return "today";
  if (days === 1) return "tomorrow";
  if (days === -1) return "yesterday";
  if (days < -1) return `${-days} days late`;
  if (days < 7) return fmtWeekday(due);
  return fmtDayShort(due);
}

export function fmtDateTime(iso) {
  if (!iso) return "";
  return new Date(iso).toLocaleString("en-GB", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
}

// ---------- money (integer cents, nl-NL display: € 1.234,50) ------------------------------------

const moneyFmt = new Intl.NumberFormat("nl-NL", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const wholeFmt = new Intl.NumberFormat("nl-NL", { maximumFractionDigits: 0 });

export function euro(cents) { return cents == null ? "" : "€ " + moneyFmt.format(cents / 100); }
export function plainMoney(cents) { return cents == null ? "" : moneyFmt.format(cents / 100); }
export function wholeEuro(cents) { return cents == null ? "" : "€ " + wholeFmt.format(Math.round(cents / 100)); }

/** "1.234,50", "1234,5", "12.50", "€ 12", "45" -> cents, or null when not a number. */
export function parseCents(text) {
  if (text == null) return null;
  let s = String(text).replace(/€|EUR/gi, "").replace(/\s/g, "");
  if (!s) return null;
  const lastComma = s.lastIndexOf(",");
  const lastDot = s.lastIndexOf(".");
  const sep = Math.max(lastComma, lastDot);
  let normalized;
  if (sep >= 0 && [1, 2].includes(s.length - sep - 1)) {
    const intPart = s.slice(0, sep).replace(/[.,]/g, "");
    normalized = intPart + "." + s.slice(sep + 1);
  } else {
    normalized = s.replace(/[.,]/g, "");
  }
  if (!/^-?\d+(\.\d+)?$/.test(normalized)) return null;
  return Math.round(parseFloat(normalized) * 100);
}

/** Cents in EUR for an amount in a given currency (NZD uses the rate "NZD per EUR"). */
export function toEurCents(cents, currency, nzdPerEur) {
  if (cents == null) return 0;
  if (currency === "NZD") return Math.round(cents / (nzdPerEur || 1.85));
  return cents;
}

// ---------- quick add: "call bank fri !  #finance" --------------------------------------------

const DAYS = {
  mon: 1, monday: 1, ma: 1, maandag: 1,
  tue: 2, tues: 2, tuesday: 2, di: 2, dinsdag: 2,
  wed: 3, wednesday: 3, wo: 3, woensdag: 3,
  thu: 4, thur: 4, thurs: 4, thursday: 4, do: 4, donderdag: 4,
  fri: 5, friday: 5, vr: 5, vrijdag: 5,
  sat: 6, saturday: 6, za: 6, zaterdag: 6,
  sun: 0, sunday: 0, zo: 0, zondag: 0,
};

export function tryDate(token, today) {
  const t = token.toLowerCase();
  if (t === "today" || t === "vandaag") return today;
  if (t === "tomorrow" || t === "tmr" || t === "morgen") return addDays(today, 1);
  if (t === "overmorgen") return addDays(today, 2);
  if (t === "nextweek") return addDays(today, 7);
  if (t in DAYS) {
    const current = new Date(dayIndex(today) * 86400000).getUTCDay();
    const diff = (DAYS[t] - current + 7) % 7;
    return addDays(today, diff === 0 ? 7 : diff);
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(t)) return t;
  const m = /^(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?$/.exec(t);
  if (m) {
    const day = Number(m[1]);
    const month = Number(m[2]);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    let year;
    if (m[3]) {
      year = Number(m[3]);
      if (year < 100) year += 2000;
    } else {
      year = Number(today.slice(0, 4));
      const candidate = `${year}-${pad(month)}-${pad(Math.min(day, 31))}`;
      if (candidate < today) year++;
    }
    const days = new Date(year, month, 0).getDate();
    if (day > days) return null;
    return `${year}-${pad(month)}-${pad(day)}`;
  }
  return null;
}

/** Returns the fields of a task created from one line of text. */
export function parseQuickTask(input, today = todayStr()) {
  const task = { status: "todo", priority: "normal" };
  const kept = [];
  const raw = input.trim().replace(/^#/, "").trim().split(/\s+/).filter(Boolean);
  raw.forEach((token, i) => {
    let t = token;
    if (/^!{1,3}$/.test(t)) { task.priority = "high"; return; }
    if (t.length > 1 && t.endsWith("!") && i === raw.length - 1) {
      task.priority = "high";
      t = t.replace(/!+$/, "");
    }
    if (t.startsWith("#") && t.length > 1 && AREAS.includes(t.slice(1).toLowerCase())) {
      task.area = t.slice(1).toLowerCase();
      return;
    }
    if (!task.dueDate) {
      const d = tryDate(t, today);
      if (d) { task.dueDate = d; return; }
    }
    kept.push(t);
  });
  task.title = kept.join(" ") || input.trim();
  return task;
}

// ---------- Markdown (notes and newsletters): headings, bold, italics, lists, paragraphs ----------

function esc(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
function inline(s) {
  return esc(s)
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/(^|[^*])\*(.+?)\*/g, "$1<em>$2</em>")
    .replace(/`([^`]+)`/g, "<code>$1</code>");
}
/** Escapes first, then formats. The result is safe to assign to innerHTML. */
export function markdownToHtml(src = "") {
  const out = [];
  let list = false;
  let para = [];
  const flushPara = () => { if (para.length) { out.push(`<p>${para.map(inline).join("<br>")}</p>`); para = []; } };
  const closeList = () => { if (list) { out.push("</ul>"); list = false; } };
  for (const line of src.split(/\r?\n/)) {
    const heading = /^(#{1,3})\s+(.*)$/.exec(line);
    const bullet = /^\s*[-*]\s+(.*)$/.exec(line);
    if (heading) {
      flushPara(); closeList();
      out.push(`<h${heading[1].length}>${inline(heading[2])}</h${heading[1].length}>`);
    } else if (bullet) {
      flushPara();
      if (!list) { out.push("<ul>"); list = true; }
      out.push(`<li>${inline(bullet[1])}</li>`);
    } else if (!line.trim()) {
      flushPara(); closeList();
    } else {
      closeList();
      para.push(line);
    }
  }
  flushPara(); closeList();
  return out.join("\n");
}

// ---------- CSV (export: UTF-8 with BOM, commas; import: comma, semicolon or tab) ----------------

function csvCell(v) {
  const s = v == null ? "" : String(v);
  return /[",;\r\n\t]/.test(s) || s !== s.trim() ? `"${s.replace(/"/g, '""')}"` : s;
}
export function toCsv(columns, rows) {
  const head = columns.map((c) => csvCell(c.label)).join(",");
  const body = rows.map((r) => columns.map((c) => csvCell(c.get(r))).join(","));
  return "﻿" + [head, ...body].join("\r\n");
}
export function parseCsv(text) {
  const clean = text.replace(/^﻿/, "");
  const first = clean.split(/\r?\n/, 1)[0];
  const counts = { ",": 0, ";": 0, "\t": 0 };
  for (const ch of first) if (ch in counts) counts[ch]++;
  const sep = Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
  const rows = [];
  let row = [];
  let cell = "";
  let quoted = false;
  for (let i = 0; i < clean.length; i++) {
    const ch = clean[i];
    if (quoted) {
      if (ch === '"' && clean[i + 1] === '"') { cell += '"'; i++; }
      else if (ch === '"') quoted = false;
      else cell += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === sep) { row.push(cell); cell = ""; }
    else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && clean[i + 1] === "\n") i++;
      row.push(cell); rows.push(row); row = []; cell = "";
    } else cell += ch;
  }
  if (cell || row.length) { row.push(cell); rows.push(row); }
  const [header, ...data] = rows.filter((r) => r.some((c) => c.trim()));
  if (!header) return [];
  return data.map((r) => Object.fromEntries(header.map((h, i) => [h.trim(), (r[i] ?? "").trim()])));
}

export function download(filename, content, type = "text/csv;charset=utf-8") {
  const blob = content instanceof Blob ? content : new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/** yyyy-mm-dd from a typed date. Accepts 2026-10-08 or 8-10-2026 (or 8/10/2026). */
export function parseDateInput(text) {
  const t = (text || "").trim();
  if (!t) return null;
  return tryDate(t, todayStr()) ?? null;
}

export function sortBy(list, key, dir = 1) {
  return [...list].sort((a, b) => {
    const x = a[key] ?? "";
    const y = b[key] ?? "";
    return x < y ? -dir : x > y ? dir : 0;
  });
}

export function sha256Hex(buffer) {
  return crypto.subtle.digest("SHA-256", buffer).then((d) =>
    [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join(""));
}

export function guessDocKind(fileName) {
  const n = fileName.replace(/\.[^.]+$/, "").toLowerCase();
  const map = [
    ["passport", ["paspoort", "passport", "pasport"]],
    ["visa", ["visa", "visum", "whv", "working holiday", "nzeta", "eta"]],
    ["insurance", ["verzekering", "insurance", "polis", "zorgpas"]],
    ["ticket", ["ticket", "boarding", "vlucht", "flight", "e-ticket", "itinerary", "booking"]],
    ["id", ["identiteit", "idkaart", "id-kaart", "id card", "rijbewijs", "license", "licence"]],
    ["bank", ["bank", "iban", "rekening", "afschrift", "statement"]],
    ["medical", ["medisch", "medical", "vaccin", "inenting", "health", "huisarts", "xray", "x-ray"]],
    ["diploma", ["diploma", "certificaat", "certificate", "getuigschrift"]],
    ["reference", ["referentie", "reference", "aanbeveling", "recommendation"]],
    ["contract", ["contract", "overeenkomst", "agreement", "huur", "lease"]],
    ["receipt", ["bon", "receipt", "factuur", "invoice", "kwitantie"]],
    ["letter", ["brief", "letter", "uitnodiging", "invitation", "acceptance"]],
  ];
  for (const [kind, words] of map) if (words.some((w) => n.includes(w))) return kind;
  return "other";
}

export function formatBytes(n) {
  if (n == null) return "";
  if (n < 1024) return `${n} B`;
  if (n < 1048576) return `${(n / 1024).toFixed(0)} KB`;
  return `${(n / 1048576).toFixed(1)} MB`;
}

/** Money with its currency: "€ 12,50" or "NZ$ 12,50". */
export function fmtMoney(cents, currency = "EUR") {
  if (cents == null) return "";
  return currency === "NZD" ? `NZ$ ${plainMoney(cents)}` : euro(cents);
}
