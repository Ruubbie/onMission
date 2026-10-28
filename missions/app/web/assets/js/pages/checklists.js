// Checklists: the lists for the move in four phases (Now, Before, Leaving, Arrival). Each list is a row
// with a progress ring; open one to tick its items. A full list turns solid and says so. Port of
// prototype.html PAGES.checklists. A list's phase is the free text on the list; it is grouped by words in it.

import { store } from "../store.js";
import { I, anim, tween, ease } from "../motion.js";
import { esc, toast, slideIn, placeBar, pop } from "../ui.js";
import { patch } from "./common.js";

export const title = "Checklists";
export const parent = "move";
export const kick = "Checklists";

const PHASES = [["now", "Now"], ["before", "Before"], ["week", "Leaving"], ["arrival", "Arrival"]];
let phase = "now";
let openId = null;

function phaseOf(c) {
  const t = (c.phase ?? "").toLowerCase();
  if (/arriv|queenstown|after|first/.test(t)) return "arrival";
  if (/leav|depart|week|last/.test(t)) return "week";
  if (/before|soon|pre/.test(t)) return "before";
  return "now";
}

function lists() {
  return store.list("checklists").filter((c) => !c.archived).sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
}

function itemsOf(c) {
  return store.list("tasks").filter((t) => t.checklistId === c.id).sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
}

function leftIn(c) {
  return itemsOf(c).filter((t) => t.status !== "done" && t.status !== "skipped").length;
}

function totalLeft() {
  return lists().reduce((s, c) => s + leftIn(c), 0);
}

export function build() {
  const all = lists();
  const count = (p) => all.filter((c) => phaseOf(c) === p).reduce((s, c) => s + leftIn(c), 0);
  const shown = all.filter((c) => phaseOf(c) === phase);
  return `
    <div class="abs hand hi in">Before you fly</div>
    <div class="abs disp bign in" data-n>${totalLeft()}</div>
    <div class="abs cap cp in">Things left<br>on ${all.length} lists</div>
    <svg class="abs art" style="left:200px;top:120px" width="176" height="230" viewBox="0 0 176 230"><g class="ln">
      <path class="dots" stroke-dasharray="1 7" d="M30 196 C 40 172, 62 170, 74 160 M74 160 C 86 134, 106 130, 116 118 M116 118 C 128 96, 144 90, 150 78"/>
      <path class="bgf" d="M8 206 C 8 196, 52 196, 52 206 C 52 214, 8 214, 8 206 Z"/>
      <path class="bgf" d="M54 166 C 54 156, 96 156, 96 166 C 96 174, 54 174, 54 166 Z"/>
      <path class="bgf" d="M96 124 C 96 114, 138 114, 138 124 C 138 132, 96 132, 96 124 Z"/>
      <path class="bgf" d="M130 82 C 130 72, 170 72, 170 82 C 170 90, 130 90, 130 82 Z"/>
      <path d="M150 78 L150 22"/><path class="crf" d="M150 22 L172 30 L150 38"/>
      <circle class="crf" cx="30" cy="196" r="7"/>
    </g></svg>
    <div class="sheet" style="padding-top:10px">
      <div class="seg four" id="seg">${PHASES.map(([id, label]) => `<button data-phase="${id}" class="${id === phase ? "on" : ""}">${label}<i>${count(id)}</i></button>`).join("")}<i class="bar"></i></div>
      <div class="scroll" data-list>${shown.map(listRow).join("") || `<div class="rw"><div class="tx"><div class="t1">Nothing in this phase</div><div class="t2">Lists get their phase from the word on them, like "before leaving".</div></div></div>`}</div>
    </div>`;
}

function ringSvg(done, total) {
  const f = total ? done / total : 0;
  return `<svg class="pr ${total && done === total ? "full" : ""}" viewBox="0 0 36 36"><circle cx="18" cy="18" r="15" class="prbg"/><circle cx="18" cy="18" r="15" class="prarc" pathLength="1" stroke-dasharray="${f} 1"/><path class="prck" pathLength="1" d="M11 18.5l4.5 4.5L25 13.5"/></svg>`;
}

function listRow(c) {
  const items = itemsOf(c);
  const done = items.filter((t) => t.status === "done" || t.status === "skipped").length;
  const open = openId === c.id;
  return `<div class="cl ${open ? "open" : ""}" data-list-id="${esc(c.id)}">
    <button class="clhead">${ringSvg(done, items.length)}<div class="tx"><div class="t1">${esc(c.title)}</div><div class="t2">${items.length && done === items.length ? "All done" : `${done} of ${items.length} done`}</div></div><span class="chev">${I.chev}</span></button>
    <div class="clitems">${items.map((t) => `<div class="it ${t.status === "done" ? "struck" : ""}" data-item="${esc(t.id)}"><span class="ring sm ${t.status === "done" ? "ticked" : ""}">${I.check}</span><span>${esc(t.title)}</span></div>`).join("") || `<div class="it"><span>No items yet.</span></div>`}</div>
  </div>`;
}

export function init(root) {
  const seg = root.querySelector("#seg");
  placeBar(seg.querySelector(".bar"), seg.querySelector(".on"));
  seg.addEventListener("click", (e) => {
    const b = e.target.closest("[data-phase]");
    if (!b || b.dataset.phase === phase) return;
    const ids = PHASES.map((p) => p[0]);
    const dir = ids.indexOf(b.dataset.phase) > ids.indexOf(phase) ? 1 : -1;
    phase = b.dataset.phase;
    openId = null;
    document.dispatchEvent(new Event("app:refresh"));
    queueMicrotask(() => {
      const list = document.querySelector(".pg [data-list]");
      if (list) slideIn(list, dir);
    });
  });

  const list = root.querySelector("[data-list]");
  list.addEventListener("click", (e) => {
    const head = e.target.closest(".clhead");
    if (head) {
      const box = head.parentNode;
      openId = openId === box.dataset.listId ? null : box.dataset.listId;
      list.querySelectorAll(".cl").forEach((x) => x.classList.toggle("open", x.dataset.listId === openId));
      return;
    }
    const it = e.target.closest("[data-item]");
    if (!it) return;
    tickItem(it.dataset.item, root);
  });
}

async function tickItem(id, root) {
  const task = store.get("tasks", id);
  if (!task) return;
  const c = store.get("checklists", task.checklistId);
  const done = task.status !== "done";
  const box = root.querySelector(`[data-list-id="${task.checklistId}"]`);
  const row = root.querySelector(`[data-item="${id}"]`);
  row?.classList.toggle("struck", done);
  row?.querySelector(".ring")?.classList.toggle("ticked", done);
  const after = itemsOf(c).filter((t) => t.id !== id && t.status !== "done").length + (done ? 0 : 1);
  const total = itemsOf(c).length;
  const doneNow = total - after;
  const arc = box?.querySelector(".prarc");
  if (arc) {
    const f0 = parseFloat(arc.getAttribute("stroke-dasharray")) || 0;
    tween(520, (t) => arc.setAttribute("stroke-dasharray", `${f0 + (doneNow / total - f0) * ease(t)} 1`));
  }
  const full = doneNow === total;
  const pr = box?.querySelector(".pr");
  if (pr) {
    pr.classList.toggle("full", full);
    if (full) pop(pr);
  }
  await patch("tasks", id, { status: done ? "done" : "todo", completedAt: done ? new Date().toISOString() : null });
  if (full && done) toast(`${c.title} · all done`);
}

export function countLeft() {
  return totalLeft();
}
