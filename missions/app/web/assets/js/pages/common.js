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

/** The partner stages in the order of the stage path (the Partner page). */
export const PATH = [
  { stage: "idea", label: "List" },
  { stage: "to-ask", label: "Ask" },
  { stage: "asked", label: "Asked" },
  { stage: "thinking", label: "Thinking" },
  { stage: "committed", label: "Yes" },
  { stage: "giving", label: "Giving" },
];

export const STAGE_LABEL = {
  idea: "On the list", "to-ask": "To ask", asked: "Asked", thinking: "Thinking about it",
  committed: "Committed", giving: "Giving", declined: "Declined", paused: "Not now",
};

/** The index on the path for a stage (-1 when it is off the path, e.g. declined). */
export function pathIndex(stage) {
  return PATH.findIndex((p) => p.stage === stage);
}

/** Partners who need a step from you: ask them, check in, or thank them. */
/** People with a message from hesent.me come first, whatever their stage; newest message first. */
export function waitingOnYou(partners) {
  const today = todayStr();
  const messages = partners.filter((p) => p.replyWaiting === true)
    .sort((a, b) => (latestMessage(b)?.at ?? "").localeCompare(latestMessage(a)?.at ?? ""));
  const rest = partners.filter((p) => p.replyWaiting !== true && (["to-ask", "asked", "thinking"].includes(p.stage)
    || (p.stage === "giving" && p.thankedAt == null && p.lastContactAt !== today)))
    .sort((a, b) => (a.lastContactAt ?? "").localeCompare(b.lastContactAt ?? ""));
  return [...messages, ...rest];
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
