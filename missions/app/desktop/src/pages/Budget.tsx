import { useState } from "react";
import { Wallet } from "lucide-react";
import { AddButton, Chip, EmptyState, Segmented } from "../ui";
import { list, settings, useStore } from "../data/store";
import { BUDGET_KIND, RECURRENCE, type BudgetEntry, type Rec } from "../data/types";
import { label, money, shortDate } from "../data/format";
import { PageHead, RecordSheet, useOpenFromNav } from "./common";
import { CsvButton, DataTable, type Col } from "./table";
import { committedMonthly } from "./Partners";

const VIEWS = ["Setup", "Monthly", "Income"] as const;

export default function Budget() {
  useStore();
  const [editing, setEditing] = useOpenFromNav<BudgetEntry>("budget");
  const [view, setView] = useState<(typeof VIEWS)[number]>("Setup");
  const rate = settings().data.nzdPerEur ?? 1.85;
  const eur = (cents: number, cur: string) => (cur === "NZD" ? Math.round(cents / rate) : cents);
  const perMonth = (b: BudgetEntry) => (b.recurrence === "yearly" ? b.amountCents / 12 : b.amountCents);
  const all = list<BudgetEntry>("budget");

  const setup = all.filter((b) => b.data.phase !== "monthly" && b.data.kind !== "income");
  const monthly = all.filter((b) => b.data.phase === "monthly" && b.data.kind !== "income");
  const income = all.filter((b) => b.data.kind === "income");
  const setupTotal = setup.reduce((s, b) => s + eur(b.data.amountCents, b.data.currency), 0);
  const monthlyCost = monthly.reduce((s, b) => s + eur(perMonth(b.data), b.data.currency), 0);
  const monthlyIn = income.filter((b) => b.data.recurrence !== "once").reduce((s, b) => s + eur(perMonth(b.data), b.data.currency), 0) + committedMonthly();
  const rows = (view === "Setup" ? setup : view === "Monthly" ? monthly : income).sort((a, b) => (a.data.date ?? "").localeCompare(b.data.date ?? ""));

  const cols: Col<BudgetEntry>[] = [
    { head: "What", cell: (r) => <b>{r.data.label}</b>, csv: (r) => r.data.label },
    { head: "Kind", cell: (r) => <Chip accent={r.data.kind === "income" ? "green" : r.data.kind === "saving" ? "purple" : "sand"} selected>{label(r.data.kind)}</Chip>, csv: (r) => r.data.kind },
    { head: "Category", cell: (r) => r.data.category ?? "" },
    { head: "When", cell: (r) => (r.data.recurrence && r.data.recurrence !== "once" ? label(r.data.recurrence) : shortDate(r.data.date)), csv: (r) => r.data.date ?? r.data.recurrence },
    { head: "Paid", cell: (r) => (r.data.paid ? "✓" : ""), csv: (r) => (r.data.paid ? "yes" : "") },
    { head: "Amount", cell: (r) => money(r.data.amountCents, r.data.currency), csv: (r) => r.data.amountCents / 100, align: "right" },
    { head: "In €", cell: (r) => money(eur(r.data.amountCents, r.data.currency)), csv: (r) => eur(r.data.amountCents, r.data.currency) / 100, align: "right" },
  ];

  const Stat = ({ title, value, note }: { title: string; value: string; note?: string }) => (
    <div className="box card grow" style={{ minWidth: 200 }}>
      <div className="caption muted">{title}</div>
      <div className="num bold" style={{ fontSize: 26 }}>{value}</div>
      {note && <div className="caption muted">{note}</div>}
    </div>
  );

  return (
    <>
      <PageHead title="Budget"><CsvButton name="budget" cols={cols} rows={all} /></PageHead>
      <div className="row wrap" style={{ gap: 16, marginBottom: 24 }}>
        <Stat title="Before leaving" value={money(setupTotal)} note={`${money(Math.round(setupTotal * rate), "NZD")}`} />
        <Stat title="Monthly costs" value={money(monthlyCost)} note={`${money(Math.round(monthlyCost * rate), "NZD")}`} />
        <Stat title="Monthly income" value={money(monthlyIn)} note="incl. committed partners" />
        <Stat title="Monthly gap" value={money(Math.max(0, monthlyCost - monthlyIn))} note={monthlyIn >= monthlyCost ? "Covered" : "still to find"} />
      </div>
      <div className="row" style={{ marginBottom: 12 }}><Segmented value={view} options={VIEWS} onChange={setView} accent="green" /><span className="caption muted">1 € = {rate} NZD (Settings)</span></div>
      <DataTable cols={cols} rows={rows} onOpen={setEditing} empty={<EmptyState accent="green" icon={<Wallet size={30} strokeWidth={2.5} />} title="Nothing here yet" message="Add a cost or income line with the + button." />} />
      <AddButton title="Add budget line" onClick={() => setEditing("new")} />
      {editing && <RecordSheet title="Budget line" collection="budget" rec={editing as Rec<BudgetEntry> | "new"} onClose={() => setEditing(null)}
        defaults={{ kind: view === "Income" ? "income" : "expense", phase: view === "Monthly" ? "monthly" : "setup", recurrence: view === "Setup" ? "once" : "monthly", currency: "EUR", amountCents: 0 }}
        groups={[{ fields: [{ key: "label", label: "What", kind: "text" }, { key: "kind", label: "Kind", kind: "select", options: BUDGET_KIND },
          { key: "amountCents", label: "Amount", kind: "money" }, { key: "currency", label: "Currency", kind: "select", options: ["EUR", "NZD"] },
          { key: "phase", label: "Phase", kind: "select", options: ["setup", "monthly"] }, { key: "recurrence", label: "Repeats", kind: "select", options: RECURRENCE },
          { key: "date", label: "Date", kind: "date" }, { key: "category", label: "Category", kind: "text" }, { key: "paid", label: "Paid", kind: "bool" },
          { key: "notes", label: "Notes", kind: "long" }] }]} />}
    </>
  );
}
