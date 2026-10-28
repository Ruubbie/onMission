// "Someone gives": one small form for the most common thing to note about a person. Type a name (someone already in
// your people, or someone new), an amount and whether it is monthly or once, and it is saved: no stages to walk
// through first. Used on the People tab and on a person's page.

import { store } from "../store.js";
import { esc, toast } from "../ui.js";
import { parseCents, todayStr } from "../util.js";
import { patch } from "./common.js";
import { euroWhole } from "./money.js";

/** The form, closed until its opener is pressed. `name` fills in (and hides) the name field on a person's page. */
export function giveForm({ name = "", id = "give" } = {}) {
  const fixed = !!name;
  return `<form class="give" id="${id}" hidden>
    ${fixed ? `<input type="hidden" name="who" value="${esc(name)}">` : `<label class="give-f"><span>Who</span>
      <input name="who" list="${id}-names" autocomplete="off" placeholder="Name" required>
      <datalist id="${id}-names">${store.list("partners").map((p) => `<option value="${esc(p.name)}">`).join("")}</datalist></label>`}
    <label class="give-f"><span>Amount</span><input name="amount" inputmode="decimal" placeholder="€ 25" required></label>
    <div class="give-how" role="radiogroup" aria-label="How often">
      <label><input type="radio" name="how" value="monthly" checked><span>A month</span></label>
      <label><input type="radio" name="how" value="once"><span>Once</span></label>
    </div>
    <div class="give-acts"><button class="btn sm f" type="submit">Save</button><button class="btn sm o" type="button" data-give-cancel>Cancel</button></div>
  </form>`;
}

/** Wires the opener (any [data-give-open] in root) and the form. `done` runs after a save. */
export function bindGive(root, { id = "give", done } = {}) {
  const form = root.querySelector(`#${id}`);
  if (!form) return;
  root.querySelectorAll("[data-give-open]").forEach((b) => b.addEventListener("click", () => {
    form.hidden = false;
    form.querySelector("input:not([type=hidden])").focus();
  }));
  form.querySelector("[data-give-cancel]").addEventListener("click", () => { form.hidden = true; });
  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const data = new FormData(form);
    const name = String(data.get("who") ?? "").trim();
    const cents = parseCents(String(data.get("amount") ?? ""));
    if (!name || !cents) return toast("Fill in a name and an amount", { bad: true });
    const monthly = data.get("how") === "monthly";
    const p = await recordGiving(name, cents, monthly);
    form.hidden = true;
    form.reset();
    toast(monthly ? `${p.name} gives ${euroWhole(cents)} a month` : `${euroWhole(cents)} from ${p.name} noted`);
    done?.(p);
  });
}

/** Saves that someone gives: finds them by name or adds them, then sets the monthly amount or records the gift. */
export async function recordGiving(name, cents, monthly) {
  const key = name.toLowerCase();
  let p = store.list("partners").find((x) => (x.name ?? "").trim().toLowerCase() === key);
  if (!p) p = await store.create("partners", { name, stage: "idea", currency: "EUR", prayer: false, newsletter: false, links: [] });
  const changes = { stage: "giving", startDate: p.startDate ?? todayStr() };
  if (monthly) changes.monthlyCents = cents;
  else {
    changes.oneOffCents = (p.oneOffCents ?? 0) + cents;
    await store.create("gifts", { partnerId: p.id, amountCents: cents, currency: p.currency ?? "EUR", date: todayStr(), recurring: false });
  }
  return (await patch("partners", p.id, changes)) ?? p;
}
