import { useState } from "react";
import { FolderLock, HeartHandshake, ListChecks, Luggage, Mail, NotebookPen, Plane, Tag, Wallet } from "lucide-react";
import { AccentSquare, Button, FolderCard, Progress, QuickAdd, SectionHeader } from "../ui";
import { list, put, settings, useStore } from "../data/store";
import type { Checklist, Doc, Newsletter, Note, PackingItem, Partner, Rec, SellItem, Task } from "../data/types";
import { daysUntil, money, shortDate, today } from "../data/format";
import { areaAccent } from "../design/brand";
import { PageHead, useNav } from "./common";
import { isLate, isOpen, sortTasks, TaskRow, TaskSheet, tasks } from "./tasks";
import { committedMonthly } from "./Partners";

const icon = (C: typeof Plane) => <C size={18} strokeWidth={2.5} />;

export default function Home() {
  useStore();
  const { go } = useNav();
  const [editing, setEditing] = useState<Rec<Task> | null>(null);
  const s = settings().data;
  const days = daysUntil(s.departureDate);
  const all = tasks();
  const soon = all.filter((r) => isOpen(r.data) && r.data.dueDate && r.data.dueDate <= addDays(7)).sort(sortTasks);
  const late = all.filter((r) => isLate(r.data)).length;
  const checklists = list<Checklist>("checklists").filter((c) => !c.data.archived).sort((a, b) => (a.data.order ?? 0) - (b.data.order ?? 0));
  const target = s.supportTargetMonthlyCents ?? 100000;
  const committed = committedMonthly();
  const docs = list<Doc>("documents");
  const expiring = docs.filter((d) => { const n = daysUntil(d.data.expiresAt); return n !== undefined && n < 180; }).length;
  const sell = list<SellItem>("sellItems");
  const pack = list<PackingItem>("packing");
  const news = list<Newsletter>("newsletters");
  const notes = list<Note>("notes");

  return (
    <>
      <PageHead title={days !== undefined && days > 0 ? `${days} days to Queenstown` : "Queenstown"} />
      <div className="row wrap" style={{ gap: 16, alignItems: "stretch" }}>
        <div className="box card row grow" style={{ minWidth: 280 }}>
          <AccentSquare accent="yellow" icon={icon(Plane)} />
          <div className="grow">
            <div className="bold">Departure {shortDate(s.departureDate)}</div>
            <div className="caption muted">{late ? `${late} late, ` : ""}{all.filter((r) => isOpen(r.data)).length} open tasks</div>
          </div>
        </div>
        <div className="box card stack grow" style={{ minWidth: 280, gap: 8 }}>
          <div className="row"><span className="bold grow">Monthly support</span><span className="num bold">{money(committed)} / {money(target)}</span></div>
          <Progress value={committed / target} accent="pink" />
          <div className="caption muted">Minimum {money(s.supportMinimumMonthlyCents ?? 75000)}</div>
        </div>
      </div>

      <SectionHeader title="This week" count={soon.length} accent="yellow" />
      <QuickAdd placeholder="Add a task and press Enter" onAdd={(title) => put<Task>("tasks", { title, status: "todo", priority: "normal", dueDate: today() })} />
      <div style={{ marginTop: 8 }}>
        {soon.slice(0, 8).map((r) => <TaskRow key={r.id} r={r} showList onOpen={() => setEditing(r)} />)}
        {!soon.length && <p className="muted">Nothing due this week.</p>}
        {soon.length > 8 && <Button variant="secondary" compact onClick={() => go("checklists")}>Show all {soon.length}</Button>}
      </div>

      <SectionHeader title="Checklists" count={checklists.length} accent="lime" />
      <div className="grid">
        {checklists.map((c) => {
          const ts = all.filter((t) => t.data.checklistId === c.id);
          const open = ts.filter((t) => isOpen(t.data)).length;
          const lateN = ts.filter((t) => isLate(t.data)).length;
          return <FolderCard key={c.id} title={c.data.title} accent={areaAccent[c.data.area ?? "other"] ?? "lime"} icon={icon(ListChecks)} count={open}
            subtitle={`${ts.length - open} of ${ts.length} done`} badge={lateN ? `${lateN} late` : undefined} progress={ts.length ? (ts.length - open) / ts.length : 0} onClick={() => go("checklists", c.id)} />;
        })}
      </div>

      <SectionHeader title="Everything else" accent="sand" />
      <div className="grid">
        <FolderCard title="Partners" accent="pink" icon={icon(HeartHandshake)} count={list<Partner>("partners").length} subtitle={`${money(committed)} a month committed`} onClick={() => go("partners")} />
        <FolderCard title="Budget" accent="green" icon={icon(Wallet)} count={money(target - committed)} subtitle="still to raise each month" onClick={() => go("budget")} />
        <FolderCard title="Documents" accent="purple" icon={icon(FolderLock)} count={docs.length} subtitle="in the vault" badge={expiring ? `${expiring} expiring` : undefined} onClick={() => go("documents")} />
        <FolderCard title="Selling" accent="sand" icon={icon(Tag)} count={sell.filter((x) => !["sold", "given-away", "keep", "store"].includes(x.data.status)).length} subtitle="still to sell or decide" onClick={() => go("selling")} />
        <FolderCard title="Packing" accent="lime" icon={icon(Luggage)} count={`${pack.filter((p) => p.data.packed).length}/${pack.length}`} subtitle="packed" progress={pack.length ? pack.filter((p) => p.data.packed).length / pack.length : 0} onClick={() => go("packing")} />
        <FolderCard title="Newsletter" accent="pink" icon={icon(Mail)} count={news.length} subtitle={`${news.filter((n) => n.data.status === "sent").length} sent`} onClick={() => go("newsletter")} />
        <FolderCard title="Notes" accent="sand" icon={icon(NotebookPen)} count={notes.length} subtitle={`${notes.filter((n) => n.data.kind === "prayer").length} prayer notes`} onClick={() => go("notes")} />
      </div>
      {editing && <TaskSheet rec={editing} onClose={() => setEditing(null)} />}
    </>
  );
}

function addDays(n: number) { const d = new Date(); d.setDate(d.getDate() + n); return d.toISOString().slice(0, 10); }
