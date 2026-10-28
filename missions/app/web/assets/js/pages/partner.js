// A partner: where they are on the path from list to giving, the next step as one hero card, and
// the story. Port of prototype.html PAGES.partner.

import { store } from "../store.js";
import { I, tween, ease, anim, wait } from "../motion.js";
import { esc, toast, pop, rise, draw } from "../ui.js";
import { todayStr } from "../util.js";
import { patch, PATH, pathIndex, STAGE_LABEL, latestMessage, messageDay, replyMailto, markAnswered } from "./common.js";
import { openCheckin } from "../checkin.js";

export const title = "Partner";
export const kick = "People";
export const parent = "people";

const sx = (i) => 40 + i * 62;

export function build(ctx) {
  const p = store.get("partners", ctx.id);
  if (!p) return `<div class="abs hand hi in">Not found</div><div class="sheet"><div class="rw"><div class="tx"><div class="t1">This person is gone.</div></div></div></div>`;
  const idx = Math.max(0, pathIndex(p.stage));
  const cat = p.category ? `Category ${p.category}` : "Partner";
  return `
    <div class="abs hand hi in">${esc(cat)} · ${esc(STAGE_LABEL[p.stage] ?? p.stage)}</div>
    <div class="abs disp in" style="left:20px;top:140px;font-size:${p.name.length > 16 ? 66 : 96}px;line-height:.86">${esc(p.name)}</div>
    <svg class="abs" data-path style="left:0;top:304px;overflow:visible" width="390" height="86" viewBox="0 0 390 86">
      <path class="ln" stroke-dasharray="1 8" d="M40 26 L350 26"/>
      <path class="ln" data-prog style="stroke-width:3.4" d="M40 26 L${sx(idx)} 26"/>
      ${PATH.map((s, i) => `<circle data-stop="${i}" cx="${sx(i)}" cy="26" r="5.5" stroke="#1E1A17" stroke-width="2.4" style="fill:${sx(i) <= sx(idx) ? "#1E1A17" : "#E9DFCE"}"/><text data-lab="${i}" x="${sx(i)}" y="62" text-anchor="middle" font-family="Archivo" font-weight="800" font-size="11.5" letter-spacing="1" fill="#1E1A17" opacity="${i === idx ? 1 : 0.5}">${s.label}</text>`).join("")}
      <circle data-halo cx="${sx(idx)}" cy="26" r="11" fill="none" stroke="#1E1A17" stroke-width="2" opacity="0"/>
      <circle data-w cx="${sx(idx)}" cy="26" r="11" fill="#1E1A17"/>
    </svg>
    <div class="sheet"><div class="scroll">${body(p)}</div></div>`;
}

function body(p) {
  const hero = heroFor(p);
  const notes = store.list("notes").filter((n) => (n.links ?? []).some((l) => l.collection === "partners" && l.id === p.id));
  const messages = (Array.isArray(p.siteMessages) ? p.siteMessages : []).filter((m) => m && m.text);
  return `
    <div class="sec">Next <b class="late-b">${esc(hero.when)}</b></div>
    <div class="hero" data-hero>
      <div class="ht">${esc(hero.title)}</div>
      <div class="t2${hero.msg ? " msg" : ""}">${esc(hero.sub)}</div>
      <div class="acts">${hero.actions}</div>
    </div>
    <div class="sec">Story <b>${messages.length + notes.length + (p.lastContactAt ? 1 : 0)}</b></div>
    ${messages.map((m) => `<div class="rw"><div class="tx"><div class="t1">Wrote on hesent.me</div><div class="t2 clamp">${esc(m.text.replace(/\n/g, " "))}</div></div><span class="when">${esc(shortDay(m.at))}</span></div>`).join("")}
    ${p.lastContactAt ? `<div class="rw"><div class="tx"><div class="t1">Last contact</div><div class="t2">${esc(STAGE_LABEL[p.stage] ?? p.stage)}</div></div><span class="when">${esc(shortDay(p.lastContactAt))}</span></div>` : ""}
    ${notes.map((n) => `<div class="rw"><div class="tx"><div class="t1">${esc(n.title)}</div><div class="t2">${esc((n.body ?? "").slice(0, 60))}</div></div><span class="when">${esc(shortDay(n.createdAt))}</span></div>`).join("")}
    ${p.notes ? `<div class="rw"><div class="tx"><div class="t1">About ${esc(p.name.split(" ")[0])}</div><div class="t2">${esc(p.notes)}</div></div></div>` : ""}`;
}

function heroFor(p) {
  // A message from hesent.me waiting for an answer comes before whatever the stage asks for.
  const m = p.replyWaiting === true ? latestMessage(p) : null;
  if (m) {
    const first = p.name.split(" ")[0] || "They";
    return { when: `Sent on hesent.me ${messageDay(m)}`, title: `${first} wrote to you`, sub: `“${m.text}”`, msg: true,
      actions: `${p.email ? `<button class="btn f" data-act="reply">${I.mail}Reply</button>` : ""}<button class="btn o" data-act="answered">Mark answered</button>` };
  }
  if (p.stage === "giving" && !(p.thankedAt && p.thankedAt.slice(0, 10) === todayStr())) {
    return { when: "Today", title: "Say thanks", sub: "They give every month. A quick note means a lot.", actions: `<button class="btn f" data-act="thanks">${I.heart}Say thanks</button><button class="btn o" data-act="msg">Message</button>` };
  }
  if (p.stage === "committed") {
    return { when: "Today", title: "Set the amount", sub: "They said yes. Thank them while it is fresh.", actions: `<button class="btn f" data-act="thanks">${I.heart}Say thanks</button><button class="btn o" data-act="msg">Record a gift</button>` };
  }
  if (p.stage === "paused") {
    return { when: "In spring", title: "Catch up in spring", sub: "No pressure. You'll get a reminder in March.", actions: `<button class="btn o" data-act="msg">Write a note</button>` };
  }
  return { when: "Was due yesterday", title: "Check in about the decision", sub: "They wanted some time to pray about it.", actions: `<button class="btn f" data-act="checkin">${I.phone}Check in</button><button class="btn o" data-act="msg">Message</button>` };
}

export function init(el, ctx) {
  const p = store.get("partners", ctx.id);
  if (!p) return;
  const idx = Math.max(0, pathIndex(p.stage));
  const halo = el.querySelector("[data-halo]");
  // On entry the walker slides along the path to her stage, then a halo pulses.
  const walker = el.querySelector("[data-w]");
  const paint = (x) => {
    el.querySelector("[data-prog]").setAttribute("d", `M40 26 L${x} 26`);
    walker.setAttribute("cx", x);
    halo.setAttribute("cx", x);
  };
  const start = sx(0), end = sx(idx);
  paint(start);
  tween(1000, (t) => paint(start + (end - start) * ease(t))).then(() => {
    anim(halo, [{ transform: "scale(1)", opacity: 0.9 }, { transform: "scale(2.6)", opacity: 0 }], { duration: 900, easing: "cubic-bezier(.2,.8,.2,1)" });
  });

  el.addEventListener("click", async (e) => {
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
      await patch("partners", p.id, { thankedAt: new Date().toISOString() });
      toast("Thank-you noted");
      return;
    }
    toast(`Opens a message to ${p.name}`);
  });
}

function shortDay(iso) {
  if (!iso) return "";
  return new Date(iso.length > 10 ? iso : `${iso}T12:00:00`).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}
