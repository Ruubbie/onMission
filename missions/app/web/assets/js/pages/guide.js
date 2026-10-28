// The guide reader: a cream page with no poster. A progress line under the top bar follows the
// scroll; Mark as read draws its check and returns to the guides. Port of prototype.html PAGES.reader.

import { I, anim, wait } from "../motion.js";
import { esc, pop, toast, draw } from "../ui.js";
import { GUIDES } from "./guides-data.js";
import { markRead, progressOf } from "./guides.js";

export const title = "Guide";
export const parent = "guides";
export const cream = true;
export const kick = (ctx) => `Guide · ${GUIDES[+ctx.id]?.m ?? ""} read`;

export function build(ctx) {
  const i = +ctx.id;
  const g = GUIDES[i];
  if (!g) return `<div class="reader"><p class="lead">This guide is gone.</p></div>`;
  return `
    <div class="rprog"><i></i></div>
    <div class="reader">
      <div class="rk in">Guide · ${esc(g.m)} read</div>
      <h2 class="disp in">${esc(g.t)}</h2>
      <p class="lead in">${esc(g.lead)}</p>
      <ol class="steps">${g.steps.map(([h, b], n) => `<li><span class="disp">${n + 1}</span><div><b>${esc(h)}</b><p>${esc(b)}</p></div></li>`).join("")}</ol>
      <blockquote class="hand">${esc(g.quote)}</blockquote>
      <button class="btn f wide" data-read>${progressOf(i) >= 1 ? "Read it again" : "Mark as read"}</button>
    </div>`;
}

export function init(el, ctx) {
  const i = +ctx.id;
  const rd = el.querySelector(".reader");
  const bar = el.querySelector(".rprog i");
  rd.addEventListener("scroll", () => {
    bar.style.transform = `scaleX(${rd.scrollTop / Math.max(1, rd.scrollHeight - rd.clientHeight)})`;
  });
  el.querySelector("[data-read]").addEventListener("click", async (e) => {
    const b = e.currentTarget;
    markRead(i);
    b.innerHTML = `<svg viewBox="0 0 24 24" class="ln" style="stroke-width:2.6;width:20px;height:20px"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>Read`;
    draw(b, 0);
    pop(b);
    anim(bar, [{ transform: `scaleX(${rd.scrollTop / Math.max(1, rd.scrollHeight - rd.clientHeight)})` }, { transform: "scaleX(1)" }], { duration: 400, fill: "forwards" });
    await wait(800);
    toast("Marked as read");
    location.hash = "#/guides";
  });
}
