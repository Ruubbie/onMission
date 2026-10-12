import { useState } from "react";
import { ExternalLink, Tag } from "lucide-react";
import { AddButton, Chip, ChipFilter, EmptyState, SearchField } from "../ui";
import { list, useStore } from "../data/store";
import { SELL_STATUS, type SellItem } from "../data/types";
import { label, money, shortDate } from "../data/format";
import { PageHead, RecordSheet, useOpenFromNav } from "./common";
import { CsvButton, DataTable, type Col } from "./table";

export default function Selling() {
  useStore();
  const [editing, setEditing] = useOpenFromNav<SellItem>("sellItems");
  const [status, setStatus] = useState<(typeof SELL_STATUS)[number] | null>(null);
  const [q, setQ] = useState("");
  const all = list<SellItem>("sellItems");
  const rows = all.filter((s) => !status || s.data.status === status).filter((s) => !q || JSON.stringify(s.data).toLowerCase().includes(q.toLowerCase()))
    .sort((a, b) => SELL_STATUS.indexOf(a.data.status) - SELL_STATUS.indexOf(b.data.status) || a.data.name.localeCompare(b.data.name));
  const sold = all.filter((s) => s.data.status === "sold").reduce((t, s) => t + (s.data.soldCents ?? 0), 0);
  const asking = all.filter((s) => ["to-list", "listed", "reserved"].includes(s.data.status)).reduce((t, s) => t + (s.data.askingCents ?? 0), 0);

  const cols: Col<SellItem>[] = [
    { head: "Item", cell: (r) => <b>{r.data.name}</b>, csv: (r) => r.data.name },
    { head: "Status", cell: (r) => <Chip accent={r.data.status === "sold" ? "green" : "sand"} selected>{label(r.data.status)}</Chip>, csv: (r) => r.data.status },
    { head: "Where", cell: (r) => r.data.platform ?? "" },
    { head: "Pickup", cell: (r) => shortDate(r.data.pickupDate), csv: (r) => r.data.pickupDate },
    { head: "Link", cell: (r) => (r.data.listingUrl ? <a href={r.data.listingUrl} target="_blank" rel="noreferrer" onClick={(e) => e.stopPropagation()}><ExternalLink size={16} /></a> : ""), csv: (r) => r.data.listingUrl },
    { head: "Price", cell: (r) => money(r.data.soldCents ?? r.data.askingCents), csv: (r) => (r.data.soldCents ?? r.data.askingCents ?? 0) / 100, align: "right" },
  ];

  return (
    <>
      <PageHead title="Selling"><CsvButton name="selling" cols={cols} rows={all} /></PageHead>
      <p className="muted" style={{ marginTop: -12 }}>Sold so far <b className="num">{money(sold)}</b> · still listed or to list <b className="num">{money(asking)}</b></p>
      <div className="row wrap" style={{ gap: 12, marginBottom: 12 }}>
        <SearchField value={q} onChange={setQ} placeholder="Search items" />
        <ChipFilter value={status} options={SELL_STATUS} onChange={setStatus} accent="sand" all="All" label={label} />
      </div>
      <DataTable cols={cols} rows={rows} onOpen={setEditing} empty={<EmptyState accent="sand" icon={<Tag size={30} strokeWidth={2.5} />} title="Nothing to sell yet" message="Walk through your room and add what can go." />} />
      <AddButton title="Add item" onClick={() => setEditing("new")} />
      {editing && <RecordSheet title="Item" collection="sellItems" rec={editing} defaults={{ status: "decide", currency: "EUR", platform: "Marktplaats" }} onClose={() => setEditing(null)}
        groups={[{ fields: [{ key: "name", label: "Item", kind: "text" }, { key: "status", label: "Status", kind: "select", options: SELL_STATUS },
          { key: "askingCents", label: "Asking (€)", kind: "money" }, { key: "soldCents", label: "Sold for (€)", kind: "money" }, { key: "platform", label: "Platform", kind: "text" },
          { key: "listingUrl", label: "Listing link", kind: "url" }, { key: "buyer", label: "Buyer", kind: "text" }, { key: "pickupDate", label: "Pickup", kind: "date" },
          { key: "location", label: "Where it is", kind: "text" }, { key: "notes", label: "Notes", kind: "long" }] }]} />}
    </>
  );
}
