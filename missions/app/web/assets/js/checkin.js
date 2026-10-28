// After a call: a cover that slides up, a three-stop slider (Not now, Thinking, Yes!) and the sky that
// goes from night through sunrise to full sun. Saving moves the partner to the matching stage.

import { store } from "./store.js";
import { I, tween, anim, ease } from "./motion.js";
import { esc, toast } from "./ui.js";
import { patch } from "./pages/common.js";
import { todayStr } from "./util.js";

const STAGES = [
  { w: "Not now", stage: "paused", next: "That's okay. I'll suggest a catch-up in spring.", c: "#A9CCE0", ink: "#1E1A17", model: "Not now" },
  { w: "Thinking", stage: "thinking", next: "I'll remind you to follow up in 2 weeks.", c: "#D9A13B", ink: "#1E1A17", model: "Thinking about it" },
  { w: "Yes!", stage: "committed", next: "Committed! Next up: a thank-you and the amount.", c: "#E5774A", ink: "#1E1A17", model: "Committed" },
];

let t = 0.5;
let idx = 1;
let who = null;
let dragging = false;

export function initCheckin() {
  const el = document.getElementById("chk");
  const rays = Array.from({ length: 12 }, (_, i) => `<path data-a="${i * 30}"/>`).join("");
  el.innerHTML = `
    <div class="top"><span class="kicker">After the call</span><button class="round xbtn" id="ckClose" aria-label="Close">${I.x}</button></div>
    <div class="hand q" id="ckQ"></div>
    <svg class="sun" viewBox="0 0 300 230">
      <defs><clipPath id="sky"><rect x="0" y="0" width="300" height="190"/></clipPath></defs>
      <g class="ln" style="stroke-width:2.6">
        <g id="night">
          <path class="ckbg" d="M236 34 A 22 22 0 1 0 258 66 A 17 17 0 1 1 236 34 Z"/>
          <path d="M62 44 v12 M56 50 h12"/><path d="M104 22 v9 M99.5 26.5 h9"/><path d="M196 92 v9 M191.5 96.5 h9"/>
        </g>
        <g clip-path="url(#sky)">
          <g id="rays">${rays}</g>
          <circle id="sunc" class="ckbg" cx="150" cy="200" r="38"/>
        </g>
        <path class="ckbg" d="M-4 186 C 40 150, 84 140, 128 160 C 166 134, 222 128, 304 168 L304 234 L-4 234 Z"/>
        <path d="M60 230 C 90 206, 120 196, 150 194 C 184 192, 214 200, 248 230"/>
        <path d="M108 172 L112 168 L118 172 L124 167 L130 172"/>
      </g>
    </svg>
    <div class="word disp" id="ckWord"><span>Thinking</span></div>
    <div class="whatnext" id="ckNext"></div>
    <div class="slider" id="slider">
      <i class="track"></i><i class="tick" style="left:0"></i><i class="tick" style="left:50%"></i><i class="tick" style="left:100%"></i>
      <span class="knob" id="knob">${I.sun}</span>
    </div>
    <div class="slabels" id="slabels"><span>Not now</span><span>Thinking</span><span>Yes!</span></div>
    <div class="ckacts"><button class="o" id="ckNote">Add note</button><button class="f" id="ckSave">Save${I.arrow}</button></div>`;

  document.getElementById("ckClose").addEventListener("click", closeCheckin);
  document.getElementById("ckSave").addEventListener("click", save);
  document.getElementById("ckNote").addEventListener("click", () => {
    const id = who?.id;
    closeCheckin();
    if (id) location.hash = `#/partners/${id}`;
  });
  document.getElementById("slabels").addEventListener("click", (e) => {
    const s = e.target.closest("span");
    if (s) snapTo([...s.parentNode.children].indexOf(s) / 2);
  });

  const slider = document.getElementById("slider");
  const fromX = (x) => {
    const r = slider.getBoundingClientRect();
    return Math.max(0, Math.min(1, (x - r.left) / r.width));
  };
  slider.addEventListener("pointerdown", (e) => { dragging = true; slider.setPointerCapture(e.pointerId); slider.classList.add("drag"); renderCk(fromX(e.clientX)); });
  slider.addEventListener("pointermove", (e) => { if (dragging) renderCk(fromX(e.clientX)); });
  const drop = () => {
    if (!dragging) return;
    dragging = false;
    slider.classList.remove("drag");
    snapTo(Math.round(t * 2) / 2);
  };
  slider.addEventListener("pointerup", drop);
  slider.addEventListener("pointercancel", drop);
  slider.addEventListener("keydown", (e) => {
    if (e.key === "ArrowRight") snapTo(Math.min(1, Math.round(t * 2) / 2 + 0.5));
    if (e.key === "ArrowLeft") snapTo(Math.max(0, Math.round(t * 2) / 2 - 0.5));
  });
  slider.tabIndex = 0;
  slider.setAttribute("role", "slider");
  slider.setAttribute("aria-label", "How did it go?");
}

