// People: the monthly support on the poster beside what friends give (letters, coffee, flowers, a heart), then
// "Someone gives" right at hand and the people who need something from you, each with one action. Nobody is shown as
// further along than anyone else (see WAYS in common.js).

import { store } from "../store.js";
import { I, anim, playIcon, wait } from "../motion.js";
import { esc, fold, toast, isDesk } from "../ui.js";
import { todayStr } from "../util.js";
import { patch, waitingOnYou, waitingReason, initials, replyMailto, markAnswered, WAYS, hasWay } from "./common.js";
import { openCheckin } from "../checkin.js";
import { euroWhole, supportTotals } from "./money.js";
import { giveForm, bindGive } from "./give.js";

export const title = "People";

export function build() {
  const { total, target, pct } = supportTotals();
  const waiting = waitingOnYou(store.list("partners"));
  const count = store.list("partners").length + store.list("contacts").length;
  return `
    <div class="abs hand hi in">Monthly support</div>
    <div class="abs disp big in">${euroWhole(total)}</div>
    <div class="abs cap cp in">${target ? `of ${euroWhole(target)} a month · ${pct}%` : "Set a monthly target in Settings"}</div>
    <img class="abs art pic in" src="assets/art/people.webp" alt="" style="left:214px;top:236px;width:166px">
    <div class="sheet" data-count="${count}">${isDesk() ? deskHtml(waiting) : sheetHtml(waiting)}</div>`;
}

/** "Someone gives" and All people, first in the sheet so neither needs digging for. */
function quick() {
  return `<div class="quick"><button class="btn sm f" data-give-open>${I.heart}Someone gives</button>
    <button class="btn sm o" data-all>All ${store.list("partners").length} people</button></div>${giveForm()}`;
}

function sheetHtml(waiting) {
  if (!waiting.length) {
    return `${quick()}<div class="sec">Waiting on you</div><div class="rw"><div class="tx"><div class="t1">Nobody's waiting on you</div><div class="t2">Nice. Nothing needs you right now.</div></div></div>`;
  }
  // Everyone, not the first few: the sheet rises to the top bar when the list is longer than the screen.
  return `${quick()}<div class="sec">Waiting on you <b>${waiting.length}</b></div>
    ${waiting.map((p) => row(p)).join("")}`;
}

/** The desktop sheet: everyone waiting on you, beside how people are with you (not a ladder: any mix counts). */
function deskHtml(waiting) {
  const partners = store.list("partners");
  const ways = WAYS.map((w) => [w.label, partners.filter((p) => hasWay(p, w.id)).length]);
  const most = Math.max(1, ...ways.map(([, n]) => n));
  return `<div class="dash">
    <section class="card wide">${quick()}<div class="sec">Waiting on you <b>${waiting.length}</b></div>
      <div class="cols">${waiting.map(row).join("") || `<div class="rw"><div class="tx"><div class="t1">Nobody's waiting on you</div><div class="t2">Nice. Nothing needs you right now.</div></div></div>`}</div></section>
    <section class="card"><div class="sec">How people are with you</div>
      ${ways.map(([label, n]) => `<div class="bar-row"><span>${esc(label)}</span><div class="meter"><i style="width:${(n / most) * 100}%"></i></div><b>${n}</b></div>`).join("")}
    </section>
  </div>`;
}

const BUTTON = {
  reply: { label: "Reply", kind: "f" },
  thanks: { label: "Say thanks", kind: "f" },
  checkin: { label: "Check in", kind: "o" },
  plan: { label: "Plan", kind: "o" },
};

function row(p) {
  const why = waitingReason(p);
  const b = BUTTON[why.action];
  return `<div class="rw tap" data-person="${esc(p.id)}"><span class="av">${esc(initials(p.name))}</span>
    <div class="tx"><div class="t1">${esc(p.name)}</div><div class="t2${why.late ? " late" : ""} clamp">${esc(why.sub)}</div></div>
    <button class="btn sm ${b.kind}" data-action="${why.action}">${b.label}</button></div>`;
}

export function init(root, ctx) {
  bindGive(root, { done: () => ctx.refresh() });

  root.addEventListener("click", async (e) => {
    if (e.target.closest("[data-all]")) { location.hash = "#/allpeople"; return; }
    const btn = e.target.closest("[data-action]");
    const row = e.target.closest("[data-person]");
    if (!row) return;
    const p = store.get("partners", row.dataset.person);
    if (!p) return;
    if (!btn || btn.dataset.action === "plan") { location.hash = `#/partners/${p.id}`; return; }
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
      await patch("partners", p.id, { thankedAt: todayStr() });
      return;
    }
    if (btn.dataset.action === "checkin") openCheckin(p);
  });
}

/** The people who need you, for the tab badge. */
export function countWaiting() {
  return waitingOnYou(store.list("partners")).length;
}
