// A person: their name, how they are with you (gives, prays, gets letters, wants to meet: any mix, tapped on or off
// right here), the one thing that needs you if anything does, and the story. There is no ladder to climb: someone who
// only reads the letters is as much a part of it as someone who gives.

import { store } from "../store.js";
import { I } from "../motion.js";
import { esc, toast, pop } from "../ui.js";
import { parseCents, plainMoney, todayStr } from "../util.js";
import { patch, WAYS, hasWay, wayChanges, gives, involvement, needsThanks, followUpDue, whenLabel, STAGE_LABEL,
  latestMessage, messageDay, replyMailto, markAnswered } from "./common.js";
import { openCheckin } from "../checkin.js";
import { euroWhole } from "./money.js";
import { giveForm, bindGive } from "./give.js";

export const title = "Partner";
export const kick = "People";
export const parent = "people";

export function build(ctx) {
  const p = store.get("partners", ctx.id);
  if (!p) return `<div class="abs hand hi in">Not found</div><div class="sheet"><div class="rw"><div class="tx"><div class="t1">This person is gone.</div></div></div></div>`;
  return `
    <div class="abs hand hi in oneline">${esc(involvement(p, euroWhole))}</div>
    <div class="abs disp in" style="left:20px;top:140px;width:${p.name.length > 12 ? 350 : 230}px;font-size:${p.name.length > 16 ? 62 : 88}px;line-height:.95">${esc(p.name)}</div>
    <img class="abs art pic in" src="assets/art/partner.webp" alt="" style="left:256px;top:250px;width:126px">
    <div class="sheet"><div class="scroll">${body(p)}</div></div>`;
}

function body(p) {
  const first = p.name.split(" ")[0] || "them";
  const hero = heroFor(p);
  const notes = store.list("notes").filter((n) => (n.links ?? []).some((l) => l.collection === "partners" && l.id === p.id));
  const messages = (Array.isArray(p.siteMessages) ? p.siteMessages : []).filter((m) => m && m.text);
  const gifts = store.list("gifts").filter((g) => g.partnerId === p.id).sort((a, b) => (b.date ?? "").localeCompare(a.date ?? ""));
  return `
    <div class="sec">How ${esc(first)} is with you</div>
    <div class="ways">${WAYS.map((w) => `<button class="pl way ${hasWay(p, w.id) ? "on" : ""}" data-way="${w.id}" aria-pressed="${hasWay(p, w.id)}">${hasWay(p, w.id) ? I.check : ""}${w.label}</button>`).join("")}</div>
    ${gives(p) ? `<label class="set"><span class="lbl">A month</span><input data-monthly inputmode="decimal" placeholder="€ 0" value="${p.monthlyCents ? esc(plainMoney(p.monthlyCents)) : ""}"></label>` : ""}
    <label class="set"><span class="lbl">Follow up on</span><input type="date" data-follow value="${esc(p.nextFollowUp ?? "")}"></label>
    ${hero ? `<div class="sec">Next <b class="${hero.late ? "late-b" : ""}">${esc(hero.when)}</b></div>
    <div class="hero" data-hero>
      <div class="ht">${esc(hero.title)}</div>
      <div class="t2${hero.msg ? " msg" : ""}">${esc(hero.sub)}</div>
      <div class="acts">${hero.actions}</div>
    </div>` : `<div class="quick"><button class="btn sm o" data-give-open>${I.heart}Record a gift</button></div>`}
    ${giveForm({ name: p.name, id: "pgive" })}
    <div class="sec">Story <b>${gifts.length + messages.length + notes.length + (p.lastContactAt ? 1 : 0)}</b></div>
    ${gifts.map((g) => `<div class="rw"><div class="tx"><div class="t1">Gave ${esc(euroWhole(g.amountCents))}</div><div class="t2">${g.recurring ? "Monthly gift" : "One-off gift"}${g.thankedAt ? " · thanked" : ""}</div></div><span class="when">${esc(shortDay(g.date))}</span></div>`).join("")}
    ${messages.map((m) => `<div class="rw"><div class="tx"><div class="t1">Wrote on hesent.me</div><div class="t2 clamp">${esc(m.text.replace(/\n/g, " "))}</div></div><span class="when">${esc(shortDay(m.at))}</span></div>`).join("")}
    ${p.lastContactAt ? `<div class="rw"><div class="tx"><div class="t1">Last contact</div><div class="t2">${esc(p.nextStep || STAGE_LABEL[p.stage] || "")}</div></div><span class="when">${esc(shortDay(p.lastContactAt))}</span></div>` : ""}
    ${notes.map((n) => `<div class="rw"><div class="tx"><div class="t1">${esc(n.title)}</div><div class="t2">${esc((n.body ?? "").slice(0, 60))}</div></div><span class="when">${esc(shortDay(n.createdAt))}</span></div>`).join("")}
    ${p.notes ? `<div class="rw"><div class="tx"><div class="t1">About ${esc(first)}</div><div class="t2">${esc(p.notes)}</div></div></div>` : ""}`;
}

