// Notes: prayer points, journal, meeting notes and ideas, as plain text. The pills filter them and a
// row opens to show its text. Port of prototype.html PAGES.notes. Notes are notes records (kind, body).

import { store } from "../store.js";
import { esc, slideIn, mkPills } from "../ui.js";
import { I } from "../motion.js";

export const title = "Notes";
export const parent = "move";
export const kick = "Notes";

const KINDS = [["all", "All"], ["journal", "Journal"], ["meeting", "Meetings"], ["idea", "Ideas"]];
let kind = "all";
let opened = null;

const notes = () => store.list("notes")
  .filter((n) => n.kind !== "prayer")
  .filter((n) => kind === "all" || n.kind === kind)
  .sort((a, b) => (b.createdAt ?? "").localeCompare(a.createdAt ?? ""));

export function build() {
  const all = store.list("notes").filter((n) => n.kind !== "prayer");
  const since = all.map((n) => n.createdAt).filter(Boolean).sort()[0];
  const month = since ? new Date(since).toLocaleDateString("en-GB", { month: "long" }) : "today";
  return `
    <div class="abs hand hi in">Notes &amp; journal</div>
    <div class="abs disp bign in">${all.length}</div>
    <div class="abs cap cp in">Written since<br>${esc(month)}</div>
    <img class="abs art pic in" src="assets/art/notes.webp" alt="" style="left:210px;top:120px;width:170px">
    <div class="sheet" style="padding-top:16px">
      <div class="pills" id="kinds"></div>
      <div class="scroll" data-list>${list()}</div>
      <a class="more" href="#/prayer">Prayers &amp; thanks are on the Prayer tab ${I.arrow}</a>
    </div>`;
}

function list() {
  const items = notes();
  return items.map((n) => `<div class="rw tap ${opened === n.id ? "open-note" : ""}" data-note="${esc(n.id)}">
      <div class="tx"><div class="t1">${esc(n.title || "Untitled")}</div><div class="t2">${esc(opened === n.id ? "" : (n.body ?? "").replace(/\s+/g, " ").slice(0, 70))}</div>
      ${opened === n.id ? `<div class="note-body">${esc(n.body ?? "")}</div>` : ""}</div>
      <span class="when">${esc(shortDay(n.createdAt))}</span></div>`).join("")
    || `<div class="rw"><div class="tx"><div class="t1">Nothing here yet</div><div class="t2">Add a note with + and "note: …".</div></div></div>`;
}

export function init(el) {
  mkPills(el.querySelector("#kinds"), KINDS.map(([id, label]) => [id, label, id === "all" ? store.list("notes").filter((n) => n.kind !== "prayer").length : null]), kind, (k, dir) => {
    kind = k;
    el.querySelector("[data-list]").innerHTML = list();
    slideIn(el.querySelector("[data-list]"), dir);
  });
  el.querySelector("[data-list]").addEventListener("click", (e) => {
    const r = e.target.closest("[data-note]");
    if (!r) return;
    opened = opened === r.dataset.note ? null : r.dataset.note;
    el.querySelector("[data-list]").innerHTML = list();
  });
}

function shortDay(iso) {
  if (!iso) return "";
  return new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}
