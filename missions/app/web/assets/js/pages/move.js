// Move: the readiness for the move on tomato, and seven tiles, in three groups, to the pages that get you there.
// Checklists live on the Tasks tab (one link there), so they are not repeated here.
// Port of prototype.html #s-move. Readiness is the average of checklist progress, papers in the
// Vault and packing (HANDOFF.md §13 proposes this; it is a choice to confirm with Ruben).

import { store } from "../store.js";
import { I, tween, ease, playIcon, anim } from "../motion.js";
import { esc, rise, isDesk } from "../ui.js";
import { dayDiff, todayStr, parseDay } from "../util.js";
import { bucketTasks } from "./common.js";
import { guideProgress } from "./guides.js";

export const title = "Move";

const HUBS = {
  "Papers & money": [
    { route: "vault", icon: "lock", name: "Vault" },
    { route: "budget", icon: "euro", name: "Budget" },
    { route: "selling", icon: "tag", name: "Selling" },
  ],
  "Packing & guides": [
    { route: "packing", icon: "case", name: "Packing" },
    { route: "guides", icon: "book", name: "Guides" },
  ],
  "Writing": [
    { route: "newsletter", icon: "mail", name: "Newsletters" },
    { route: "notes", icon: "note", name: "Notes" },
  ],
};

/** Readiness: the average of checklist progress, papers in the Vault and packing (0–100). */
export function readiness() {
  const tasks = store.list("tasks").filter((t) => t.checklistId);
  const checklist = tasks.length ? tasks.filter((t) => t.status === "done").length / tasks.length : null;
  const docs = store.list("documents");
  const vault = docs.length ? docs.filter((d) => d.fileId).length / docs.length : null;
  const packing = store.list("packing").filter((p) => p.bag !== "leave");
  const packed = packing.length ? packing.filter((p) => p.packed).length / packing.length : null;
  const parts = [checklist, vault, packed].filter((x) => x != null);
  return parts.length ? Math.round((parts.reduce((s, x) => s + x, 0) / parts.length) * 100) : 0;
}

function status(route) {
  const today = todayStr();
  switch (route) {
    case "vault": {
      const missing = store.list("documents").filter((d) => !d.fileId).length;
      return { text: missing ? `${missing} missing` : "All in", alert: missing > 0 };
    }
    case "packing": {
      const items = store.list("packing").filter((p) => p.bag !== "leave");
      const pct = items.length ? Math.round((items.filter((p) => p.packed).length / items.length) * 100) : 0;
      return { text: `${pct}% packed`, alert: false };
    }
    case "budget":
      return { text: "On track", alert: false };
    case "selling": {
      const listed = store.list("sellItems").filter((s) => s.status === "listed").length;
      return { text: `${listed} listed`, alert: false };
    }
    case "newsletter": {
      const draft = store.list("newsletters").filter((n) => n.status !== "sent").sort((a, b) => (a.number ?? 0) - (b.number ?? 0))[0];
      return { text: draft ? (draft.title || "Draft") : "Nothing to send", alert: false };
    }
    case "notes":
      return { text: `${store.list("notes").length}`, alert: false };
    case "guides": {
      const read = guideProgress();
      return { text: `${read} read`, alert: false };
    }
    default:
      return { text: "", alert: false };
  }
}

export function build() {
  const s = store.settings();
  const dep = s.departureDate ? parseDay(s.departureDate) : null;
  const leaving = dep ? `Leaving ${dep.toLocaleDateString("en-GB", { day: "numeric", month: "long" })}` : "Set your departure date";
  const pct = readiness();
  return `
    <div class="abs hand hi in">${esc(leaving)}</div>
    <div class="abs disp big in">${pct}%</div>
    <div class="abs cap cp in">Ready<br>to go</div>
    <svg class="abs art" id="arcArt" style="left:0;top:236px" width="390" height="138" viewBox="0 0 390 138">
      <g class="ln">
        <path class="dots" stroke-dasharray="1 8" d="M34 112 C 110 6, 280 6, 356 112"/>
        <path id="arc" class="nodraw" pathLength="1" style="stroke-width:3.2;stroke-dasharray:0 1" d="M34 112 C 110 6, 280 6, 356 112"/>
        <circle class="crf" cx="34" cy="112" r="5"/><circle cx="356" cy="112" r="5"/>
        <g id="plane" class="nodraw"><path class="bgf" d="M-16 -9 L18 0 L-16 9 L-9 0 Z"/><path d="M-9 0 L18 0"/></g>
      </g>
      <text x="34" y="134" text-anchor="middle" font-family="Archivo" font-weight="800" font-size="12" letter-spacing="1.5" fill="#1E1A17">AMS</text>
      <text x="356" y="134" text-anchor="middle" font-family="Archivo" font-weight="800" font-size="12" letter-spacing="1.5" fill="#1E1A17">ZQN</text>
    </svg>
    <div class="sheet">${Object.entries(HUBS).map(([name, hubs], i) => `
      <div class="sec" style="margin-top:${i ? 18 : 0}px">${esc(name)}</div>
      <div class="grid">${hubs.map((h) => {
        const st = status(h.route);
        return `<button class="tile" data-route="${h.route}">${I[h.icon]}<span class="nm">${h.name}</span><span class="st ${st.alert ? "alert" : ""}">${esc(st.text)}</span></button>`;
      }).join("")}</div>`).join("")}${isDesk() ? panels() : ""}</div>`;
}

