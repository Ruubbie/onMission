// Shared domain bits for the screens: saving changes, creating tasks, the partner stages and the
// task buckets. The rules match the Windows app (TasksViewModel.cs, PartnersViewModel.cs).

import { store } from "../store.js";
import { addDays, dayDiff, todayStr } from "../util.js";

/** Saves changes to one record and keeps every other field. */
export function patch(collection, id, changes) {
  const current = store.get(collection, id);
  if (!current) return Promise.resolve(null);
  return store.save(collection, { ...current, ...changes });
}

export function isDone(t) {
  return t.status === "done" || t.status === "skipped";
}

/** Creates a task from parsed fields (see parseQuickTask in util.js). */
export async function createTask(fields, checklistId = null) {
  const siblings = store.list("tasks").filter((t) => (t.checklistId ?? null) === checklistId);
  return store.create("tasks", {
    title: fields.title,
    status: fields.status ?? "todo",
    priority: fields.priority ?? "normal",
    dueDate: fields.dueDate ?? null,
    area: fields.area ?? null,
    checklistId,
    notes: null,
    order: (Math.max(0, ...siblings.map((t) => t.order ?? 0)) || 0) + 10,
  });
}

/** Marks a task done, or back to to-do, with the same completion stamp the desktop uses. */
export function setTaskDone(task, done) {
  return patch("tasks", task.id, {
    status: done ? "done" : "todo",
    completedAt: done ? new Date().toISOString() : null,
  });
}

/**
 * The three buckets of the Tasks tab. Overdue and today are "Today"; tomorrow and the next six
 * days are "This week"; later and undated are "Later".
 */
export function bucketTasks(tasks, today = todayStr()) {
  const open = tasks.filter((t) => !isDone(t));
  const out = { today: [], week: [], later: [] };
  for (const t of open) {
    if (!t.dueDate) out.later.push(t);
    else {
      const d = dayDiff(t.dueDate, today);
      if (d <= 0) out.today.push(t);
      else if (d <= 7) out.week.push(t);
      else out.later.push(t);
    }
  }
  const byDue = (a, b) => (a.dueDate ?? "9999").localeCompare(b.dueDate ?? "9999") || (b.priority === "high") - (a.priority === "high");
  out.today.sort(byDue); out.week.sort(byDue); out.later.sort(byDue);
  return out;
}

/** The label for a due date: Today, Tomorrow, a weekday within the week, or a day. */
export function whenLabel(dueDate, today = todayStr()) {
  if (!dueDate) return "No date";
  const d = dayDiff(dueDate, today);
  if (d < 0) return `${-d} ${-d === 1 ? "day" : "days"} late`;
  if (d === 0) return "Today";
  if (d === 1) return "Tomorrow";
  if (d <= 6) return new Date(`${dueDate}T12:00:00`).toLocaleDateString("en-GB", { weekday: "short" });
  return new Date(`${dueDate}T12:00:00`).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}

export const STAGE_LABEL = {
  idea: "On the list", "to-ask": "To ask", asked: "Asked", thinking: "Thinking about it",
  committed: "Committed", giving: "Giving", declined: "Declined", paused: "Not now",
};

// ---------- how someone is with you ----------
// Not a ladder: people give, pray, read the letters or want to meet, in any mix, and none of it is further along than
// another. Gives is the stage (committed or giving, which the server counts as support); prays and letters are the
// prayer and newsletter flags; wants to meet is the extra field wantsToMeet.

export const WAYS = [
  { id: "gives", label: "Gives" },
  { id: "prays", label: "Prays" },
  { id: "letters", label: "Gets letters" },
  { id: "meet", label: "Wants to meet" },
];

export function gives(p) {
  return p.stage === "committed" || p.stage === "giving";
}

/** Whether a way is on for someone. */
export function hasWay(p, id) {
  if (id === "gives") return gives(p);
  if (id === "prays") return p.prayer === true;
  if (id === "letters") return p.newsletter === true;
  return p.wantsToMeet === true;
}

/** The changes that switch a way on or off. Gives on is "giving" (the amount is set beside it); off is back on the list. */
export function wayChanges(p, id, on) {
  if (id === "gives") return on ? { stage: "giving", startDate: p.startDate ?? todayStr() } : { stage: "idea", monthlyCents: undefined };
  if (id === "prays") return { prayer: on };
  if (id === "letters") return { newsletter: on };
  return { wantsToMeet: on ? true : undefined };
}

