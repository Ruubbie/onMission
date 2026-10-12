import { useRef, useState } from "react";
import { FileText, FolderLock, Paperclip, Upload } from "lucide-react";
import { AccentSquare, AddButton, Badge, Button, Chip, EmptyState, FormSection, SearchField } from "../ui";
import { addFile, list, openFile, put, useStore } from "../data/store";
import { DOC_KINDS, type Doc } from "../data/types";
import { daysUntil, label, shortDate } from "../data/format";
import { showBlobUrl } from "../platform";
import { PageHead, RecordSheet, useNav, useOpenFromNav } from "./common";

async function show(fileId: string, fileName: string | undefined, toast: (t: string) => void) {
  try { showBlobUrl(await openFile(fileId), fileName); } catch (e) { toast(e instanceof Error ? e.message : "Could not open the file"); }
}

export default function Documents() {
  useStore();
  const { toast } = useNav();
  const [editing, setEditing] = useOpenFromNav<Doc>("documents");
  const [q, setQ] = useState("");
  const [drag, setDrag] = useState(false);
  const all = list<Doc>("documents").filter((d) => !q || JSON.stringify(d.data).toLowerCase().includes(q.toLowerCase()))
    .sort((a, b) => (a.data.order ?? 99) - (b.data.order ?? 99) || a.data.title.localeCompare(b.data.title));

  const onDrop = async (files: FileList) => {
    for (const f of Array.from(files)) {
      put<Doc>("documents", { title: f.name.replace(/\.[^.]+$/, ""), kind: "other", offline: true, ...(await addFile(f)) });
    }
    toast(`Added ${files.length} file${files.length > 1 ? "s" : ""} to the vault`);
  };

  return (
    <div onDragOver={(e) => { e.preventDefault(); setDrag(true); }} onDragLeave={() => setDrag(false)}
      onDrop={(e) => { e.preventDefault(); setDrag(false); void onDrop(e.dataTransfer.files); }}>
      <PageHead title="Documents" />
      <div className="row" style={{ marginBottom: 12 }}><SearchField value={q} onChange={setQ} placeholder="Search documents" /></div>
      <div className="box card row caption" style={{ marginBottom: 16, borderStyle: "dashed", background: drag ? "var(--soft-yellow)" : undefined, boxShadow: "none" }}>
        <Upload size={18} strokeWidth={3} /> Drop files anywhere on this page to keep them safe. They open even offline.
      </div>
      {all.map((d) => {
        const left = daysUntil(d.data.expiresAt);
        return (
          <div key={d.id} className="lrow click" onClick={() => setEditing(d)}>
            <AccentSquare accent="purple" icon={<FileText size={16} strokeWidth={2.5} />} size={34} />
            <div className="grow">
              <div className="bold">{d.data.title}</div>
              <div className="caption muted">{label(d.data.kind)}{d.data.expiresAt ? ` · expires ${shortDate(d.data.expiresAt)}` : ""}{d.data.notes ? ` · ${d.data.notes}` : ""}</div>
            </div>
            {left !== undefined && left < 180 && <Badge>{left < 0 ? "expired" : `${left} days left`}</Badge>}
            {d.data.fileId ? <Button compact variant="secondary" onClick={(e) => { e.stopPropagation(); void show(d.data.fileId!, d.data.fileName, toast); }}><Paperclip size={14} strokeWidth={3} />Open</Button>
              : <Chip>No file yet</Chip>}
          </div>
        );
      })}
      {!all.length && <EmptyState accent="purple" icon={<FolderLock size={30} strokeWidth={2.5} />} title="The vault is empty" message="Drop your passport scan, tickets and insurance papers here." />}
      <AddButton title="Add document" onClick={() => setEditing("new")} />
      {editing && <RecordSheet title="Document" collection="documents" rec={editing} defaults={{ kind: "other", offline: true }} onClose={() => setEditing(null)}
        groups={[{ fields: [{ key: "title", label: "Title", kind: "text" }, { key: "kind", label: "Kind", kind: "select", options: DOC_KINDS },
          { key: "number", label: "Number", kind: "text" }, { key: "issuedAt", label: "Issued", kind: "date" }, { key: "expiresAt", label: "Expires", kind: "date" },
          { key: "offline", label: "Keep offline", kind: "bool" }, { key: "notes", label: "Notes", kind: "long" }] }]}
        extra={(draft, merge) => <FileSection draft={draft} merge={merge} />} />}
    </div>
  );
}

function FileSection({ draft, merge }: { draft: Record<string, unknown>; merge: (p: Record<string, unknown>) => void }) {
  const input = useRef<HTMLInputElement>(null);
  const { toast } = useNav();
  const fileId = draft.fileId as string | undefined;
  return (
    <FormSection title="File" footer="Stored on this computer and uploaded to your account when you are logged in.">
      <div className="frow">
        <span className="grow ellipsis">{(draft.fileName as string) ?? <span className="muted">No file attached</span>}</span>
        {fileId && <Button compact variant="secondary" onClick={() => void show(fileId, draft.fileName as string | undefined, toast)}>Open</Button>}
        <Button compact onClick={() => input.current?.click()}>{fileId ? "Replace" : "Attach"}</Button>
        <input ref={input} type="file" hidden onChange={async (e) => { const f = e.target.files?.[0]; if (f) merge(await addFile(f)); }} />
      </div>
    </FormSection>
  );
}
