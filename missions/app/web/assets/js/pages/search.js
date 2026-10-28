// Search (Ctrl+K): one field over tasks, people, papers and notes. Opens as a page, like the other pages.

import { store } from "../store.js";
import { esc } from "../ui.js";
import { I } from "../motion.js";

export const title = "Search";
export const parent = "today";
export const kick = "Search";

export function build() {
  return `
    <div class="abs hand hi in">Find anything</div>
    <div class="sheet" style="top:146px"><label class="search" style="margin-top:4px">${I.search}<input type="search" placeholder="Tasks, people, papers, notes" aria-label="Search" autofocus></label>
      <div class="scroll" data-results>${results("")}</div></div>`;
}

function results(query) {
  const q = query.trim().toLowerCase();
  if (!q) return `<div class="rw"><div class="tx"><div class="t1">Type to search</div><div class="t2">Tasks, people, papers and notes, in one place.</div></div></div>`;
  const hits = [];
  for (const t of store.list("tasks")) if (t.title?.toLowerCase().includes(q)) hits.push({ title: t.title, sub: `Task${t.dueDate ? ` · ${t.dueDate}` : ""}`, route: `task/${t.id}` });
  for (const p of store.list("partners")) if (p.name?.toLowerCase().includes(q)) hits.push({ title: p.name, sub: `Person · ${p.stage}`, route: `partners/${p.id}` });
  for (const d of store.list("documents")) if ([d.title, d.fileName, d.notes].some((x) => x && x.toLowerCase().includes(q))) hits.push({ title: d.title, sub: "Paper in the Vault", route: "vault" });
  for (const n of store.list("notes")) if ([n.title, n.body].some((x) => x && x.toLowerCase().includes(q))) hits.push({ title: n.title || "Untitled", sub: `Note · ${n.kind}`, route: n.kind === "prayer" ? "prayer" : "notes" });
  if (!hits.length) return `<div class="rw"><div class="tx"><div class="t1">Nothing found</div><div class="t2">Try a shorter word.</div></div></div>`;
  return hits.slice(0, 40).map((h) => `<button class="rw tap" data-route="${esc(h.route)}" style="width:100%;text-align:left"><div class="tx"><div class="t1">${esc(h.title)}</div><div class="t2">${esc(h.sub)}</div></div></button>`).join("");
}

export function init(el) {
  const input = el.querySelector("input");
  const out = el.querySelector("[data-results]");
  input.addEventListener("input", () => { out.innerHTML = results(input.value); });
  out.addEventListener("click", (e) => {
    const r = e.target.closest("[data-route]");
    if (r) location.hash = `#/${r.dataset.route}`;
  });
  input.focus();
}
