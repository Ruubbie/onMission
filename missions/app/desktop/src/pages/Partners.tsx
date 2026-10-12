import { useState } from "react";
import { Gift as GiftIcon, HeartHandshake } from "lucide-react";
import { AddButton, Badge, Button, Chip, ChipFilter, EmptyState, Progress, SearchField, SectionHeader } from "../ui";
import { get, list, settings, useStore } from "../data/store";
import { STAGES, type Gift, type Partner, type Rec } from "../data/types";
import { label, money, shortDate, today } from "../data/format";
import type { Accent } from "../design/brand";
import { PageHead, RecordSheet, useOpenFromNav, type FieldGroup } from "./common";
import { CsvButton, DataTable, type Col } from "./table";

const stageAccent: Record<string, Accent> = { idea: "grey", "to-ask": "sand", asked: "yellow", thinking: "yellow", committed: "lime", giving: "green", declined: "grey", paused: "grey" };

export const committedMonthly = () =>
  list<Partner>("partners").filter((p) => p.data.stage === "committed" || p.data.stage === "giving").reduce((s, p) => s + (p.data.monthlyCents ?? 0), 0);

const partnerFields: FieldGroup[] = [
  { fields: [{ key: "name", label: "Name", kind: "text" }, { key: "stage", label: "Stage", kind: "select", options: STAGES },
    { key: "monthlyCents", label: "Monthly (€)", kind: "money" }, { key: "oneOffCents", label: "One-off (€)", kind: "money" }, { key: "startDate", label: "Starts", kind: "date" }] },
  { title: "Contact", fields: [{ key: "email", label: "Email", kind: "text" }, { key: "phone", label: "Phone", kind: "text" }, { key: "church", label: "Church", kind: "text" },
    { key: "prayer", label: "Prays for you", kind: "bool" }, { key: "newsletter", label: "Gets newsletter", kind: "bool" }] },
  { title: "Follow-up", fields: [{ key: "lastContactAt", label: "Last contact", kind: "date" }, { key: "nextFollowUp", label: "Next follow-up", kind: "date" },
    { key: "thankedAt", label: "Thanked", kind: "date" }, { key: "notes", label: "Conversation log", kind: "long" }] },
];
const giftFields: FieldGroup[] = [{ fields: [{ key: "partnerId", label: "From", kind: "ref", collection: "partners" }, { key: "amountCents", label: "Amount (€)", kind: "money" },
  { key: "date", label: "Date", kind: "date" }, { key: "recurring", label: "Recurring", kind: "bool" }, { key: "via", label: "Via", kind: "text" },
  { key: "thankedAt", label: "Thanked", kind: "date" }, { key: "notes", label: "Notes", kind: "long" }] }];

export default function Partners() {
  useStore();
  const [editing, setEditing] = useOpenFromNav<Partner>("partners");
  const [gift, setGift] = useState<Rec<Gift> | "new" | null>(null);
  const [stage, setStage] = useState<(typeof STAGES)[number] | null>(null);
  const [q, setQ] = useState("");
  const s = settings().data;
  const target = s.supportTargetMonthlyCents ?? 100000;
  const committed = committedMonthly();
  const all = list<Partner>("partners");
  const rows = all.filter((p) => !stage || p.data.stage === stage)
    .filter((p) => !q || JSON.stringify(p.data).toLowerCase().includes(q.toLowerCase()))
    .sort((a, b) => a.data.name.localeCompare(b.data.name));
  const gifts = list<Gift>("gifts").sort((a, b) => b.data.date.localeCompare(a.data.date));
  const toThank = gifts.filter((g) => !g.data.thankedAt).length;

  const cols: Col<Partner>[] = [
    { head: "Name", cell: (r) => <b>{r.data.name}</b>, csv: (r) => r.data.name },
    { head: "Stage", cell: (r) => <Chip accent={stageAccent[r.data.stage]} selected>{label(r.data.stage)}</Chip>, csv: (r) => r.data.stage },
    { head: "Monthly", cell: (r) => (r.data.monthlyCents ? money(r.data.monthlyCents) : ""), csv: (r) => (r.data.monthlyCents ?? 0) / 100, align: "right" },
    { head: "Church", cell: (r) => r.data.church ?? "" },
    { head: "Follow up", cell: (r) => (r.data.nextFollowUp ? (r.data.nextFollowUp < today() ? <Badge>{shortDate(r.data.nextFollowUp)}</Badge> : shortDate(r.data.nextFollowUp)) : ""), csv: (r) => r.data.nextFollowUp },
    { head: "Email", cell: (r) => r.data.email ?? "" },
  ];

  return (
    <>
      <PageHead title="Partners"><CsvButton name="partners" cols={cols} rows={rows} /></PageHead>
      <div className="box card stack" style={{ gap: 8, marginBottom: 20 }}>
        <div className="row"><span className="bold grow">Committed each month</span><span className="num bold">{money(committed)} of {money(target)}</span></div>
        <Progress value={committed / target} accent="pink" />
        <div className="row wrap caption muted">
          {STAGES.map((st) => { const n = all.filter((p) => p.data.stage === st).length; return n ? <span key={st}>{label(st)} {n}</span> : null; })}
        </div>
      </div>
      <div className="row wrap" style={{ gap: 12, marginBottom: 12 }}>
        <SearchField value={q} onChange={setQ} placeholder="Search partners" />
        <ChipFilter value={stage} options={STAGES} onChange={setStage} accent="pink" all="All" label={label} />
      </div>
      <DataTable cols={cols} rows={rows} onOpen={setEditing}
        empty={<EmptyState accent="pink" icon={<HeartHandshake size={30} strokeWidth={2.5} />} title="No partners yet" message="Add the people you want to ask, then move them through the stages." />} />

      <SectionHeader title="Gifts received" count={toThank ? <Badge>{toThank} to thank</Badge> : gifts.length} accent="pink" />
      <div className="row" style={{ marginBottom: 8 }}><Button compact variant="secondary" onClick={() => setGift("new")}><GiftIcon size={14} strokeWidth={3} />Add gift</Button></div>
      {gifts.map((g) => (
        <div key={g.id} className="lrow click" onClick={() => setGift(g)}>
          <span className="bold grow">{get<Partner>(g.data.partnerId)?.data.name ?? "Unknown"}</span>
          <span className="caption muted">{shortDate(g.data.date)}{g.data.recurring ? " · monthly" : ""}</span>
          {!g.data.thankedAt && <Badge>thank</Badge>}
          <span className="num bold">{money(g.data.amountCents, g.data.currency)}</span>
        </div>
      ))}
      <AddButton title="Add partner" onClick={() => setEditing("new")} />
      {editing && <RecordSheet title="Partner" collection="partners" rec={editing} defaults={{ stage: "idea", currency: "EUR" }} groups={partnerFields} onClose={() => setEditing(null)} />}
      {gift && <RecordSheet title="Gift" collection="gifts" rec={gift} defaults={{ currency: "EUR", date: today(), amountCents: 0 }} groups={giftFields} onClose={() => setGift(null)} />}
    </>
  );
}
