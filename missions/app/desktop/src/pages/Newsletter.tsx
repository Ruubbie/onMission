import { useState } from "react";
import { Download, Mail, Trash2 } from "lucide-react";
import { AddButton, Button, Chip, DateField, Dialog, EmptyState, IconButton, Segmented, TextField } from "../ui";
import { get, list, patch, put, remove, restore, useStore } from "../data/store";
import { NEWS_STATUS, type Newsletter as News, type Rec } from "../data/types";
import { download, label, shortDate } from "../data/format";
import { brand } from "../design/brand";
import { renderNewsletter } from "../newsletter/render";
import { PageHead, useNav } from "./common";

export default function Newsletter() {
  useStore();
  const { openId, toast } = useNav();
  const all = list<News>("newsletters").sort((a, b) => (b.data.number ?? 0) - (a.data.number ?? 0));
  const [selId, setSel] = useState<string | undefined>(get(openId)?.collection === "newsletters" ? openId : all[0]?.id);
  const [confirm, setConfirm] = useState(false);
  const sel = get<News>(selId);

  const add = () => {
    const n = Math.max(0, ...all.map((x) => x.data.number ?? 0)) + 1;
    setSel(put<News>("newsletters", { title: `Newsletter ${n}`, number: n, status: "draft", body: "Hi everyone,\n\n" }).id);
  };
  const exp = (email: boolean) => sel && download(`${slug(sel.data.title)}${email ? "-email" : ""}.html`, renderNewsletter(sel.data, { appName: brand.appName, email }), "text/html");

  return (
    <>
      <PageHead title="Newsletter">
        {sel && <>
          <Button variant="secondary" onClick={() => exp(false)}><Download size={16} strokeWidth={3} />Web page</Button>
          <Button variant="secondary" onClick={() => exp(true)}><Mail size={16} strokeWidth={3} />Email HTML</Button>
        </>}
      </PageHead>
      {!all.length && <EmptyState accent="pink" icon={<Mail size={30} strokeWidth={2.5} />} title="No newsletters yet" message="Start your first one with the + button." />}
      {all.length > 0 && (
        <div className="split" style={{ gridTemplateColumns: "240px 1fr" }}>
          <div>
            {all.map((n) => (
              <div key={n.id} className={`lrow click ${n.id === selId ? "sel" : ""}`} onClick={() => setSel(n.id)}>
                <div className="grow"><div className="bold ellipsis">{n.data.title}</div><div className="caption muted">{shortDate(n.data.plannedDate) || "No date"}</div></div>
                <Chip accent={n.data.status === "sent" ? "green" : "pink"} selected={n.data.status !== "idea"}>{label(n.data.status)}</Chip>
              </div>
            ))}
          </div>
          {sel && <Editor key={sel.id} rec={sel} onDelete={() => setConfirm(true)} />}
        </div>
      )}
      <AddButton title="New newsletter" onClick={add} />
      {confirm && sel && <Dialog title="Delete this newsletter?" confirm="Delete" danger onCancel={() => setConfirm(false)}
        onConfirm={() => { remove(sel); setConfirm(false); setSel(undefined); toast("Newsletter deleted", () => restore(sel)); }} />}
    </>
  );
}

function Editor({ rec, onDelete }: { rec: Rec<News>; onDelete: () => void }) {
  const d = rec.data;
  return (
    <div className="stack" style={{ gap: 16 }}>
      <div className="row wrap" style={{ gap: 12 }}>
        <div className="grow" style={{ minWidth: 220 }}><TextField value={d.title} onChange={(title) => patch(rec, { title })} placeholder="Title" /></div>
        <DateField value={d.plannedDate} onChange={(plannedDate) => patch(rec, { plannedDate })} />
        <IconButton icon={<Trash2 size={16} strokeWidth={3} />} onClick={onDelete} title="Delete" />
      </div>
      <Segmented value={d.status} options={NEWS_STATUS} onChange={(status) => patch(rec, { status, sentAt: status === "sent" ? new Date().toISOString() : d.sentAt })} accent="pink" label={label} />
      <div className="row" style={{ gap: 16, alignItems: "stretch", flexWrap: "wrap" }}>
        <div className="grow" style={{ minWidth: 300, flexBasis: 0 }}>
          <TextField multiline value={d.body ?? ""} onChange={(body) => patch(rec, { body })} placeholder="Write in Markdown: # heading, **bold**, ![photo](https://…)" style={{ minHeight: 520, height: "100%" }} />
        </div>
        <iframe title="Preview" className="box grow" style={{ minWidth: 300, flexBasis: 0, minHeight: 520, padding: 0, background: "var(--background)" }}
          srcDoc={renderNewsletter(d, { appName: brand.appName })} />
      </div>
    </div>
  );
}

const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "newsletter";
