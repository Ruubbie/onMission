// Notes: prayer points, journal, meeting notes and ideas, as plain text. The pills filter them and a
// row opens to show its text. Port of prototype.html PAGES.notes. Notes are notes records (kind, body).

import { store } from "../store.js";
import { esc, slideIn, mkPills } from "../ui.js";

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
    <svg class="abs art" style="left:212px;top:124px" width="160" height="220" viewBox="0 0 160 220"><g class="ln">
      <path class="bgf" d="M20 20 L130 16 C 136 16, 140 20, 140 26 L142 196 C 142 202, 138 206, 132 206 L24 208 C 18 208, 14 204, 14 198 L12 28 C 12 23, 15 20, 20 20 Z"/>
      <path d="M12 46 L4 46 M12 76 L4 76 M12 106 L4 106 M12 136 L4 136 M12 166 L4 166"/>
      <path d="M36 62 L116 60 M36 90 L110 89 M36 118 L96 117"/>
      <path class="crf" d="M96 186 L146 116 L158 126 L108 196 L92 200 Z"/><path d="M146 116 L158 126"/>
    </g></svg>
    <div class="sheet" style="padding-top:16px">
      <div class="pills" id="kinds"></div>
      <div class="scroll" data-list>${list()}</div>
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
