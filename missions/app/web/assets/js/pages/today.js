// Today: the days to departure on tomato, then the next task as one hero card and the rest as rows.
// When the day is clear the sheet drops, the poster lifts and the tab bar turns tomato. Port of
// prototype.html #s-today.

import { store } from "../store.js";
import { I, tween, ease, anim, draw } from "../motion.js";
import { esc, ring, fold, toast, plural, isDesk } from "../ui.js";
import { addDays, dayDiff, todayStr } from "../util.js";
import { bucketTasks, setTaskDone, patch, whenLabel, waitingOnYou, waitingReason, initials } from "./common.js";
import { AREAS } from "../util.js";
import { euroWhole, supportTotals } from "./money.js";
import { readiness } from "./move.js";

export const title = "Today";

const RM = matchMedia("(prefers-reduced-motion: reduce)").matches;

export function build(ctx) {
  const today = todayStr();
  const s = store.settings();
  const days = s.departureDate ? dayDiff(s.departureDate, today) : null;
  const list = bucketTasks(store.list("tasks"), today).today;
  return `
    <div class="poster">
      <div class="abs hand hi in">${greeting()}</div>
      <div class="abs disp big in" data-count>${days == null ? "—" : Math.max(0, days)}</div>
      <div class="abs cap cp in">${days == null ? "Set your departure<br>date in Settings" : `Days till ${destination(s)}`}</div>
      <img class="abs art pic in" src="assets/art/traveller-walk.webp" alt="" style="left:254px;top:122px;height:214px">
    </div>
    <div class="done-art">
      <div class="abs disp bigd">All<br>done.</div>
      <div class="abs hand note">Go enjoy the evening</div>
      <img class="abs art pic" src="assets/art/traveller-read.webp" alt="" style="left:112px;top:420px;height:236px">
    </div>
    <div class="sheet">${isDesk() ? deskHtml(list, today) : sheetHtml(list, today)}</div>`;
}

/**
 * The desktop dashboard: today's tasks (or the all-done note) beside the week ahead, the people
 * waiting on you, and how support and the move are going.
 */
/** Under a name waiting on you: why (their message from hesent.me, a thank-you owed, a follow-up, a coffee). */
function waitingSub(p) {
  const why = waitingReason(p);
  return `<div class="t2${why.late ? " late" : ""} clamp">${esc(why.sub)}</div>`;
}

