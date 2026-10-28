// Tasks: one list in three segments (Today, This week, Later). The ring ticks a task off; a row opens
// its page. Port of prototype.html #s-tasks.

import { store } from "../store.js";
import { I, anim } from "../motion.js";
import { esc, ring, fold, slideIn, placeBar, isDesk } from "../ui.js";
import { todayStr } from "../util.js";
import { bucketTasks, setTaskDone, whenLabel } from "./common.js";

export const title = "Tasks";

const SEGS = [["today", "Today"], ["week", "This week"], ["later", "Later"]];
let seg = "today";

export function build() {
  const buckets = bucketTasks(store.list("tasks"));
  const left = buckets.today.length + buckets.week.length + buckets.later.length;
  return `
    <div class="abs disp ttl in">Tasks</div>
    <div class="abs hand note in">${left} left, you got this</div>
    <svg class="abs art" style="left:268px;top:104px" width="112" height="150" viewBox="0 0 112 150">
      <g class="ln">
        <path class="bgf" d="M14 22 C 40 20, 72 20, 98 23 C 102 24, 104 27, 104 31 L103 138 C 103 142, 100 145, 96 145 L16 146 C 11 146, 8 143, 8 138 L9 30 C 9 25, 11 23, 14 22 Z"/>
        <path class="crf" d="M36 14 L76 14 L78 30 L34 30 Z"/>
        <path d="M24 56 L32 64 L46 48"/><path d="M56 58 L90 57"/>
        <path d="M24 88 L32 96 L46 80"/><path d="M56 90 L86 89"/>
        <circle cx="34" cy="120" r="8"/><path d="M56 121 L80 120"/>
      </g>
    </svg>
    <div class="sheet">${isDesk() ? board(buckets) : `
      <div class="seg" id="seg">${SEGS.map(([id, label]) => `<button data-seg="${id}" class="${id === seg ? "on" : ""}">${label}<i>${buckets[id].length}</i></button>`).join("")}<i class="bar"></i></div>
      <div class="tlist" id="tlist">${rows(buckets[seg])}</div>`}
    </div>`;
}

/** On a desktop the three segments sit side by side as a board. */
function board(buckets) {
  return `<div class="board">${SEGS.map(([id, label]) => `<section class="card">
    <div class="sec">${label} <b>${buckets[id].length}</b></div>
    <div class="tlist">${rows(buckets[id])}</div></section>`).join("")}</div>`;
}

function rows(list) {
  const today = todayStr();
  return list.map((t) => `
    <div class="rw tap" data-task="${esc(t.id)}">${ring(false, "Done")}
      <div class="tx"><div class="t1">${esc(t.title)}</div><div class="t2">${esc(areaLabel(t.area))}</div></div>
      <span class="when ${t.dueDate && t.dueDate < today ? "late" : ""}">${esc(whenLabel(t.dueDate, today))}</span>
    </div>`).join("") || `<div class="rw"><div class="tx"><div class="t1">Nothing here</div><div class="t2">Add a task with + and a date, like "call bank fri".</div></div></div>`;
}

export function init(root) {
  const segBar = root.querySelector("#seg");
  placeBar(segBar?.querySelector(".bar"), segBar?.querySelector(".on"));
  segBar?.addEventListener("click", (e) => {
    const b = e.target.closest("[data-seg]");
    if (!b || b.dataset.seg === seg) return;
    const dir = SEGS.findIndex((s) => s[0] === b.dataset.seg) > SEGS.findIndex((s) => s[0] === seg) ? 1 : -1;
    seg = b.dataset.seg;
    const buckets = bucketTasks(store.list("tasks"));
    segBar.querySelectorAll("[data-seg]").forEach((x) => x.classList.toggle("on", x === b));
    placeBar(segBar.querySelector(".bar"), b);
    root.querySelector("#tlist").innerHTML = rows(buckets[seg]);
    slideIn(root.querySelector("#tlist"), dir);
  });

  root.querySelector(".sheet").addEventListener("click", async (e) => {
    const row = e.target.closest("[data-task]");
    if (!row) return;
    const task = store.get("tasks", row.dataset.task);
    if (!task) return;
    if (e.target.closest("[data-ring]")) {
      row.querySelector("[data-ring]").classList.add("ticked");
      row.classList.add("struck");
      await new Promise((r) => setTimeout(r, 560));
      await fold(row);
      await setTaskDone(task, true);
      return;
    }
    location.hash = `#/task/${task.id}`;
  });
}

export function countOverdue() {
  const today = todayStr();
  return store.list("tasks").filter((t) => t.status !== "done" && t.status !== "skipped" && t.dueDate && t.dueDate < today).length;
}

function areaLabel(area) {
  if (!area) return "";
  return area.charAt(0).toUpperCase() + area.slice(1);
}
