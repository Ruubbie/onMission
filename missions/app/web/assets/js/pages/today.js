// Today: the days to departure on tomato, then the next task as one hero card and the rest as rows.
// When the day is clear the sheet drops, the poster lifts and the tab bar turns tomato. Port of
// prototype.html #s-today.

import { store } from "../store.js";
import { I, tween, ease, anim, draw } from "../motion.js";
import { esc, ring, fold, toast, plural, isDesk } from "../ui.js";
import { addDays, dayDiff, todayStr } from "../util.js";
import { bucketTasks, setTaskDone, patch, whenLabel, waitingOnYou, initials, STAGE_LABEL, latestMessage, messageDay } from "./common.js";
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
      <svg class="abs art" style="left:208px;top:140px" width="170" height="182" viewBox="0 0 170 182">
        <g class="ln">
          <path class="dots" stroke-dasharray="1 7" d="M8 84 C 2 52, 40 38, 52 58 C 62 74, 36 84, 40 64 C 44 40, 90 28, 118 34"/>
          <path class="bgf" d="M120 34 L162 14 L148 46 L142 34 Z"/><path d="M142 34 L162 14"/>
          <path d="M2 178 L44 120 L62 140 L96 86 L150 178"/>
          <path d="M33 135 L38 131 L42 136 L47 129 L52 134"/>
          <path d="M84 104 L89 99 L96 105 L102 98 L108 104"/>
          <path d="M96 86 L96 62"/><path class="crf" d="M96 62 L114 68 L96 75"/>
          <path d="M2 178 L164 178"/>
        </g>
      </svg>
    </div>
    <div class="done-art">
      <div class="abs disp bigd">All<br>done.</div>
      <div class="abs hand note">Go enjoy the evening</div>
      <svg class="abs art" style="left:80px;top:430px" width="230" height="210" viewBox="0 0 230 210">
        <g class="ln">
          <circle cx="170" cy="40" r="20"/>
          <path d="M170 8v-6M196 18l5-4M144 18l-5-4M202 40h7M131 40h-7"/>
          <path d="M40 200 L40 96"/><path class="bgf" d="M40 64 C 18 70, 14 96, 24 110 C 30 120, 50 120, 56 110 C 66 96, 62 70, 40 64 Z"/>
          <path d="M196 200 L196 112"/><path class="bgf" d="M196 84 C 178 88, 172 110, 180 122 C 186 132, 206 132, 212 122 C 220 110, 214 88, 196 84 Z"/>
          <path d="M40 132 C 80 176, 156 178, 196 140"/>
          <path d="M40 132 C 84 162, 152 164, 196 140"/>
          <path d="M92 150 L108 140 L122 156"/>
          <path d="M8 200 C 80 196, 160 203, 226 199"/>
        </g>
      </svg>
    </div>
    <div class="sheet">${isDesk() ? deskHtml(list, today) : sheetHtml(list, today)}</div>`;
}

/**
 * The desktop dashboard: today's tasks (or the all-done note) beside the week ahead, the people
 * waiting on you, and how support and the move are going.
 */
/** Under a name waiting on you: their message from hesent.me, or their stage. */
function waitingSub(p) {
  const m = p.replyWaiting === true ? latestMessage(p) : null;
  if (p.replyWaiting === true) {
    return `<div class="t2 late clamp">${esc(m ? `Wrote ${messageDay(m)}: “${m.text.replace(/\n/g, " ")}”` : "Wrote to you on hesent.me")}</div>`;
  }
  return `<div class="t2">${esc(STAGE_LABEL[p.stage] ?? p.stage)}</div>`;
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

