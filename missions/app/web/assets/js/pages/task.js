// A task: its area as the poster line, its title big, and the day it's due. Pick when it's due, go to
// the checklist it belongs to, or mark it done. Port of prototype.html PAGES.task.

import { store } from "../store.js";
import { I, wait, anim } from "../motion.js";
import { esc, toast, pop, draw, mkPills } from "../ui.js";
import { addDays, todayStr } from "../util.js";
import { patch, setTaskDone, whenLabel } from "./common.js";

export const title = "Task";
export const parent = "tasks";
export const kick = "Task";

const WHEN = [["today", "Today"], ["tomorrow", "Tomorrow"], ["week", "Next week"], ["none", "No date"]];

function dayFor(key) {
  const today = todayStr();
  return { today, tomorrow: addDays(today, 1), week: addDays(today, 7), none: null }[key];
}

export function build(ctx) {
  const t = store.get("tasks", ctx.id);
  if (!t) return `<div class="abs hand hi in">Gone</div><div class="sheet"><div class="rw"><div class="tx"><div class="t1">This task is gone.</div></div></div></div>`;
  const big = t.title.length > 60 ? 34 : t.title.length > 30 ? 46 : t.title.length > 22 ? 58 : 68;
  return `
    <div class="abs hand hi in">${esc(areaLabel(t.area) || "Task")}</div>
    <div class="abs in" style="left:22px;right:22px;top:146px"><div class="disp" style="font-size:${big}px;line-height:.9">${esc(t.title)}</div><div class="cap" data-due style="margin:16px 0 0 2px">${esc(dueLine(t))}</div></div>
    <div class="sheet"><div class="scroll">
      <div class="sec">When</div><div class="pills tight" id="when" style="margin-top:10px"></div>
      ${t.checklistId ? `<div class="sec" style="margin-top:6px">Linked to</div><div class="rw tap" data-link><span class="dbox">${I.list}</span><div class="tx"><div class="t1">${esc(checklistTitle(t.checklistId))}</div><div class="t2">Checklist</div></div><span class="chev">${I.chev}</span></div>` : ""}
      <button class="btn f wide" data-done>${I.check.replace('pathLength="1" ', "")}Mark done</button>
    </div></div>`;
}

function dueLine(t) {
  if (!t.dueDate) return "No date";
  return `Due ${whenLabel(t.dueDate).toLowerCase()}`;
}

function checklistTitle(id) {
  return store.get("checklists", id)?.title ?? "Checklist";
}

function areaLabel(area) {
  return area ? area.charAt(0).toUpperCase() + area.slice(1) : "";
}

export function init(el, ctx) {
  const t = store.get("tasks", ctx.id);
  if (!t) return;
  const current = !t.dueDate ? "none" : t.dueDate <= todayStr() ? "today" : t.dueDate === addDays(todayStr(), 1) ? "tomorrow" : "week";
  mkPills(el.querySelector("#when"), WHEN, current, async (key) => {
    await patch("tasks", t.id, { dueDate: dayFor(key) });
    el.querySelector("[data-due]").textContent = { today: "Due today", tomorrow: "Due tomorrow", week: "Due next week", none: "No date" }[key];
    toast("Moved");
  });
  el.querySelector("[data-link]")?.addEventListener("click", () => { location.hash = `#/checklists`; });
  el.querySelector("[data-done]").addEventListener("click", async (e) => {
    const b = e.currentTarget;
    b.innerHTML = `<svg viewBox="0 0 24 24" class="ln" style="stroke-width:2.6;width:20px;height:20px"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>Done`;
    draw(b);
    pop(b);
    await wait(650);
    await setTaskDone(t, true);
    location.hash = "#/tasks";
  });
}