/** Desktop only: what's next on the checklists and which papers are still missing, under the tiles. */
function panels() {
  const lists = new Map(store.list("checklists").map((c) => [c.id, c]));
  const next = store.list("tasks")
    .filter((t) => t.checklistId && lists.has(t.checklistId) && !lists.get(t.checklistId).archived && t.status !== "done" && t.status !== "skipped")
    .sort((a, b) => (lists.get(a.checklistId).order ?? 0) - (lists.get(b.checklistId).order ?? 0) || (a.order ?? 0) - (b.order ?? 0));
  const missing = store.list("documents").filter((d) => !d.fileId).sort((a, b) => (a.title ?? "").localeCompare(b.title ?? ""));
  return `<div class="dash" style="margin-top:28px">
    <section class="card"><div class="sec">Next on your checklists <b>${next.length} left</b></div>
      ${next.slice(0, 6).map((t) => `<a class="rw tap" href="#/checklists"><span class="dbox">${I.list}</span><div class="tx"><div class="t1">${esc(t.title)}</div><div class="t2">${esc(lists.get(t.checklistId).title)}</div></div></a>`).join("")
        || `<div class="rw"><div class="tx"><div class="t1">Every list is done</div><div class="t2">Nothing left to tick off.</div></div></div>`}
      <a class="more" href="#/checklists">Checklists ${I.arrow}</a></section>
    <section class="card"><div class="sec">Papers still missing <b>${missing.length}</b></div>
      ${missing.slice(0, 6).map((d) => `<a class="rw tap" href="#/vault"><span class="dbox miss">${I.lock}</span><div class="tx"><div class="t1">${esc(d.title)}</div><div class="t2">Add a scan or photo</div></div></a>`).join("")
        || `<div class="rw"><div class="tx"><div class="t1">Nothing missing</div><div class="t2">Every paper is in the Vault.</div></div></div>`}
      <a class="more" href="#/vault">Vault ${I.arrow}</a></section>
  </div>`;
}

export function init(root) {
  const arc = root.querySelector("#arc"), plane = root.querySelector("#plane");
  if (arc && plane) along(arc, plane, pctFromReadiness(), 1600);
  const sheet = root.querySelector(".sheet");
  sheet.querySelectorAll(".tile").forEach((t, i) => anim(t, [{ opacity: 0, transform: "translateY(14px)" }, { opacity: 1, transform: "none" }], { duration: 420, delay: 140 + i * 35, easing: "cubic-bezier(.2,.85,.25,1)" }));
  sheet.querySelectorAll(".tile svg[data-la]").forEach((sv, i) => playIcon(sv, 260 + i * 70));
  sheet.addEventListener("click", (e) => {
    const t = e.target.closest(".tile");
    if (t) location.hash = `#/${t.dataset.route}`;
  });
}

function pctFromReadiness() {
  return Math.max(0.04, readiness() / 100);
}

function along(pathEl, dotEl, frac, ms) {
  const L = pathEl.getTotalLength();
  return tween(ms, (t) => {
    const f = ease(t) * frac;
    pathEl.style.strokeDasharray = `${f} 1`;
    const p = pathEl.getPointAtLength(L * f);
    const q = pathEl.getPointAtLength(Math.min(L, L * f + 1));
    const ang = (Math.atan2(q.y - p.y, q.x - p.x) * 180) / Math.PI;
    dotEl.setAttribute("transform", `translate(${p.x} ${p.y}) rotate(${ang})`);
  });
}
