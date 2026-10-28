// The + sheet: a full cream cover that floods out of the +. You type once; the kind is guessed
// from a prefix (@Name, pray:, note:) or from what you pick, and the field under it shows the context.

import { store } from "./store.js";
import { I, anim, draw } from "./motion.js";
import { esc, toast } from "./ui.js";
import { parseQuickTask, todayStr } from "./util.js";
import { createTask, whenLabel } from "./pages/common.js";
import { recordGiving } from "./pages/give.js";
import { euroWhole } from "./pages/money.js";

const KINDS = [
  { id: "task", label: "Task", field: "Due", tab: "tasks" },
  { id: "person", label: "Person", field: "Gives", tab: "people" },
  { id: "prayer", label: "Prayer", field: "Shows in", tab: "prayer" },
  { id: "note", label: "Note", field: "Link to", tab: "move" },
];

// The line drawing for each kind, from the prototype.
const DRAWINGS = {
  task: '<path class="crf" d="M150 30 C 180 28, 220 28, 246 31 C 250 32, 252 35, 252 39 L251 140 C 251 144, 248 147, 244 147 L152 148 C 147 148, 144 145, 144 140 L145 38 C 145 33, 147 31, 150 30 Z"/><path d="M162 62 L172 72 L190 54"/><path d="M200 66 L236 65"/><path d="M162 104 L172 114 L190 96"/><path d="M200 108 L230 107"/>',
  person: '<circle cx="176" cy="62" r="24"/><path d="M130 146 C 134 112, 152 96, 176 96 S 218 112, 222 146"/><circle cx="238" cy="72" r="18"/><path d="M226 102 C 250 100, 266 118, 270 146"/>',
  prayer: '<path class="crf" d="M195 14 C 214 40, 236 56, 236 92 A 41 41 0 0 1 154 92 C 154 56, 176 40, 195 14 Z"/><path d="M195 92 C 204 102, 211 109, 211 120 A 16 16 0 0 1 179 120 C 179 109, 186 102, 195 92 Z"/>',
  note: '<path class="crf" d="M146 30 L232 30 L250 48 L250 148 L146 148 Z"/><path d="M232 30 L232 48 L250 48"/><path d="M164 76 L230 76"/><path d="M164 100 L222 100"/><path d="M164 124 L204 124"/>',
};

let kind = "task";
let manual = false;

export function initCapture() {
  const el = document.getElementById("cap");
  el.innerHTML = `
    <div class="top"><span class="kicker">Add anything</span></div>
    <svg class="capart" viewBox="0 0 390 160"><g class="ln">
      ${KINDS.map((k) => `<g class="k" data-k="${k.id}">${DRAWINGS[k.id]}</g>`).join("")}
    </g></svg>
    <input class="entry-input" id="entryInput" placeholder="What needs doing?" aria-label="What to add" autocomplete="off">
    <div class="abs hand guess" id="guess">↓ sounds like a person</div>
    <div class="chips" id="chips"><i class="cpill" id="cpill"></i>${KINDS.map((k) => `<button class="chip" data-k="${k.id}">${k.label}</button>`).join("")}</div>
    <div class="field" id="field"></div>
    <button id="addBtn"><span id="addTx">Add task</span>${I.arrow}</button>`;

  const input = document.getElementById("entryInput");
  input.addEventListener("input", () => { manual = false; guess(input.value); paint(input.value); });
  input.addEventListener("keydown", (e) => { if (e.key === "Enter") add(); });
  el.querySelector("#chips").addEventListener("click", (e) => {
    const c = e.target.closest(".chip");
    if (!c) return;
    manual = true;
    kind = c.dataset.k;
    paint(input.value);
  });
  el.querySelector("#addBtn").addEventListener("click", add);
}

/** The prefix a user typed decides the kind, unless they picked one with a chip. */
function guess(text) {
  if (manual) return;
  if (/^@/.test(text) || /^person:/i.test(text)) kind = "person";
  else if (/^pray:/i.test(text)) kind = "prayer";
  else if (/^note:/i.test(text)) kind = "note";
  else kind = "task";
  document.getElementById("guess").classList.toggle("on", kind === "person" && /^@/.test(text));
}

function stripped(text) {
  return text.replace(/^(@|person:|pray:|note:)\s*/i, "").trim();
}

const MONTHLY = /\b(?:a|per|each|every)\s+(?:month|maand)\b|\/\s*(?:month|maand|mnd|m)\b|\bmonthly\b|\bmaandelijks\b|\bp\/?m\b/i;