const mix = (a, b, k) => {
  const A = [1, 3, 5].map((i) => parseInt(a.slice(i, i + 2), 16));
  const B = [1, 3, 5].map((i) => parseInt(b.slice(i, i + 2), 16));
  return `rgb(${A.map((v, i) => Math.round(v + (B[i] - v) * k)).join(",")})`;
};
const colorAt = (x) => (x <= 0.5 ? mix(STAGES[0].c, STAGES[1].c, x * 2) : mix(STAGES[1].c, STAGES[2].c, (x - 0.5) * 2));

/** Paints the whole check-in for a position on the slider (0 = Not now, 0.5 = Thinking, 1 = Yes!). */
function renderCk(x) {
  t = x;
  const el = document.getElementById("chk");
  el.style.setProperty("--ck", colorAt(x));
  const next = Math.round(x * 2);
  const ink = STAGES[x < 0.27 ? 0 : x < 0.74 ? 1 : 2].ink;
  el.style.setProperty("--ckink", ink);
  el.classList.toggle("light", ink !== "#1E1A17");
  const cy = 206 - x * 124;
  document.getElementById("sunc").setAttribute("cy", cy);
  const len = 6 + x * 18, op = Math.max(0, Math.min(1, (x - 0.3) / 0.45));
  const rays = document.getElementById("rays");
  rays.querySelectorAll("path").forEach((p) => {
    const a = (+p.dataset.a * Math.PI) / 180, r0 = 48;
    p.setAttribute("d", `M${150 + Math.cos(a) * r0} ${cy + Math.sin(a) * r0} L${150 + Math.cos(a) * (r0 + len)} ${cy + Math.sin(a) * (r0 + len)}`);
  });
  rays.style.opacity = op;
  document.getElementById("night").style.opacity = Math.max(0, 1 - x * 2.4);
  document.getElementById("knob").style.left = `${x * 100}%`;
  if (next !== idx) setWord(next);
}

function setWord(next) {
  const up = next > idx;
  idx = next;
  const box = document.getElementById("ckWord");
  const old = box.querySelector("span");
  const fresh = document.createElement("span");
  fresh.textContent = STAGES[next].w;
  box.appendChild(fresh);
  anim(old, [{ transform: "none", opacity: 1 }, { transform: `translateY(${up ? -70 : 70}%)`, opacity: 0 }], { duration: 280, easing: "cubic-bezier(.5,0,.75,0)", fill: "forwards" }).then(() => old.remove());
  anim(fresh, [{ transform: `translateY(${up ? 70 : -70}%)`, opacity: 0 }, { transform: "none", opacity: 1 }], { duration: 420, easing: "cubic-bezier(.2,1.3,.4,1)" });
  document.getElementById("ckNext").textContent = STAGES[next].next;
  document.querySelectorAll("#slabels span").forEach((s, i) => s.classList.toggle("on", i === next));
}

function snapTo(target) {
  const from = t;
  return tween(420, (k) => {
    const e = k < 1 ? 1 - Math.pow(1 - k, 3) * Math.cos(k * 4) : 1;
    renderCk(from + (target - from) * Math.min(1.04, e));
  }).then(() => renderCk(target));
}

/** Opens the check-in for a partner. */
export function openCheckin(partner) {
  who = partner;
  document.getElementById("ckQ").textContent = `how did it go with ${partner.name.split(" ")[0]}?`;
  const el = document.getElementById("chk");
  el.classList.add("open");
  t = 0.5;
  idx = 1;
  renderCk(0.5);
  document.getElementById("ckWord").innerHTML = "<span>Thinking</span>";
  document.getElementById("ckNext").textContent = STAGES[1].next;
  document.querySelectorAll("#slabels span").forEach((s, i) => s.classList.toggle("on", i === 1));
  document.dispatchEvent(new Event("app:refresh"));
  // A small nudge, so you see the slider moves.
  setTimeout(() => snapTo(0.62).then(() => snapTo(0.5)), 650);
}

export function closeCheckin() {
  document.getElementById("chk")?.classList.remove("open");
  document.dispatchEvent(new Event("app:refresh"));
}

export function isCheckinOpen() {
  return !!document.getElementById("chk")?.classList.contains("open");
}

async function save() {
  if (!who) return closeCheckin();
  const s = STAGES[Math.round(t * 2)];
  const name = who.name;
  const id = who.id;
  closeCheckin();
  await patch("partners", id, { stage: s.stage, lastContactAt: todayStr() });
  toast(`${name} · ${s.model}`);
  document.dispatchEvent(new Event("app:refresh"));
}