/** "Gives €50 a month · prays", or "In your people" when nothing is set. */
export function involvement(p, money = (c) => `€${Math.round(c / 100)}`) {
  const bits = [];
  if (gives(p)) bits.push(p.monthlyCents ? `Gives ${money(p.monthlyCents)} a month` : p.oneOffCents ? `Gave ${money(p.oneOffCents)}` : "Gives");
  if (p.prayer) bits.push(bits.length ? "prays" : "Prays");
  if (p.newsletter) bits.push(bits.length ? "gets letters" : "Gets letters");
  if (p.wantsToMeet) bits.push(bits.length ? "wants to meet" : "Wants to meet");
  return bits.join(" · ") || "In your people";
}

/** A follow-up you planned yourself is due (from three days before, as on the iPhone). */
export function followUpDue(p, today = todayStr()) {
  return !!p.nextFollowUp && dayDiff(p.nextFollowUp, today) <= 3;
}

/** Gives but was never thanked. */
export function needsThanks(p) {
  return gives(p) && p.thankedAt == null;
}

/**
 * The people who need something from you, and only them: a message from hesent.me (newest first), a thank-you
 * owed, a follow-up you planned, or someone who wants to meet and has no time planned yet. Nobody is listed just
 * for being on the list.
 */
export function waitingOnYou(partners) {
  const messages = partners.filter((p) => p.replyWaiting === true)
    .sort((a, b) => (latestMessage(b)?.at ?? "").localeCompare(latestMessage(a)?.at ?? ""));
  const rest = partners.filter((p) => p.replyWaiting !== true
    && (needsThanks(p) || followUpDue(p) || (p.wantsToMeet === true && !p.nextFollowUp)))
    .sort((a, b) => (a.nextFollowUp ?? "9999").localeCompare(b.nextFollowUp ?? "9999"));
  return [...messages, ...rest];
}

/** Why someone is waiting on you, and the one button for it: reply, thanks, checkin or plan. */
export function waitingReason(p, today = todayStr()) {
  if (p.replyWaiting === true) {
    const m = latestMessage(p);
    return { action: "reply", late: true, sub: m ? `Wrote ${messageDay(m)} on hesent.me: “${m.text.replace(/\n/g, " ")}”` : "Wrote to you on hesent.me" };
  }
  if (needsThanks(p)) return { action: "thanks", sub: `${involvement(p)}, not thanked yet` };
  if (followUpDue(p, today)) {
    const d = dayDiff(p.nextFollowUp, today);
    const when = d < 0 ? `was due ${whenLabel(p.nextFollowUp, today).replace(" late", " ago")}` : d === 0 ? "today" : whenLabel(p.nextFollowUp, today).toLowerCase();
    return { action: "checkin", late: d < 0, sub: `${p.nextStep || "Follow up"} · ${when}` };
  }
  return { action: "plan", sub: "Would like to meet. Pick a time." };
}

// ---------- messages from hesent.me (data.siteMessages and data.replyWaiting, written by the server) ----------

/** The next step the server sets with a message from hesent.me. */
export const REPLY_STEP = "Reply to their message from hesent.me";

/** Their newest message from hesent.me, or null. */
export function latestMessage(p) {
  return (Array.isArray(p.siteMessages) ? p.siteMessages : []).find((m) => m && typeof m.text === "string" && m.text) ?? null;
}

/** "today", "yesterday", "3 Nov". */
export function messageDay(m) {
  const day = String(m.at).slice(0, 10);
  if (day === todayStr()) return "today";
  if (day === addDays(todayStr(), -1)) return "yesterday";
  return new Date(m.at).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}

/** An email back, in the language they wrote in, with their newest message quoted. */
export function replyMailto(p) {
  if (!p.email) return null;
  const m = latestMessage(p);
  if (!m) return `mailto:${p.email}`;
  const en = m.lang === "en";
  const first = (m.name || p.name || "").split(/\s+/)[0];
  const quote = m.text.split("\n").map((l) => `> ${l}`).join("\n");
  const body = `${en ? "Hi" : "Hoi"} ${first},\n\n\n\n${en ? "You wrote on hesent.me" : "Je schreef op hesent.me"}:\n${quote}`;
  const subject = en ? "Your message on hesent.me" : "Je bericht op hesent.me";
  return `mailto:${p.email}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
}

/** The message is answered: no longer waiting on you, and the reply follow-up the server set goes. */
export function markAnswered(p) {
  const changes = { replyWaiting: undefined, lastContactAt: todayStr() };
  if (p.nextStep === REPLY_STEP) Object.assign(changes, { nextStep: undefined, nextFollowUp: undefined });
  return patch("partners", p.id, changes);
}

export function initials(name = "") {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join("") || "?";
}

export function weekFrom(today = todayStr()) {
  return addDays(today, 7);
}
