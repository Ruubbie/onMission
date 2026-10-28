// Prayer: one prayer at a time on tomato, a candle, and two buttons. I prayed lights the candle and
// counts up; Answered floods the screen gold and takes the prayer off the list. Swipe skips one.
// Port of prototype.html #s-prayer. Prayers are notes of kind "prayer" (prayedCount, answeredAt).

import { store } from "../store.js";
import { I, anim, wait, tween } from "../motion.js";
import { esc, toast, hold, isDesk } from "../ui.js";
import { todayStr } from "../util.js";
import { patch } from "./common.js";

export const title = "Prayer";

let index = 0;
let praying = false;
let lit = false;

function prayers() {
  return store.list("notes")
    .filter((n) => n.kind === "prayer" && !n.answeredAt)
    .sort((a, b) => (a.createdAt ?? "").localeCompare(b.createdAt ?? ""));
}

export function kick() {
  return `Prayer · ${prayers().length} open`;
}

export function build() {
  const list = prayers();
  const p = list[index] ?? null;
  // The stage keeps the phone's composition; on a desktop it is centred, with the list beside it.
  return `
    <div class="pstage">
    <div class="abs hand hi in">pray for</div>
    <div class="pcard" id="pcard">${card(p)}</div>
    <svg class="candle art" viewBox="0 0 120 190">
      <g id="glow" class="ln nodraw" opacity="0"><path d="M60 14v-9M36 26l-6-5M84 26l6-5M30 50h-9M90 50h9"/></g>
      <g class="ln">
        <path d="M60 74 L60 64"/>
        <path class="bgf" d="M38 80 L38 160 L82 160 L82 80"/>
        <path d="M38 80 A22 6 0 0 0 82 80 A22 6 0 0 0 38 80"/>
        <path d="M48 87 C 46 95, 48 103, 52 107"/>
        <path d="M14 160 L106 160"/>
        <path d="M22 160 C 24 175, 96 175, 98 160"/>
      </g>
      <g id="flame"><path d="M60 24 C 68 38, 74 44, 74 56 A 14 14 0 0 1 46 56 C 46 44, 52 38, 60 24 Z" fill="#E5774A" stroke="#1E1A17" stroke-width="2" stroke-linejoin="round"/><path d="M60 46 C 63 51, 66 54, 66 59 A 6 6 0 0 1 54 59 C 54 54, 57 51, 60 46 Z" fill="none" stroke="#D9A13B" stroke-width="2.2"/></g>
    </svg>
    <div class="abs hand amen" id="amen">Amen.</div>
    <div class="pacts"><button class="btn" id="answer" ${p ? "" : "disabled"}>Answered</button><button class="btn" id="prayed" ${p ? "" : "disabled"}>${I.flame}I prayed</button></div>
    <div class="pager" id="pager">${list.map((_, i) => `<i class="${i === index ? "on" : ""}"></i>`).join("")}</div>
    </div>
    ${isDesk() ? listHtml(list) : ""}
    <div id="ansFlood" aria-hidden="true"><div class="afin">
      <div class="abs disp in" style="left:22px;top:130px;font-size:74px">Answered!</div>
      <div class="abs hand in" data-what style="left:24px;right:24px;top:214px;font-size:29px;line-height:1.05;transform:rotate(-2deg)"></div>
      <svg class="abs art" style="left:95px;top:318px" width="200" height="190" viewBox="0 0 200 190">
        <g class="ln" style="stroke-width:2.6">
          <circle cx="100" cy="92" r="34" fill="#D9A13B"/>
          <path d="M100 50 V32 M142 92 H160 M58 92 H40 M130 62 L142 50 M70 62 L58 50 M130 122 L142 134 M70 122 L58 134"/>
          <path d="M4 178 C 40 152, 70 148, 100 162 C 130 146, 166 148, 196 174"/>
        </g>
      </svg>
      <div class="abs cap in" style="left:0;right:0;top:540px;text-align:center;font-size:18px">Saved in Prayer &amp; thanks</div>
    </div></div>`;
}

/** The desktop list beside the stage: every open prayer (click one to pray for it) and the answered ones. */
function listHtml(list) {
  const answered = store.list("notes").filter((n) => n.kind === "prayer" && n.answeredAt)
    .sort((a, b) => b.answeredAt.localeCompare(a.answeredAt));
  return `<aside class="sheet plist">
    <div class="sec">Praying for <b>${list.length}</b></div>
    ${list.map((p, i) => `<button class="rw tap ${i === index ? "cur" : ""}" data-pi="${i}"><div class="tx"><div class="t1">${esc(p.body || p.title)}</div><div class="t2">Prayed ${p.prayedCount ?? 0}×</div></div></button>`).join("")
      || `<div class="rw"><div class="tx"><div class="t1">No prayers yet</div><div class="t2">Add one with New and start with pray:</div></div></div>`}
    <div class="sec" style="margin-top:28px">Answered <b>${answered.length}</b></div>
    ${answered.slice(0, 10).map((p) => `<div class="rw"><div class="tx"><div class="t1">${esc(p.body || p.title)}</div><div class="t2">Answered ${esc(shortDay(p.answeredAt))}</div></div></div>`).join("")
      || `<div class="rw"><div class="tx"><div class="t2">Answered prayers are kept here.</div></div></div>`}
  </aside>`;
}

