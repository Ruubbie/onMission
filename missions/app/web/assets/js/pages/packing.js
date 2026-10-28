// Packing: what goes in which bag, and what is packed. The suitcase fills as you pack. Port of
// prototype.html PAGES.packing. Items are packing records (bag, packed, weightGrams, quantity).

import { store } from "../store.js";
import { I, anim, tween, spring } from "../motion.js";
import { esc, ring, toast, swapText, placeBar, slideIn, pop } from "../ui.js";
import { BAG_LABEL, BAG_LIMIT_KG } from "../util.js";
import { patch } from "./common.js";

export const title = "Packing";
export const parent = "move";
export const kick = "Packing";

const BAGS = ["checked", "carry-on", "ship"];
const SEG_LABEL = { checked: "Checked", "carry-on": "Carry-on", ship: "Ship" };
let bag = "checked";

const itemsIn = (b) => store.list("packing").filter((p) => p.bag === b).sort((a, b2) => (a.name ?? "").localeCompare(b2.name ?? ""));
const kgOf = (items) => items.reduce((s, p) => s + ((p.weightGrams ?? 0) * (p.quantity ?? 1)), 0) / 1000;
const pctOf = (items) => (items.length ? Math.round((items.filter((p) => p.packed).length / items.length) * 100) : 0);

export function build() {
  const items = itemsIn(bag);
  const kg = kgOf(items);
  const limit = BAG_LIMIT_KG[bag];
  return `
    <div class="abs hand hi in" data-hi>${esc(BAG_LABEL[bag])}</div>
    <div class="abs disp in" data-n style="left:18px;top:138px;font-size:122px;line-height:.8">${pctOf(items)}%</div>
    <div class="abs cap in" data-cp style="left:24px;top:272px">${esc(kgText(kg, limit))}</div>
    <img class="abs art pic in" src="assets/art/packing.webp" alt="" data-case style="left:216px;top:112px;width:168px">
    <div class="sheet" style="padding-top:10px">
      <div class="seg" id="seg">${BAGS.map((b) => `<button data-bag="${b}" class="${b === bag ? "on" : ""}">${SEG_LABEL[b]}<i>${itemsIn(b).length}</i></button>`).join("")}<i class="bar"></i></div>
      <div class="scroll" data-list>${items.map(row).join("") || `<div class="rw"><div class="tx"><div class="t1">Nothing in this bag yet</div><div class="t2">Add an item with + and "pack: passport".</div></div></div>`}</div>
    </div>`;
}

function kgText(kg, limit) {
  return limit ? `${kg.toFixed(1)} of ${limit} kg` : `${kg.toFixed(1)} kg`;
}

function row(p) {
  const kg = ((p.weightGrams ?? 0) * (p.quantity ?? 1)) / 1000;
  return `<div class="rw ${p.packed ? "struck" : ""}" data-item="${esc(p.id)}">${ring(!!p.packed, "Packed")}
    <div class="tx"><div class="t1">${esc(p.name)}${p.quantity > 1 ? ` ×${p.quantity}` : ""}</div><div class="t2">${esc(p.category ?? "")}</div></div>
    <span class="when">${kg ? `${kg.toFixed(1)} kg` : ""}</span></div>`;
}

export function init(el) {
  const seg = el.querySelector("#seg");
  placeBar(seg.querySelector(".bar"), seg.querySelector(".on"));
  lvl(el, pctOf(itemsIn(bag)) / 100);
  seg.addEventListener("click", (e) => {
    const b = e.target.closest("[data-bag]");
    if (!b || b.dataset.bag === bag) return;
    const dir = BAGS.indexOf(b.dataset.bag) > BAGS.indexOf(bag) ? 1 : -1;
    bag = b.dataset.bag;
    document.dispatchEvent(new Event("app:refresh"));
    queueMicrotask(() => {
      const list = document.querySelector(".pg [data-list]");
      if (list) slideIn(list, dir);
    });
  });

  el.querySelector("[data-list]").addEventListener("click", async (e) => {
    if (!e.target.closest("[data-ring]")) return;
    const row = e.target.closest("[data-item]");
    const item = store.get("packing", row.dataset.item);
    if (!item || item.packed) return;
    row.querySelector("[data-ring]").classList.add("ticked");
    row.classList.add("struck");
    const caseEl = el.querySelector("[data-case]");
    anim(caseEl, [{ transform: "none" }, { transform: "rotate(-3deg) translateY(2px)" }, { transform: "rotate(2deg)" }, { transform: "none" }], { duration: 480, easing: "ease-out" });
    await patch("packing", item.id, { packed: true });
    const left = itemsIn(bag);
    if (left.every((p) => p.packed) && left.length) toast(`${BAG_LABEL[bag]} is packed`);
  });
}

function lvl(el, p) {
  const y = 248 - p * 186;
  const w = `M0 ${y} C 30 ${y - 6}, 50 ${y + 6}, 70 ${y} S 110 ${y - 6}, 140 ${y}`;
  el.querySelector("[data-lvl]")?.setAttribute("d", w);
  el.querySelector("[data-fill]")?.setAttribute("d", `${w} L140 272 L0 272 Z`);
}

export function fill(el, to) {
  return tween(900, (t) => lvl(el, spring(t) * to));
}

