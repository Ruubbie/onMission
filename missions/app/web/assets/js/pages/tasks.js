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
    <img class="abs art pic in" src="assets/art/tasks.webp" alt="" style="left:252px;top:96px;width:128px">
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
