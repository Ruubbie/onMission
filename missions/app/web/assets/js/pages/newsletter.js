// Newsletters: the next letter to the people who give. Mark sent folds the letter into the envelope and
// sends it off along the dotted route; the next issue becomes the draft. Port of prototype.html
// PAGES.newsletters. Issues are newsletter records (number, title, status, sentAt).

import { store } from "../store.js";
import { anim, tween, ease, wait, I } from "../motion.js";
import { esc, toast, fold, swapText } from "../ui.js";
import { todayStr } from "../util.js";
import { patch } from "./common.js";

export const title = "Newsletters";
export const parent = "move";
export const kick = "Newsletters";

const STATUS = { idea: "Idea", draft: "Draft", ready: "Ready" };
const MONTH =(d) => d.toLocaleDateString("en-GB", { month: "short" }).toUpperCase();

function issues() {
  return store.list("newsletters").sort((a, b) => (b.number ?? 0) - (a.number ?? 0));
}

function nextDraft() {
  return issues().filter((n) => n.status !== "sent").sort((a, b) => (a.number ?? 0) - (b.number ?? 0))[0] ?? null;
}

function recipients() {
  return store.list("partners").filter((p) => p.newsletter).length;
}

export function build() {
  const draft = nextDraft();
  const when = draft?.plannedDate ? new Date(`${draft.plannedDate}T12:00:00`) : new Date(Date.now() + 30 * 86400000);
  return `
    <div class="abs hand hi in">Next letter</div>
    <div class="abs disp in" data-n style="left:18px;top:134px;font-size:140px;line-height:.8">${esc(MONTH(when))}</div>
    <div class="abs cap in" data-cp style="left:24px;top:276px">Due ${esc(when.toLocaleDateString("en-GB", { day: "numeric", month: "long" }))}<br>to ${recipients()} people</div>
    <svg class="abs art" style="left:0;top:0;overflow:visible;pointer-events:none" width="390" height="396" viewBox="0 0 390 396"><g class="ln">
      <path class="dots" data-route stroke-dasharray="1 7" d="M318 270 C 350 250, 352 204, 372 178 S 420 132, 460 120"/>
      <g data-env transform="translate(318 270)">
        <path class="crf" data-letter d="M-34 -50 L34 -50 L34 -12 L-34 -12 Z"/>
        <path class="bgf" d="M-46 -30 L46 -30 L46 30 L-46 30 Z"/>
        <path d="M-46 30 L-10 2 M46 30 L10 2"/>
        <path data-flap d="M-46 -30 L0 -62 L46 -30"/>
      </g>
    </g></svg>
    <div class="sheet"><div class="scroll" data-list>${sheetHtml(draft)}</div></div>`;
}

function sheetHtml(draft) {
  const sent = issues().filter((n) => n.status === "sent");
  // Unsent letters after the next one: ideas and drafts for later issues.
  const later = issues().filter((n) => n.status !== "sent" && n.id !== draft?.id).reverse();
  const hero = draft
    ? `<div class="hero" data-hero><div class="ht">${esc(draft.title || "Untitled letter")}</div><div class="t2">${esc(draft.status === "idea" ? "An idea so far" : "In draft")}</div><div class="acts"><button class="btn f" data-send>Mark sent</button><button class="btn o" data-open>Open draft</button></div></div>`
    : `<div class="hero" data-hero><div class="ht">Next letter</div><div class="t2">Nothing started yet.</div><div class="acts"><button class="btn f" data-new>Start a letter</button></div></div>`;
  return `<div class="sec">${draft ? "Draft" : "Up next"}</div>${hero}
    ${draft ? `<div class="sec">Later <b>${later.length}</b></div>
    ${later.map((n) => `<div class="rw tap" data-letter-id="${esc(n.id)}"><div class="tx"><div class="t1">${esc(n.title || "Untitled")}</div><div class="t2">${esc(n.number != null ? `Issue ${n.number}` : "Not numbered")} · ${esc(STATUS[n.status] ?? "Idea")}</div></div></div>`).join("")}
    <button class="btn o wide" data-new>${I.plus}New letter</button>` : ""}
    <div class="sec">Sent <b>${sent.length}</b></div>
    ${sent.map((n) => `<div class="rw tap" data-letter-id="${esc(n.id)}"><div class="tx"><div class="t1">${esc(n.title || "Untitled")}</div><div class="t2">${esc(n.number != null ? `Issue ${n.number}` : "Sent")}</div></div><span class="when">${esc(shortDay(n.sentAt))}</span></div>`).join("")}`;
}

export function init(el) {
  const list = el.querySelector("[data-list]");
  const env = el.querySelector("[data-env]");
  list.addEventListener("click", async (e) => {
    if (e.target.closest("[data-open]")) { location.hash = `#/letter/${nextDraft().id}`; return; }
    const row = e.target.closest("[data-letter-id]");
    if (row) { location.hash = `#/letter/${row.dataset.letterId}`; return; }
    if (e.target.closest("[data-new]")) {
      try {
        const n = await store.create("newsletters", { title: "New letter", number: nextNumber(), status: "idea", plannedDate: null, sentAt: null, body: "", webUrl: null, notes: null, public: true });
        if (n?.id) location.hash = `#/letter/${n.id}`;
      } catch (err) {
        toast(err.message || "That letter didn't save.", { bad: true });
      }
      return;
    }
    const b = e.target.closest("[data-send]");
    if (!b || b.disabled) return;
    const draft = nextDraft();
    if (!draft) return;
    b.disabled = true;
    await tween(260, (t) => env.querySelector("[data-letter]").setAttribute("transform", `translate(0 ${ease(t) * 34})`));
    await tween(300, (t) => env.querySelector("[data-flap]").setAttribute("d", `M-46 -30 L0 ${-62 + 68 * ease(t)} L46 -30`));
    const route = el.querySelector("[data-route]");
    const L = route.getTotalLength();
    await tween(950, (t) => {
      const k = t * t * (3 - 2 * t);
      const p = route.getPointAtLength(L * k), p2 = route.getPointAtLength(Math.min(L, L * k + 2));
      const ang = (Math.atan2(p2.y - p.y, p2.x - p.x) * 180) / Math.PI;
      env.setAttribute("transform", `translate(${p.x} ${p.y}) rotate(${ang * k}) scale(${1 - 0.45 * k})`);
    });
    env.style.opacity = 0;
    await fold(b.closest("[data-hero]"));
    await patch("newsletters", draft.id, { status: "sent", sentAt: new Date().toISOString() });
    toast("Letter marked as sent");
  });
}

function nextNumber() {
  return Math.max(0, ...store.list("newsletters").map((n) => n.number ?? 0)) + 1;
}

function shortDay(iso) {
  if (!iso) return "";
  return new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}
