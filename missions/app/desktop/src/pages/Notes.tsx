import { useState } from "react";
import { NotebookPen, Pin } from "lucide-react";
import { marked } from "marked";
import { AddButton, Chip, ChipFilter, EmptyState, SearchField } from "../ui";
import { list, useStore } from "../data/store";
import { AREAS, NOTE_KINDS, type Note } from "../data/types";
import { label, shortDate } from "../data/format";
import { LinkChips, PageHead, RecordSheet, useOpenFromNav } from "./common";

export default function Notes() {
  useStore();
  const [editing, setEditing] = useOpenFromNav<Note>("notes");
  const [kind, setKind] = useState<(typeof NOTE_KINDS)[number] | null>(null);
  const [q, setQ] = useState("");
  const all = list<Note>("notes").filter((n) => !kind || (n.data.kind ?? "note") === kind)
    .filter((n) => !q || (n.data.title + (n.data.body ?? "")).toLowerCase().includes(q.toLowerCase()))
    .sort((a, b) => Number(!!b.data.pinned) - Number(!!a.data.pinned) || b.updatedAt.localeCompare(a.updatedAt));

  return (
    <>
      <PageHead title="Notes" />
      <div className="row wrap" style={{ gap: 12, marginBottom: 16 }}>
        <SearchField value={q} onChange={setQ} placeholder="Search notes" />
        <ChipFilter value={kind} options={NOTE_KINDS} onChange={setKind} accent="sand" all="All" label={label} />
      </div>
      <div className="grid">
        {all.map((n) => (
          <div key={n.id} className="box card press stack" style={{ gap: 8 }} onClick={() => setEditing(n)}>
            <div className="row"><b className="grow">{n.data.title}</b>{n.data.pinned && <Pin size={16} strokeWidth={3} />}</div>
            <div className="md caption" style={{ maxHeight: 120, overflow: "hidden" }} dangerouslySetInnerHTML={{ __html: marked.parse(n.data.body ?? "", { async: false }) }} />
            <div className="row wrap">
              <Chip accent={n.data.kind === "prayer" ? "purple" : "sand"} selected>{label(n.data.kind ?? "note")}</Chip>
              {n.data.answeredAt && <Chip accent="green" selected>Answered {shortDate(n.data.answeredAt)}</Chip>}
              <span className="caption muted grow" style={{ textAlign: "right" }}>{shortDate(n.updatedAt)}</span>
            </div>
            <LinkChips links={n.data.links} />
          </div>
        ))}
      </div>
      {!all.length && <EmptyState accent="sand" icon={<NotebookPen size={30} strokeWidth={2.5} />} title="No notes yet" message="Prayer requests, meetings, ideas: write them down with the + button." />}
      <AddButton title="Add note" onClick={() => setEditing("new")} />
      {editing && <RecordSheet title="Note" collection="notes" rec={editing} defaults={{ kind: kind ?? "note" }} onClose={() => setEditing(null)}
        groups={[{ fields: [{ key: "title", label: "Title", kind: "text" }, { key: "kind", label: "Kind", kind: "select", options: NOTE_KINDS },
          { key: "area", label: "Area", kind: "select", options: AREAS, empty: "None" }, { key: "pinned", label: "Pinned", kind: "bool" },
          { key: "answeredAt", label: "Answered", kind: "date" }, { key: "body", label: "Text (Markdown)", kind: "long" }] }]} />}
    </>
  );
}
