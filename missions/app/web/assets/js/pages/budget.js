// Budget: what comes in and goes out each month, and what is still to save before you go. A balance
// scale tips toward the heavier side. Port of prototype.html PAGES.budget. Lines are budget records.

import { store } from "../store.js";
import { I, tween, spring } from "../motion.js";
import { esc, slideIn, placeBar, swapText, toast } from "../ui.js";
import { fmtMoney, toEurCents } from "../util.js";
import { euroWhole, monthlyEur } from "./money.js";

export const title = "Budget";
export const parent = "move";
export const kick = "Budget";

const PHASES = [["monthly", "Every month"], ["setup", "Before you go"]];
let phase = "monthly";

const lines = (p) => store.list("budget").filter((b) => (b.phase ?? "monthly") === p).sort((a, b) => (a.label ?? "").localeCompare(b.label ?? ""));

function summary(p) {
  const rate = store.settings().nzdPerEur;
  const all = store.list("budget");
  if (p === "monthly") {
    const inn = all.filter((b) => b.kind === "income" && (b.phase ?? "monthly") === "monthly").reduce((s, b) => s + monthlyEur(b, rate), 0);
    const out = all.filter((b) => b.kind !== "income" && (b.phase ?? "monthly") === "monthly").reduce((s, b) => s + monthlyEur(b, rate), 0);
    const left = inn - out;
    return {
      hi: "Left over each month",
      big: `${left < 0 ? "−" : "+"}${euroWhole(Math.abs(left))}`,
      cp: `${euroWhole(inn)} in<br>${euroWhole(out)} out`,
      tilt: clampTilt(-((inn - out) / (inn + out || 1)) * 60),
    };
  }
  const setup = all.filter((b) => b.phase === "setup" && b.kind !== "income");
  const total = setup.reduce((s, b) => s + toEurCents(b.amountCents ?? 0, b.currency, rate), 0);
  const paid = setup.filter((b) => b.paid).reduce((s, b) => s + toEurCents(b.amountCents ?? 0, b.currency, rate), 0);
  const left = total - paid;
  return {
    hi: "Still to save",
    big: euroWhole(left),
    cp: `${euroWhole(paid)} saved<br>of ${euroWhole(total)}`,
    tilt: clampTilt(total ? (left / total) * 15 : 0),
  };
}

const clampTilt = (d) => Math.max(-14, Math.min(14, d));

export function build() {
  const s = summary(phase);
  return `
    <div class="abs hand hi in" data-hi>${esc(s.hi)}</div>
    <div class="abs disp in" data-n style="left:20px;top:140px;font-size:104px">${esc(s.big)}</div>
    <div class="abs cap in" data-cp style="left:24px;top:254px">${s.cp}</div>
    <img class="abs art pic in" src="assets/art/budget.webp" alt="" style="left:228px;top:208px;width:146px">
    <div class="sheet" style="padding-top:10px">
      <div class="seg" id="seg">${PHASES.map(([id, label]) => `<button data-phase="${id}" class="${id === phase ? "on" : ""}">${label}</button>`).join("")}<i class="bar"></i></div>
      <div class="scroll" data-list>${lines(phase).map(rowHtml).join("") || `<div class="rw"><div class="tx"><div class="t1">No lines yet</div><div class="t2">Add a budget line on the iPhone or in the Windows app for now.</div></div></div>`}</div>
    </div>`;
}

function rowHtml(b) {
  const inc = b.kind === "income";
  return `<div class="rw"><div class="tx"><div class="t1">${esc(b.label)}</div><div class="t2">${esc([inc ? "In" : "Out", b.category, b.recurrence].filter(Boolean).join(" · "))}</div></div>
    <span class="amt ${inc ? "pos" : ""}">${inc ? "+" : "−"}${esc(fmtMoney(b.amountCents, b.currency))}</span></div>`;
}

export function init(el, ctx) {
  const seg = el.querySelector("#seg");
  placeBar(seg.querySelector(".bar"), seg.querySelector(".on"));
  setTilt(el, 0);
  if (ctx.quiet) setTilt(el, summary(phase).tilt); else tip(el, summary(phase).tilt);

  seg.addEventListener("click", (e) => {
    const b = e.target.closest("[data-phase]");
    if (!b || b.dataset.phase === phase) return;
    const dir = PHASES.findIndex((p) => p[0] === b.dataset.phase) > PHASES.findIndex((p) => p[0] === phase) ? 1 : -1;
    phase = b.dataset.phase;
    document.dispatchEvent(new Event("app:refresh"));
    queueMicrotask(() => {
      const root = document.querySelector(".pg");
      if (!root) return;
      const s = summary(phase);
      swapText(root.querySelector("[data-hi]"), s.hi, dir);
      swapText(root.querySelector("[data-n]"), s.big, dir);
      swapText(root.querySelector("[data-cp]"), s.cp, dir);
      tip(root, s.tilt);
      slideIn(root.querySelector("[data-list]"), dir);
    });
  });
  el.querySelector("[data-list]").addEventListener("click", (e) => {
    if (e.target.closest(".more")) toast("A new line slides up here");
  });
}

function setTilt(el, d) {
  const a = (d * Math.PI) / 180, c = Math.cos(a) * 65, s = Math.sin(a) * 65;
  el.querySelector("[data-beam]")?.setAttribute("transform", `rotate(${d} 75 22)`);
  el.querySelector("[data-pl]")?.setAttribute("transform", `translate(${75 - c} ${22 - s})`);
  el.querySelector("[data-pr]")?.setAttribute("transform", `translate(${75 + c} ${22 + s})`);
  const tl = el.querySelector("[data-tl]"), tr = el.querySelector("[data-tr]");
  if (tl) { tl.setAttribute("x", 75 - c); tl.setAttribute("y", 22 - s + 74); }
  if (tr) { tr.setAttribute("x", 75 + c); tr.setAttribute("y", 22 + s + 74); }
}

function tip(el, to) {
  return tween(1300, (t) => setTilt(el, to * spring(t)));
}

