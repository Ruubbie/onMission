// Small helpers shared by the screens: escaping, icons, the toast, the rings and the entrance motion.
// The look itself lives in app.css (Tomato Flood, see design/tomato-flood/HANDOFF.md).

import { I, anim, draw } from "./motion.js";

/** Escapes text for innerHTML. Every piece of user data goes through this. */
export function esc(s) {
  return String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

/** The inline Lucide icon for a key from motion.js, e.g. icon("sun"). */
export function icon(name) {
  return I[name] ?? "";
}

/** A ring button: the round tick that fills and draws its check when done. */
export function ring(done, label = "Done") {
  return `<button class="ring ${done ? "ticked" : ""}" data-ring aria-label="${esc(label)}">${I.check}</button>`;
}

let toastTimer;
/** The ink capsule that confirms a quiet action. */
export function toast(message, { bad = false } = {}) {
  const el = document.getElementById("toast");
  if (!el) return;
  el.querySelector("#toastTx").textContent = message;
  el.classList.toggle("bad", bad);
  el.classList.add("on");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("on"), 2200);
}

/** Entrance: the poster pieces rise in a stagger, the sheet glides up. */
export function rise(root, delay = 0) {
  root.querySelectorAll(".in").forEach((el, i) => anim(el, [
    { opacity: 0, transform: "translateY(16px)" },
    { opacity: 1, transform: "none" },
  ], { duration: 480, delay: delay + i * 50, easing: "cubic-bezier(.2,.8,.2,1)" }));
  const sheet = root.querySelector(".sheet");
  if (sheet) anim(sheet, [
    { transform: "translateY(46px)", opacity: 0.4 },
    { transform: "none", opacity: 1 },
  ], { duration: 520, delay, easing: "cubic-bezier(.2,.85,.25,1)" });
}

/** Line drawings draw themselves in (re-exported so screens need one import). */
export { draw };

/** Slides a list in from the side it came from. dir: 1 = from the right, -1 = from the left. */
export function slideIn(el, dir) {
  return anim(el, [
    { opacity: 0, transform: `translateX(${dir * 40}px)` },
    { opacity: 1, transform: "none" },
  ], { duration: 380, easing: "cubic-bezier(.2,.85,.25,1)" });
}

/** Collapses a row out of a list: height to 0, slide right, fade. Resolves when done. */
export function fold(row) {
  row.style.overflow = "hidden";
  const h = row.offsetHeight;
  return anim(row, [
    { height: `${h}px`, opacity: 1 },
    { height: "0px", opacity: 0, paddingTop: "0px", paddingBottom: "0px", transform: "translateX(30px)" },
  ], { duration: 360, easing: "cubic-bezier(.4,0,.2,1)", fill: "forwards" });
}

/** A short pop when something lands. */
export function pop(el) {
  return anim(el, [{ transform: "scale(1)" }, { transform: "scale(1.18)" }, { transform: "scale(1)" }], { duration: 460, easing: "cubic-bezier(.3,1.6,.5,1)" });
}

/** Swaps text with the old line rolling up and the new one coming from below. */
export async function swapText(el, html, dir = 1) {
  await anim(el, [
    { opacity: 1, transform: "none" },
    { opacity: 0, transform: `translateY(${-dir * 14}px)` },
  ], { duration: 170, easing: "ease-in", fill: "forwards" });
  el.innerHTML = html;
  el.getAnimations().forEach((a) => a.cancel());
  anim(el, [
    { opacity: 0, transform: `translateY(${dir * 14}px)` },
    { opacity: 1, transform: "none" },
  ], { duration: 340, easing: "cubic-bezier(.2,.85,.25,1)" });
}

/** Segmented underline or pill: moves the highlight bar under the chosen button. */
export function placeBar(bar, on) {
  if (!bar || !on) return;
  bar.style.left = `${on.offsetLeft + 10}px`;
  bar.style.width = `${on.offsetWidth - 20}px`;
}

/** Tick count helper for "3 of 5 done" style lines. */
export const plural = (n, one, many) => (n === 1 ? one : many);

/**
 * Pills with a tomato highlight that slides to the chosen one. items: [id, label, count?].
 * cb(id, dir) runs when the choice changes; dir is 1 when it moves right.
 */
export function mkPills(el, items, cur, cb) {
  el.innerHTML = `<i class="pp"></i>` + items.map(([id, label, n]) =>
    `<button class="pl ${id === cur ? "on" : ""}" data-pl="${esc(id)}">${esc(label)}${n != null ? `<i>${n}</i>` : ""}</button>`).join("");
  const bar = el.querySelector(".pp");
  placeBar(bar, el.querySelector(`[data-pl="${cur}"]`));
  el.onclick = (e) => {
    const b = e.target.closest("[data-pl]");
    if (!b || b.dataset.pl === cur) return;
    const ids = items.map((x) => x[0]);
    const dir = ids.indexOf(b.dataset.pl) > ids.indexOf(cur) ? 1 : -1;
    cur = b.dataset.pl;
    el.querySelectorAll(".pl").forEach((x) => x.classList.toggle("on", x === b));
    placeBar(bar, b);
    cb(cur, dir);
  };
}

/** Set while a moment plays (a prayer, the Answered flood), so store updates wait until it ends. */
export const hold = { on: false };

const deskQuery = matchMedia("(min-width: 900px)");
/** True on a desktop window (the sidebar layout). Screens build a wider layout then; main.js redraws when it changes. */
export const isDesk = () => deskQuery.matches;