/** The one thing that needs you, or null when nothing does (then the page stays calm). */
function heroFor(p) {
  const first = p.name.split(" ")[0] || "They";
  // A message from hesent.me waiting for an answer comes first.
  const m = p.replyWaiting === true ? latestMessage(p) : null;
  if (m) {
    return { when: `Sent on hesent.me ${messageDay(m)}`, late: true, title: `${first} wrote to you`, sub: `“${m.text}”`, msg: true,
      actions: `${p.email ? `<button class="btn f" data-act="reply">${I.mail}Reply</button>` : ""}<button class="btn o" data-act="answered">Mark answered</button>` };
  }
  if (needsThanks(p)) {
    return { when: "Today", title: "Say thanks", sub: "A quick note means a lot.", actions: `<button class="btn f" data-act="thanks">${I.heart}Say thanks</button><button class="btn o" data-give-open>Record a gift</button>` };
  }
  if (followUpDue(p)) {
    const late = p.nextFollowUp < todayStr();
    return { when: whenLabel(p.nextFollowUp), late, title: p.nextStep || `Catch up with ${first}`, sub: "You planned this yourself.",
      actions: `<button class="btn f" data-act="checkin">${I.phone}Check in</button><button class="btn o" data-act="done">Done</button>` };
  }
  if (p.wantsToMeet === true && !p.nextFollowUp) {
    return { when: "When it suits", title: `Plan a coffee with ${first}`, sub: `${first} would like to meet. Pick a day above.`, actions: `<button class="btn o" data-act="met">We met</button>` };
  }
  return null;
}

export function init(el, ctx) {
  const p = store.get("partners", ctx.id);
  if (!p) return;
  bindGive(el, { id: "pgive", done: () => ctx.refresh() });

  el.addEventListener("click", async (e) => {
    const way = e.target.closest("[data-way]");
    if (way) {
      const on = !hasWay(p, way.dataset.way);
      pop(way);
      await patch("partners", p.id, wayChanges(p, way.dataset.way, on));
      ctx.refresh();
      // The redraw replaced the page; the amount field is new.
      if (on && way.dataset.way === "gives") document.querySelector(".pg [data-monthly]")?.focus();
      return;
    }
    const b = e.target.closest("[data-act]");
    if (!b) return;
    const act = b.dataset.act;
    if (act === "checkin") return openCheckin(p);
    if (act === "reply" || act === "answered") {
      if (act === "reply") location.href = replyMailto(p);
      await markAnswered(p);
      toast("Marked as answered");
      return;
    }
    if (act === "thanks") {
      b.innerHTML = `${I.heart}Thanked`;
      pop(b);
      await patch("partners", p.id, { thankedAt: todayStr() });
      toast("Thank-you noted");
      return;
    }
    if (act === "done" || act === "met") {
      await patch("partners", p.id, { lastContactAt: todayStr(), nextFollowUp: undefined, nextStep: undefined, ...(act === "met" ? { wantsToMeet: undefined } : {}) });
      toast(act === "met" ? "Noted that you met" : "Done");
    }
  });

  el.querySelector("[data-monthly]")?.addEventListener("change", async (e) => {
    const cents = parseCents(e.target.value);
    await patch("partners", p.id, { monthlyCents: cents || undefined });
    if (cents) toast(`${p.name.split(" ")[0]} gives ${euroWhole(cents)} a month`);
    ctx.refresh();
  });
  el.querySelector("[data-follow]")?.addEventListener("change", async (e) => {
    await patch("partners", p.id, { nextFollowUp: e.target.value || undefined });
    ctx.refresh();
  });
}

function shortDay(iso) {
  if (!iso) return "";
  return new Date(iso.length > 10 ? iso : `${iso}T12:00:00`).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}
