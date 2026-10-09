import { useState } from "react";
import { ListChecks, Pencil, Plus, ExternalLink } from "lucide-react";
import { AddButton, Button, EmptyState, FolderCard, IconButton, QuickAdd, SearchField, Segmented } from "../ui";
import { get, list, put, useStore } from "../data/store";
import { AREAS, PHASES, type Checklist, type Rec, type Task } from "../data/types";
import { areaAccent } from "../design/brand";
import { PageHead, RecordSheet, useNav } from "./common";
import { isLate, isOpen, sortTasks, TaskRow, TaskSheet, tasks } from "./tasks";

const SHOW = ["Open", "All", "Done"] as const;

export default function Checklists() {
  useStore();
  const { openId } = useNav();
  const opened = get(openId);
  const [sel, setSel] = useState<string | null>(opened?.collection === "checklists" ? opened.id : opened?.collection === "tasks" ? ((opened.data as Task).checklistId ?? null) : null);
  const [task, setTask] = useState<Rec<Task> | "new" | null>(opened?.collection === "tasks" ? (opened as Rec<Task>) : null);
  const [cl, setCl] = useState<Rec<Checklist> | "new" | null>(null);
  const [show, setShow] = useState<(typeof SHOW)[number]>("Open");
  const [q, setQ] = useState("");

  const lists = list<Checklist>("checklists").filter((c) => !c.data.archived).sort((a, b) => (a.data.order ?? 0) - (b.data.order ?? 0));
  const all = tasks();
  const current = get<Checklist>(sel ?? undefined);
  const shown = all
    .filter((t) => !sel || t.data.checklistId === sel)
    .filter((t) => show === "All" || (show === "Open") === isOpen(t.data))
    .filter((t) => !q || (t.data.title + " " + (t.data.notes ?? "")).toLowerCase().includes(q.toLowerCase()))
    .sort(sortTasks);

  return (
    <>
      <PageHead title={current?.data.title ?? "All tasks"}>
        {current && <IconButton icon={<Pencil size={16} strokeWidth={3} />} onClick={() => setCl(current)} title="Edit checklist" />}
        <Button variant="secondary" onClick={() => setCl("new")}><Plus size={16} strokeWidth={3} />Checklist</Button>
      </PageHead>
      <div className="split">
        <div className="stack" style={{ gap: 18 }}>
          <FolderCard title="All tasks" accent="yellow" icon={<ListChecks size={18} strokeWidth={2.5} />} count={all.filter((t) => isOpen(t.data)).length}
            subtitle="open" selected={!sel} onClick={() => setSel(null)} />
          {lists.map((c) => {
            const ts = all.filter((t) => t.data.checklistId === c.id);
            const open = ts.filter((t) => isOpen(t.data)).length;
            const late = ts.filter((t) => isLate(t.data)).length;
            return <FolderCard key={c.id} title={c.data.title} accent={areaAccent[c.data.area ?? "other"] ?? "lime"} icon={<ListChecks size={18} strokeWidth={2.5} />}
              count={open} subtitle={`${ts.length - open} of ${ts.length} done`} badge={late ? `${late} late` : undefined}
              progress={ts.length ? (ts.length - open) / ts.length : 0} selected={sel === c.id} onClick={() => setSel(c.id)} />;
          })}
        </div>
        <div>
          {current?.data.description && <p className="muted" style={{ marginTop: 0 }}>{current.data.description}</p>}
          <div className="row wrap" style={{ gap: 12, marginBottom: 12 }}>
            <SearchField value={q} onChange={setQ} placeholder="Search tasks" />
            <Segmented value={show} options={SHOW} onChange={setShow} />
          </div>
          <QuickAdd placeholder={`Add a task${current ? ` to ${current.data.title}` : ""}`} onAdd={(title) => put<Task>("tasks", { title, status: "todo", priority: "normal", checklistId: sel ?? undefined, area: current?.data.area })} />
          <div style={{ marginTop: 8 }}>
            {shown.map((r) => <TaskRow key={r.id} r={r} showList={!sel} onOpen={() => setTask(r)} />)}
            {!shown.length && <EmptyState accent="lime" icon={<ListChecks size={30} strokeWidth={2.5} />} title={show === "Open" ? "All done here" : "No tasks"} message="Type above to add one." />}
          </div>
          {current && all.some((t) => t.data.checklistId === sel && t.data.sourceUrl) && (
            <p className="caption muted row"><ExternalLink size={14} /> Tasks with an official page: re-check it before acting, rules change.</p>
          )}
        </div>
      </div>
      <AddButton title="Add task" onClick={() => setTask("new")} />
      {task && <TaskSheet rec={task} defaults={{ checklistId: sel ?? undefined, area: current?.data.area }} onClose={() => setTask(null)} />}
      {cl && <RecordSheet title="Checklist" collection="checklists" rec={cl} defaults={{ order: lists.length + 1 }} onClose={() => setCl(null)}
        groups={[{ fields: [{ key: "title", label: "Title", kind: "text" }, { key: "area", label: "Area", kind: "select", options: AREAS, empty: "None" },
          { key: "phase", label: "When", kind: "select", options: PHASES, empty: "Any time" }, { key: "description", label: "Description", kind: "long" },
          { key: "archived", label: "Archived", kind: "bool" }] }]} />}
    </>
  );
}