function card(p) {
  if (!p) return `<div class="pt">No prayers yet.</div><div class="pm">Add one with + and start with pray:</div>`;
  const added = p.createdAt ? `Added ${shortDay(p.createdAt)}` : "Added";
  return `<div class="pt">${esc(p.body || p.title)}</div><div class="pm">${esc(added)} · prayed <span id="pn">${p.prayedCount ?? 0}</span>×</div>`;
}

export function init(root) {
  const list = prayers();
  if (index >= list.length) index = 0;
  const ansFlood = root.querySelector("#ansFlood");
  const pc = root.querySelector("#pcard");

  root.querySelector("#prayed").addEventListener("click", () => pray(root));
  root.querySelector("#answer").addEventListener("click", () => answer(root));
  root.querySelector(".plist")?.addEventListener("click", (e) => {
    const b = e.target.closest("[data-pi]");
    if (!b || praying) return;
    index = +b.dataset.pi;
    resetCandle(root);
    document.dispatchEvent(new Event("app:refresh"));
  });

  // Swipe the prayer sideways to skip it.
  let x0 = null, dx = 0;
  pc.addEventListener("pointerdown", (e) => { if (praying) return; x0 = e.clientX; dx = 0; pc.setPointerCapture(e.pointerId); });
  pc.addEventListener("pointermove", (e) => {
    if (x0 === null) return;
    // The stage is scaled up with CSS zoom on a tall desktop window; keep the card under the pointer.
    dx = (e.clientX - x0) / (pc.currentCSSZoom ?? 1);
    pc.style.transform = `translateX(${dx}px) rotate(${dx / 40}deg)`;
  });
  const end = () => {
    if (x0 === null) return;
    x0 = null;
    if (Math.abs(dx) > 70) step(root, dx < 0 ? 1 : -1);
    else {
      const cur = pc.style.transform || "none";
      pc.style.transform = "";
      anim(pc, [{ transform: cur }, { transform: "none" }], { duration: 420, easing: "cubic-bezier(.3,1.5,.5,1)" });
    }
  };
  pc.addEventListener("pointerup", end);
  pc.addEventListener("pointercancel", end);
}

/** The count, the candle and the amen. The candle stays lit until the next prayer. */
async function pray(root) {
  const list = prayers();
  const p = list[index];
  if (!p || praying) return;
  praying = true;
  hold.on = true;
  lit = true;
  const b = root.querySelector("#prayed");
  const flame = root.querySelector("#flame"), glow = root.querySelector("#glow");
  b.innerHTML = `${I.flame}Prayed`;
  anim(b, [{ transform: "scale(.9)" }, { transform: "scale(1.06)" }, { transform: "none" }], { duration: 420, easing: "cubic-bezier(.3,1.6,.5,1)" });
  // The flame catches, overshoots, settles and flickers twice; the glow opens round it.
  anim(flame, [{ transform: "scale(0)" }, { transform: "scale(1.25, 1.3)", offset: 0.55 }, { transform: "scale(.94)", offset: 0.8 }, { transform: "scale(1)" }], { duration: 700, easing: "cubic-bezier(.3,1.3,.5,1)", fill: "forwards" });
  anim(glow, [{ opacity: 0, transform: "scale(.6)" }, { opacity: 1, transform: "scale(1)" }], { duration: 520, delay: 260, easing: "cubic-bezier(.3,1.5,.5,1)", fill: "forwards" });
  root.querySelector("#amen").classList.add("on");
  await wait(2100);
  // The count is saved once the moment has played, so the screen isn't redrawn under the candle.
  await patch("notes", p.id, { prayedCount: (p.prayedCount ?? 0) + 1 });
  index = (index + 1) % Math.max(1, prayers().length);
  resetCandle(root);
  praying = false;
  hold.on = false;
  document.dispatchEvent(new Event("app:refresh"));
}

function resetCandle(root) {
  root.querySelector("#amen")?.classList.remove("on");
  if (!lit) return;
  lit = false;
  const flame = root.querySelector("#flame");
  flame?.getAnimations().forEach((a) => a.cancel());
  root.querySelector("#glow")?.getAnimations().forEach((a) => a.cancel());
}

async function step(root, dir) {
  const list = prayers();
  if (!list.length) return;
  const pc = root.querySelector("#pcard");
  resetCandle(root);
  index = (index + dir + list.length) % list.length;
  pc.style.transform = "";
  pc.innerHTML = card(list[index]);
  anim(pc, [{ opacity: 0, transform: `translateX(${dir * 70}px)` }, { opacity: 1, transform: "none" }], { duration: 460, easing: "cubic-bezier(.2,.85,.25,1)" });
}

async function answer(root) {
  const list = prayers();
  const p = list[index];
  if (!p || praying) return;
  praying = true;
  hold.on = true;
  const f = root.querySelector("#ansFlood");
  const btn = root.querySelector("#answer").getBoundingClientRect();
  const phone = root.getBoundingClientRect();
  f.style.setProperty("--ox", `${btn.left + btn.width / 2 - phone.left}px`);
  f.style.setProperty("--oy", `${btn.top + btn.height / 2 - phone.top}px`);
  f.querySelector("[data-what]").textContent = p.body || p.title;
  f.classList.add("on");
  document.dispatchEvent(new Event("app:chrome"));
  await wait(2500);
  await patch("notes", p.id, { answeredAt: todayStr() });
  f.classList.remove("on");
  index = 0;
  praying = false;
  hold.on = false;
  document.dispatchEvent(new Event("app:refresh"));
  toast("Saved in Prayer & thanks");
}

function shortDay(iso) {
  return new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}

/** The tab bar turns gold while Answered is up, and tomato for the whole tab. */
export function bar() {
  return "flood";
}
