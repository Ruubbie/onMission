// Guides: short reads for before you go. The text is bundled (guides-data.js); what you've read is
// kept on this device only, like the app's per-device progress. Port of prototype.html PAGES.guides.

import { I, anim } from "../motion.js";
import { esc } from "../ui.js";
import { GUIDES } from "./guides-data.js";

export const title = "Guides";
export const parent = "move";
export const kick = "Guides";

const KEY = "missie.guides";

function stored() {
  try { return JSON.parse(localStorage.getItem(KEY)) ?? {}; } catch { return {}; }
}

/** 0–1 for one guide: 1 once it is read. */
export function progressOf(i) {
  return stored()[i] ?? GUIDES[i].p;
}

export function markRead(i) {
  const s = stored();
  s[i] = 1;
  try { localStorage.setItem(KEY, JSON.stringify(s)); } catch { /* private window: it simply isn't remembered */ }
}

export function guideProgress() {
  return GUIDES.filter((_, i) => progressOf(i) >= 1).length;
}

function right(i) {
  const p = progressOf(i);
  return p >= 1
    ? `<span class="gread">${I.check.replace('pathLength="1" ', "")}Read</span>`
    : `<span class="gbar"><i style="width:${p * 100}%"></i></span>`;
}

export function build() {
  const read = guideProgress();
  return `
    <div class="abs hand hi in">Read before you go</div>
    <div class="abs disp bign in">${GUIDES.length}</div>
    <div class="abs cap cp in" data-cp>Guides<br>${read} read so far</div>
    <svg class="abs art" style="left:190px;top:150px;overflow:visible" width="180" height="160" viewBox="0 0 180 160"><g class="ln">
      <path class="bgf" d="M90 30 C 64 16, 34 14, 8 22 L8 140 C 34 132, 64 134, 90 148 Z"/>
      <path class="bgf" d="M90 30 C 116 16, 146 14, 172 22 L172 140 C 146 132, 116 134, 90 148 Z"/>
      <path d="M24 52 C 44 48, 62 50, 76 56 M24 74 C 44 70, 62 72, 76 78 M24 96 C 40 92, 56 94, 70 98"/>
      <path d="M104 52 C 118 48, 138 46, 156 50 M104 74 C 118 70, 138 68, 156 72"/>
    </g></svg>
    <div class="sheet"><div class="sec">Guides <b>${GUIDES.length}</b></div><div class="scroll" data-list>${
      GUIDES.map((g, i) => `<div class="rw tap" data-guide="${i}"><div class="tx"><div class="t1">${esc(g.t)}</div><div class="t2">${esc(g.m)} read</div></div>${right(i)}</div>`).join("")
    }</div></div>`;
}

export function init(root) {
  root.querySelectorAll(".gbar i").forEach((b, i) => anim(b, [{ width: "0%" }, { width: b.style.width }], { duration: 800, delay: 500 + i * 90, easing: "cubic-bezier(.2,.85,.25,1)" }));
  root.querySelector("[data-list]").addEventListener("click", (e) => {
    const r = e.target.closest("[data-guide]");
    if (r) location.hash = `#/guide/${r.dataset.guide}`;
  });
}