function deskHtml(list, today) {
  const week = bucketTasks(store.list("tasks"), today).week;
  const waiting = waitingOnYou(store.list("partners"));
  const { total, target, pct } = supportTotals();
  const ready = readiness();
  const main = list.length ? sheetHtml(list, today, 8) : `
    <div class="sec">Today</div>
    <div class="donecard"><div class="disp">All done.</div><div class="hand">Go enjoy the evening</div>
      <p>Nothing left for today. Tomorrow's tasks are under This week.</p></div>`;
  return `<div class="dash">
    <section class="card wide">${main}</section>
    <section class="card">
      <div class="sec">This week <b>${week.length}</b></div>
      ${week.slice(0, 6).map((t) => `<div class="rw tap" data-row="${esc(t.id)}" data-open>${ring(false)}<div class="tx"><div class="t1">${esc(t.title)}</div><div class="t2">${esc(areaName(t.area) || "Task")}</div></div><span class="when">${esc(whenLabel(t.dueDate, today))}</span></div>`).join("")
        || `<div class="rw"><div class="tx"><div class="t1">A quiet week</div><div class="t2">Nothing else is due in the next seven days.</div></div></div>`}
      <a class="more" href="#/tasks">All tasks ${I.arrow}</a>
    </section>
    <section class="card">
      <div class="sec">Waiting on you <b>${waiting.length}</b></div>
      ${waiting.slice(0, 5).map((p) => `<a class="rw tap" href="#/partners/${encodeURIComponent(p.id)}"><span class="av">${esc(initials(p.name))}</span><div class="tx"><div class="t1">${esc(p.name)}</div>${waitingSub(p)}</div></a>`).join("")
        || `<div class="rw"><div class="tx"><div class="t1">Nobody's waiting on you</div><div class="t2">Everyone has heard from you.</div></div></div>`}
      <a class="more" href="#/people">People ${I.arrow}</a>
    </section>
    <section class="card">
      <div class="sec">Monthly support</div>
      <div class="stat">${euroWhole(total)}</div>
      <div class="meter"><i style="width:${Math.min(100, pct)}%"></i></div>
      <div class="t2">${target ? `of ${euroWhole(target)} a month · ${pct}%` : "Set a monthly target in Settings"}</div>
      <div class="sec" style="margin-top:26px">Ready to go</div>
      <div class="stat">${ready}%</div>
      <div class="meter"><i style="width:${ready}%"></i></div>
      <div class="t2">Checklists, papers and packing together</div>
      <a class="more" href="#/move">Move ${I.arrow}</a>
    </section>
  </div>`;
}

/** Today's hero and rows. max limits the rows on a desktop, where the rest are a click away under Tasks. */
function sheetHtml(list, today, max = Infinity) {
  if (!list.length) return "";
  const [hero, ...rest] = list;
  const late = hero.dueDate && hero.dueDate < today;
  return `
    <div class="sec">Next up <b>${plural(list.length, "1 today", `${list.length} today`)}</b></div>
    <div class="hero" data-hero="${esc(hero.id)}">
      <div class="ht">${esc(hero.title)}</div>
      <div class="t2 ${late ? "late" : ""}">${late ? `Was due ${whenLabel(hero.dueDate, today).replace(" late", "")}` : esc(areaName(hero.area) || "Due today")}</div>
      <div class="acts"><button class="btn f" data-act="done">${I.check.replace('pathLength="1" ', "")}Done</button><button class="btn o" data-act="later">Tomorrow</button></div>
    </div>
    ${rest.length ? `<div class="sec">Later today <b>${rest.length}</b></div>` : ""}
    ${rest.slice(0, max).map((t, i) => `<div class="rw tap" data-row="${esc(t.id)}" data-i="${i + 1}"${max < Infinity ? " data-open" : ""}>${ring(false)}<div class="tx"><div class="t1">${esc(t.title)}</div><div class="t2">${esc(areaName(t.area) || "Today")}</div></div></div>`).join("")}
    ${rest.length > max ? `<a class="more" href="#/tasks">${rest.length - max} more for today ${I.arrow}</a>` : ""}`;
}

export function init(root, ctx) {
  const today = todayStr();
  const clear = bucketTasks(store.list("tasks"), today).today.length === 0;
  root.classList.toggle("alldone", clear);
  if (!ctx.quiet) {
    root.querySelectorAll(".sheet").forEach(() => {});
  }
  if (!ctx.quiet) countUp(root);

  root.addEventListener("click", async (e) => {
    const act = e.target.closest("[data-act]");
    const row = e.target.closest("[data-row]");
    const hero = root.querySelector("[data-hero]");
    if (act && hero) {
      const id = hero.dataset.hero;
      const task = store.get("tasks", id);
      if (!task) return;
      if (act.dataset.act === "done") {
        act.innerHTML = `${I.check.replace('pathLength="1" ', "")}Done`;
        await anim(hero, [{ opacity: 1, transform: "none" }, { opacity: 0, transform: "translateX(40px)" }], { duration: 300, easing: "cubic-bezier(.5,0,.75,0)", fill: "forwards" });
        await setTaskDone(task, true);
        return;
      }
      if (act.dataset.act === "later") {
        await patch("tasks", id, { dueDate: addDays(today, 1) });
        toast("Moved to tomorrow");
      }
      return;
    }
    // Desktop rows open their task; on the phone a row only ticks with its ring.
    if (row && row.hasAttribute("data-open") && !e.target.closest("[data-ring]")) {
      location.hash = `#/task/${row.dataset.row}`;
      return;
    }
    if (e.target.closest("[data-ring]") && row) {
      const task = store.get("tasks", row.dataset.row);
      if (!task) return;
      row.querySelector("[data-ring]").classList.add("ticked");
      row.classList.add("struck");
      await new Promise((r) => setTimeout(r, RM ? 0 : 560));
      await fold(row);
      await setTaskDone(task, true);
    }
  });
}

/** Today's bar is tomato once the day is clear (the tab bar takes the page colour). */
export function bar() {
  return bucketTasks(store.list("tasks")).today.length === 0 ? "flood" : "cream";
}

function countUp(root) {
  const el = root.querySelector("[data-count]");
  const n = +el.textContent;
  if (!Number.isFinite(n) || RM) return;
  tween(1000, (k) => { el.textContent = Math.round(ease(k) * n); });
  draw(root, 200);
}

function greeting() {
  const hour = new Date().getHours();
  if (hour < 12) return "Morning!";
  if (hour < 18) return "Afternoon!";
  return "Evening!";
}

function destination(s) {
  return s.destination || "Queenstown";
}

function areaName(area) {
  if (!area) return "";
  return area.charAt(0).toUpperCase() + area.slice(1);
}

