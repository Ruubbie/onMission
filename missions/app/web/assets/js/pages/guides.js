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
    <img class="abs art pic in" src="assets/art/guides.webp" alt="" style="left:192px;top:146px;width:188px">
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
