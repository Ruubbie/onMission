// Selling: what you're selling up before you go. Sold stamps the row, the price flies into the total,
// and the tag swings. Port of prototype.html PAGES.selling. Items are sellItems records.

import { store } from "../store.js";
import { anim, wait } from "../motion.js";
import { esc, toast, fold } from "../ui.js";
import { toEurCents } from "../util.js";
import { patch } from "./common.js";
import { euroWhole } from "./money.js";

export const title = "Selling";
export const parent = "move";
export const kick = "Selling";

const OFF_MARKET = ["sold", "given-away", "keep", "store"];

function unsold() {
  return store.list("sellItems").filter((s) => !OFF_MARKET.includes(s.status)).sort((a, b) => (a.name ?? "").localeCompare(b.name ?? ""));
}

function soldTotal() {
  const rate = store.settings().nzdPerEur;
  return store.list("sellItems").filter((s) => s.status === "sold").reduce((sum, s) => sum + toEurCents(s.soldCents ?? 0, s.currency, rate), 0);
}

export function build() {
  const items = unsold();
  const listed = items.filter((s) => s.status === "listed").length;
  return `
    <div class="abs hand hi in">Selling up</div>
    <div class="abs disp in" data-n style="left:20px;top:140px;font-size:104px">${euroWhole(soldTotal())}</div>
    <div class="abs cap in" data-cp style="left:24px;top:252px">Sold so far<br>${listed} ${listed === 1 ? "thing" : "things"} listed</div>
    <svg class="abs art" style="left:262px;top:204px;overflow:visible" width="110" height="160" viewBox="0 0 110 160"><g class="ln">
      <circle class="crf" cx="55" cy="6" r="4.5"/>
      <g class="swing" data-tag>
        <path d="M55 6 L55 46"/>
        <path class="bgf" d="M28 56 L55 38 L82 56 L82 146 C 82 151, 78 154, 73 154 L37 154 C 32 154, 28 151, 28 146 Z"/>
        <circle cx="55" cy="56" r="5"/>
        <text x="55" y="124" text-anchor="middle" font-family="Archivo" font-weight="900" font-size="42" fill="#F4EDE1" stroke="none">€</text>
      </g>
    </g></svg>
    <div class="sheet"><div class="sec">On the market <b>${items.length}</b></div><div class="scroll" data-list>${items.map(row).join("") || `<div class="rw"><div class="tx"><div class="t1">Nothing on the market</div><div class="t2">Items you're selling appear here.</div></div></div>`}</div></div>`;
}

function row(s) {
  const price = s.status === "listed" || s.status === "reserved" ? s.askingCents : s.askingCents;
  const label = price != null ? `€${Math.round(price / 100).toLocaleString("en-GB")}` : "";
  const sub = { decide: "Deciding", "to-list": "Not listed yet", listed: s.platform ? `Listed on ${s.platform}` : "Listed", reserved: s.buyer ? `Reserved for ${s.buyer}` : "Reserved" }[s.status] ?? s.status;
  return `<div class="rw" data-item="${esc(s.id)}"><div class="tx"><div class="t1">${esc(s.name)}</div><div class="t2">${esc(sub)}</div></div>
    <span class="when">${esc(label)}</span>
    <button class="btn sm ${s.status === "to-list" || s.status === "decide" ? "o" : "f"}" data-sell>${s.status === "to-list" || s.status === "decide" ? "List" : "Sold"}</button></div>`;
}

export function init(el) {
  const tag = el.querySelector("[data-tag]");
  swing(tag, 500);

  el.querySelector("[data-list]").addEventListener("click", async (e) => {
    const b = e.target.closest("[data-sell]");
    if (!b || b.disabled) return;
    const row = e.target.closest("[data-item]");
    const s = store.get("sellItems", row.dataset.item);
    if (!s) return;
    if (b.textContent.trim() === "List") {
      toast("Opens a Marktplaats listing");
      return;
    }
    b.disabled = true;
    row.insertAdjacentHTML("beforeend", '<span class="stamp">Sold</span>');
    const st = row.querySelector(".stamp");
    await anim(st, [{ transform: "rotate(-18deg) scale(1.9)", opacity: 0 }, { transform: "rotate(-9deg) scale(1)", opacity: 1 }], { duration: 260, easing: "cubic-bezier(.6,0,.9,.6)", fill: "forwards" });
    anim(row, [{ transform: "none" }, { transform: "translateY(2px)" }, { transform: "none" }], { duration: 170 });
    swing(tag, 0);
    await wait(650);
    await fold(row);
    await patch("sellItems", s.id, { status: "sold", soldCents: s.askingCents ?? 0 });
    toast(`${s.name} sold`);
  });
}

function swing(tag, delay) {
  if (!tag) return;
  return anim(tag, [{ transform: "rotate(0)" }, { transform: "rotate(12deg)" }, { transform: "rotate(-8deg)" }, { transform: "rotate(5deg)" }, { transform: "rotate(-2deg)" }, { transform: "rotate(0)" }], { duration: 1600, delay, easing: "ease-in-out" });
}