/**
 * A person with what they give, if the text says so: "Jan €50 a month", "Kerk 400 euro per maand", "Oma €200".
 * Without an amount it is just a name.
 */
export function parsePerson(text) {
  const t = stripped(text);
  const amount = t.match(/€\s*(\d+(?:[.,]\d{1,2})?)|(\d+(?:[.,]\d{1,2})?)\s*(?:€|euro\b|eur\b)/i);
  if (!amount) return { name: t, cents: 0, monthly: false };
  const cents = Math.round(parseFloat((amount[1] ?? amount[2]).replace(",", ".")) * 100);
  const monthly = MONTHLY.test(t);
  const name = t.replace(amount[0], " ").replace(MONTHLY, " ").replace(/\b(?:gives?|geeft|pledged|once|eenmalig)\b/gi, " ")
    .replace(/\s+/g, " ").trim();
  return { name, cents, monthly };
}

function personField(text) {
  const g = parsePerson(text);
  if (!g.cents) return "Add “€50 a month” if they do";
  return g.monthly ? `${euroWhole(g.cents)} a month` : `${euroWhole(g.cents)} once`;
}

function paint(text) {
  const el = document.getElementById("cap");
  const k = KINDS.find((x) => x.id === kind);
  el.querySelectorAll(".chip").forEach((c) => c.classList.toggle("on", c.dataset.k === kind));
  const on = el.querySelector(".chip.on"), pill = el.querySelector("#cpill");
  if (on) { pill.style.left = `${on.offsetLeft}px`; pill.style.width = `${on.offsetWidth}px`; }
  el.querySelectorAll(".capart .k").forEach((g) => {
    const show = g.dataset.k === kind;
    g.classList.toggle("on", show);
    if (show) g.querySelectorAll("path,circle").forEach((p, i) => {
      p.setAttribute("pathLength", 1);
      p.style.strokeDasharray = "1";
      p.animate([{ strokeDashoffset: 1 }, { strokeDashoffset: 0 }], { duration: 650, delay: i * 50, easing: "cubic-bezier(.6,0,.3,1)", fill: "backwards" });
    });
  });
  const parsed = kind === "task" ? parseQuickTask(text) : null;
  const value = {
    task: parsed?.dueDate ? whenLabel(parsed.dueDate) : "No date",
    person: personField(text),
    prayer: "Prayer list",
    note: "Nothing yet",
  }[kind];
  el.querySelector("#field").innerHTML = `<span>${k.field}</span><b>${esc(value)}</b>`;
  el.querySelector("#addTx").textContent = `Add ${k.label.toLowerCase()}`;
}

async function add() {
  const input = document.getElementById("entryInput");
  const text = input.value.trim();
  if (!text) return input.focus();
  const k = KINDS.find((x) => x.id === kind);
  if (kind === "task") {
    await createTask(parseQuickTask(text, todayStr()));
  } else if (kind === "person") {
    const g = parsePerson(text);
    if (g.cents && g.name) await recordGiving(g.name, g.cents, g.monthly);
    else await store.create("partners", { name: g.name, stage: "idea", currency: "EUR", prayer: false, newsletter: false, links: [] });
  } else if (kind === "prayer") {
    await store.create("notes", { title: text.slice(0, 60), kind: "prayer", body: stripped(text), area: null, pinned: false, public: false, links: [], prayedCount: 0 });
  } else {
    await store.create("notes", { title: stripped(text).slice(0, 60), kind: "note", body: "", area: null, pinned: false, public: false, links: [] });
  }
  input.value = "";
  closeCapture();
  toast(kind === "person" ? `${parsePerson(text).name} added to People` : `Added to ${k.label === "Prayer" ? "Prayer" : k.tab === "move" ? "Notes" : k.label + "s"}`);
  location.hash = kind === "note" ? "#/notes" : `#/${k.tab}`;
}

export function openCapture() {
  kind = "task";
  manual = false;
  document.getElementById("cap").classList.add("open");
  document.getElementById("entryInput").value = "";
  paint("");
  document.dispatchEvent(new Event("app:refresh"));
  setTimeout(() => document.getElementById("entryInput").focus(), 650);
}

export function closeCapture() {
  document.getElementById("cap")?.classList.remove("open");
  document.getElementById("entryInput")?.blur();
  document.dispatchEvent(new Event("app:refresh"));
}

export function isCaptureOpen() {
  return !!document.getElementById("cap")?.classList.contains("open");
}

