// All people: every partner and contact, filtered by category and searched by name. Port of
// prototype.html PAGES.allpeople.

import { store } from "../store.js";
import { esc, toast, slideIn, placeBar } from "../ui.js";
import { I } from "../motion.js";
import { PARTNER_CATEGORIES, euro } from "../util.js";
import { initials, STAGE_LABEL } from "./common.js";
import { supportTotals, euroWhole } from "./money.js";

export const title = "People";
export const parent = "people";
export const kick = "People";

let cat = "all";
let find = "";

export function build() {
  const partners = store.list("partners");
  const monthly = partners.filter((p) => p.monthlyCents).length;
  const { total } = supportTotals();
  const cats = ["all", ...PARTNER_CATEGORIES.filter(Boolean)];
  return `
    <div class="abs hand hi in">Your people</div>
    <div class="abs disp bign in">${partners.length + store.list("contacts").length}</div>
    <div class="abs cap cp in">${monthly} give monthly<br>${euroWhole(total)} together</div>
    <svg class="abs art" style="left:206px;top:146px" width="180" height="200" viewBox="0 0 180 200"><g class="ln">
      <circle cx="58" cy="66" r="24"/><path d="M14 180 C 16 132, 34 108, 58 108 S 100 132, 102 180"/>
      <circle class="bgf" cx="126" cy="80" r="22"/><path class="bgf" d="M82 186 C 84 142, 102 120, 126 120 S 168 142, 170 186"/>
      <path d="M4 190 L176 190"/>
    </g></svg>
    <div class="sheet" style="padding-top:16px">
      <div class="pills" id="cats">${cats.map((c) => `<button class="pl ${c === cat ? "on" : ""}" data-cat="${c}">${c === "all" ? "All" : c}<i>${c === "all" ? partners.length : partners.filter((p) => p.category === c).length}</i></button>`).join("")}<i class="pp"></i></div>
      <label class="search">${I.search}<input placeholder="Search people" aria-label="Search people" value="${esc(find)}"></label>
      <div class="scroll" id="plist">${rows()}</div>
    </div>`;
}

function rows() {
  const q = find.trim().toLowerCase();
  const partners = store.list("partners")
    .filter((p) => (cat === "all" || p.category === cat) && (!q || p.name.toLowerCase().includes(q)))
    .sort((a, b) => a.name.localeCompare(b.name));
  const contacts = cat === "all" && !q ? [] : store.list("contacts").filter((c) => !q || (c.name ?? "").toLowerCase().includes(q));
  const html = partners.map((p) => `<div class="rw tap" data-partner="${esc(p.id)}"><span class="av">${esc(initials(p.name))}</span><div class="tx"><div class="t1">${esc(p.name)}</div><div class="t2">${esc(STAGE_LABEL[p.stage] ?? p.stage)}</div></div><span class="when">${esc(p.category ?? "")}</span></div>`).join("")
    + contacts.map((c) => `<div class="rw"><span class="av">${esc(initials(c.name))}</span><div class="tx"><div class="t1">${esc(c.name)}</div><div class="t2">${esc(c.organisation ?? c.role ?? "Contact")}</div></div></div>`).join("");
  return html || `<div class="rw"><div class="tx"><div class="t1">Nobody by that name</div><div class="t2">Add them with the + at the top.</div></div></div>`;
}

export function init(el) {
  const pills = el.querySelector("#cats");
  const bar = pills.querySelector(".pp");
  placeBar(bar, pills.querySelector(".on"));
  pills.addEventListener("click", (e) => {
    const b = e.target.closest("[data-cat]");
    if (!b || b.dataset.cat === cat) return;
    const ids = ["all", ...PARTNER_CATEGORIES.filter(Boolean)];
    const dir = ids.indexOf(b.dataset.cat) > ids.indexOf(cat) ? 1 : -1;
    cat = b.dataset.cat;
    pills.querySelectorAll("[data-cat]").forEach((x) => x.classList.toggle("on", x === b));
    placeBar(bar, b);
    el.querySelector("#plist").innerHTML = rows();
    slideIn(el.querySelector("#plist"), dir);
  });
  const input = el.querySelector("input");
  input.addEventListener("input", () => {
    find = input.value;
    el.querySelector("#plist").innerHTML = rows();
  });
  el.querySelector("#plist").addEventListener("click", (e) => {
    const r = e.target.closest("[data-partner]");
    if (r) location.hash = `#/partners/${r.dataset.partner}`;
    else if (e.target.closest(".rw")) toast("Contacts open from Settings for now");
  });
}
