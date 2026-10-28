// People: the monthly support on tomato, then the people waiting on you as rows with one action each.
// Port of prototype.html #s-people and its Say thanks and Check in moments.

import { store } from "../store.js";
import { I, tween, ease, anim, playIcon, wait } from "../motion.js";
import { esc, fold, toast, pop, isDesk } from "../ui.js";
import { todayStr } from "../util.js";
import { patch, waitingOnYou, initials, STAGE_LABEL, latestMessage, messageDay, replyMailto, markAnswered } from "./common.js";
import { openCheckin } from "../checkin.js";
import { euroWhole, supportTotals } from "./money.js";

export const title = "People";

export function build() {
  const { total, target, pct } = supportTotals();
  const waiting = waitingOnYou(store.list("partners"));
  const count = store.list("partners").length + store.list("contacts").length;
  return `
    <div class="abs hand hi in">Monthly support</div>
    <div class="abs disp big in">${euroWhole(total)}</div>
    <div class="abs cap cp in">${target ? `of ${euroWhole(target)} a month · ${pct}%` : "Set a monthly target in Settings"}</div>
    <svg class="abs art" id="trailArt" style="left:0;top:252px;overflow:visible" width="390" height="136" viewBox="0 0 390 136">
      <g class="ln">
        <path class="dots" stroke-dasharray="1 8" d="M20 124 C 90 122, 116 98, 160 92 S 238 64, 280 46 S 334 22, 354 18"/>
        <path id="trail" class="nodraw" pathLength="1" style="stroke-width:3.2;stroke-dasharray:0 1" d="M20 124 C 90 122, 116 98, 160 92 S 238 64, 280 46 S 334 22, 354 18"/>
        <path d="M354 18 L354 -10"/><path class="crf" d="M354 -10 L374 -3 L354 4"/>
        <path d="M200 134 L248 96 L268 112 L300 78 L352 134"/>
        <path d="M290 88 L294 84 L300 89 L305 83 L310 88"/>
        <circle id="walker" class="nodraw crf" cx="20" cy="124" r="6.5"/>
      </g>
    </svg>
    <div class="sheet" data-count="${count}">${isDesk() ? deskHtml(waiting) : sheetHtml(waiting)}</div>`;
}

function sheetHtml(waiting) {
  if (!waiting.length) {
    return `<div class="sec">Waiting on you</div><div class="rw"><div class="tx"><div class="t1">Nobody's waiting on you</div><div class="t2">Nice. Everyone has heard from you.</div></div></div>
      <button class="more" data-all>All people ${I.arrow}</button>`;
  }
  const shown = waiting.slice(0, 3);
  return `<div class="sec">Waiting on you <b>${waiting.length}</b></div>
    ${shown.map((p) => row(p)).join("")}
    <button class="more" data-all>All ${store.list("partners").length} people ${I.arrow}</button>`;
}

/** The desktop sheet: everyone waiting on you, beside where all your people are on the path. */
function deskHtml(waiting) {
  const partners = store.list("partners");
  const stages = Object.keys(STAGE_LABEL).map((st) => [st, partners.filter((p) => p.stage === st).length]).filter(([, n]) => n);
  const most = Math.max(1, ...stages.map(([, n]) => n));
  return `<div class="dash">
    <section class="card wide"><div class="sec">Waiting on you <b>${waiting.length}</b></div>
      <div class="cols">${waiting.map(row).join("") || `<div class="rw"><div class="tx"><div class="t1">Nobody's waiting on you</div><div class="t2">Nice. Everyone has heard from you.</div></div></div>`}</div>
      <button class="more" data-all>All ${partners.length} people ${I.arrow}</button></section>
    <section class="card"><div class="sec">Where everyone is</div>
      ${stages.map(([st, n]) => `<div class="bar-row"><span>${esc(STAGE_LABEL[st])}</span><div class="meter"><i style="width:${(n / most) * 100}%"></i></div><b>${n}</b></div>`).join("") || `<div class="t2">No people yet.</div>`}
    </section>
  </div>`;
}

function row(p) {
  if (p.replyWaiting === true) {
    const m = latestMessage(p);
    const sub = m ? `Wrote ${messageDay(m)} on hesent.me: “${m.text.replace(/\n/g, " ")}”` : "Wrote to you on hesent.me";
    return `<div class="rw tap" data-person="${esc(p.id)}"><span class="av">${esc(initials(p.name))}</span>
      <div class="tx"><div class="t1">${esc(p.name)}</div><div class="t2 late clamp">${esc(sub)}</div></div>
      <button class="btn sm f" data-action="reply">Reply</button></div>`;
  }
  const giving = p.stage === "giving";
  const thanked = p.thankedAt && p.thankedAt.slice(0, 10) === todayStr();
  const action = giving && !thanked ? { label: "Say thanks", kind: "f", id: "thanks" }
    : p.stage === "to-ask" ? { label: "Ask", kind: "o", id: "ask" }
    : { label: "Check in", kind: "o", id: "checkin" };
  const sub = thanked ? "Thanked just now" : STAGE_LABEL[p.stage] ?? p.stage;
  return `<div class="rw tap" data-person="${esc(p.id)}"><span class="av">${esc(initials(p.name))}</span>
    <div class="tx"><div class="t1">${esc(p.name)}</div><div class="t2">${esc(sub)}</div></div>
    <button class="btn sm ${action.kind}" data-action="${action.id}">${action.label}</button></div>`;
}

export function init(root) {
  const trail = root.querySelector("#trail");
  if (trail) along(trail, root.querySelector("#walker"), 0.62, 1500);

  root.addEventListener("click", async (e) => {
    if (e.target.closest("[data-all]")) { location.hash = "#/allpeople"; return; }
    const btn = e.target.closest("[data-action]");
    const row = e.target.closest("[data-person]");
    if (!row) return;
    const p = store.get("partners", row.dataset.person);
    if (!p) return;
    if (!btn) { location.hash = `#/partners/${p.id}`; return; }
    if (btn.dataset.action === "reply") {
      const url = replyMailto(p);
      if (!url) { location.hash = `#/partners/${p.id}`; return; }
      location.href = url;
      toast(`Marked ${p.name.split(" ")[0]}'s message as answered`);
      await wait(700);
      await fold(row);
      await markAnswered(p);
      return;
    }
    if (btn.dataset.action === "thanks") {
      btn.innerHTML = `${I.heart}Thanked`;
      playIcon(btn.querySelector("svg"));
      anim(btn, [{ transform: "scale(.85)" }, { transform: "scale(1.08)" }, { transform: "none" }], { duration: 420 });
      row.querySelector(".t2").textContent = "Thanked just now";
      await wait(700);
      await fold(row);
      await patch("partners", p.id, { thankedAt: new Date().toISOString() });
      return;
    }
    if (btn.dataset.action === "checkin") { openCheckin(p); return; }
    toast(`Opens a message to ${p.name}`);
  });
}

/** The people who need you, for the tab badge. */
export function countWaiting() {
  return waitingOnYou(store.list("partners")).length;
}

/** Walks a dot along the trail up to a fraction of it. */
function along(pathEl, dotEl, frac, ms) {
  const L = pathEl.getTotalLength();
  return tween(ms, (t) => {
    const f = ease(t) * frac;
    pathEl.style.strokeDasharray = `${f} 1`;
    const p = pathEl.getPointAtLength(L * f);
    dotEl.setAttribute("cx", p.x);
    dotEl.setAttribute("cy", p.y);
  });
}

