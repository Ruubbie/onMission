// Task row + task editor, used on Home and Checklists.
import { Badge, CheckBox, Chip } from "../ui";
import { get, list, patch } from "../data/store";
import { AREAS, PRIORITY, TASK_STATUS, type Checklist, type Rec, type Task } from "../data/types";
import { daysUntil, shortDate, today } from "../data/format";
import { areaAccent } from "../design/brand";
import { LinkChips, RecordSheet, type FieldGroup } from "./common";

export const isOpen = (t: Task) => t.status !== "done" && t.status !== "skipped";
export const isLate = (t: Task) => isOpen(t) && !!t.dueDate && t.dueDate < today();

export function setDone(r: Rec<Task>, done: boolean) {
  patch(r, done ? { status: "done", completedAt: new Date().toISOString() } : { status: "todo", completedAt: undefined });
}

export function TaskRow({ r, onOpen, showList }: { r: Rec<Task>; onOpen: () => void; showList?: boolean }) {
  const t = r.data;
  const done = !isOpen(t);
  const d = daysUntil(t.dueDate);
  const cl = showList ? get<Checklist>(t.checklistId) : undefined;
  return (
    <div className="lrow click" onClick={onOpen}>
      <CheckBox checked={t.status === "done"} onChange={(v) => setDone(r, v)} label="Done" />
      <div className="grow">
        <div className={done ? "strike" : "bold"}>{t.title}</div>
        {(cl || t.waitingOn || t.links?.length) && (
          <div className="row wrap caption muted" style={{ marginTop: 2 }}>
            {cl && <span>{cl.data.title}</span>}
            {t.status === "waiting" && t.waitingOn && <span>Waiting on {t.waitingOn}</span>}
            <LinkChips links={t.links} />
          </div>
        )}
      </div>
      {t.priority === "high" && !done && <Chip accent="pink" selected>High</Chip>}
      {t.area && <span className="wide-only"><Chip accent={areaAccent[t.area]} selected>{t.area}</Chip></span>}
      {t.dueDate && <span className="caption num" style={{ whiteSpace: "nowrap" }}>{isLate(t) ? <Badge>{shortDate(t.dueDate)}</Badge> : d === 0 ? <b>Today</b> : shortDate(t.dueDate)}</span>}
    </div>
  );
}

const groups = (): FieldGroup[] => [
  { fields: [{ key: "title", label: "Title", kind: "text" }, { key: "status", label: "Status", kind: "select", options: TASK_STATUS },
    { key: "priority", label: "Priority", kind: "select", options: PRIORITY }, { key: "dueDate", label: "Due", kind: "date" },
    { key: "checklistId", label: "Checklist", kind: "ref", collection: "checklists" }, { key: "area", label: "Area", kind: "select", options: AREAS, empty: "None" }] },
  { fields: [{ key: "waitingOn", label: "Waiting on", kind: "text" }, { key: "sourceUrl", label: "Official page", kind: "url" }, { key: "notes", label: "Notes", kind: "long" }] },
];

export function TaskSheet({ rec, defaults, onClose }: { rec: Rec<Task> | "new"; defaults?: Partial<Task>; onClose: () => void }) {
  return <RecordSheet title="Task" collection="tasks" rec={rec} defaults={{ status: "todo", priority: "normal", ...defaults }} groups={groups()} onClose={onClose} />;
}

export const sortTasks = (a: Rec<Task>, b: Rec<Task>) =>
  Number(!isOpen(a.data)) - Number(!isOpen(b.data)) || (a.data.dueDate ?? "9999").localeCompare(b.data.dueDate ?? "9999") || (a.data.order ?? 0) - (b.data.order ?? 0);

export const tasks = () => list<Task>("tasks");
