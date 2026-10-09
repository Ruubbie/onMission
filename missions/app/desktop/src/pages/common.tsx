// App-level helpers shared by the pages: navigation, the generic record editor, link chips, toasts.
import { createContext, useContext, useState, type ReactNode } from "react";
import { Link2, X } from "lucide-react";
import { Button, Chip, DateField, Dialog, FormRow, FormSection, Select, Sheet, TextField, Toggle } from "../ui";
import { get, list, patch, put, remove, restore } from "../data/store";
import { COLLECTIONS, type Collection, type Link, type Rec } from "../data/types";
import { label, money, parseMoney } from "../data/format";

export type Page = "home" | "checklists" | "partners" | "budget" | "selling" | "packing" | "documents" | "notes" | "newsletter" | "contacts" | "settings";
export const pageFor: Record<Collection, Page> = {
  tasks: "checklists", checklists: "checklists", partners: "partners", gifts: "partners", budget: "budget", sellItems: "selling",
  packing: "packing", notes: "notes", documents: "documents", contacts: "contacts", newsletters: "newsletter", settings: "settings",
};

interface Nav { page: Page; openId?: string; go: (page: Page, openId?: string) => void; toast: (text: string, undo?: () => void) => void }
export const NavContext = createContext<Nav>(null!);
export const useNav = () => useContext(NavContext);

export function recTitle(r?: Rec<unknown>): string {
  if (!r) return "removed";
  const d = r.data as Record<string, unknown>;
  return String(d.title ?? d.name ?? d.label ?? d.key ?? (d.amountCents !== undefined ? money(d.amountCents as number, d.currency as string) : "Untitled"));
}

export function PageHead({ title, children }: { title: string; children?: ReactNode }) {
  return <div className="pagehead"><h1>{title}</h1>{children}</div>;
}

/** Opens the sheet for `openId` once, when the page was reached through a link chip or search. */
export function useOpenFromNav<T>(collection: Collection | Collection[]): [Rec<T> | "new" | null, (r: Rec<T> | "new" | null) => void] {
  const { openId } = useNav();
  const [editing, setEditing] = useState<Rec<T> | "new" | null>(() => {
    const r = get<T>(openId);
    return r && ([] as Collection[]).concat(collection).includes(r.collection) ? r : null;
  });
  return [editing, setEditing];
}

// ---------- Generic record editor ----------

export type Field =
  | { key: string; label: string; kind: "text" | "long" | "date" | "money" | "int" | "bool" | "url" }
  | { key: string; label: string; kind: "select"; options: readonly string[]; empty?: string }
  | { key: string; label: string; kind: "ref"; collection: Collection; empty?: string };
export interface FieldGroup { title?: string; footer?: string; fields: Field[] }

export function RecordSheet<T extends object>({ title, collection, rec, defaults, groups, onClose, extra }:
  { title: string; collection: Collection; rec: Rec<T> | "new"; defaults?: Partial<T>; groups: FieldGroup[]; onClose: () => void; extra?: (draft: Record<string, unknown>, merge: (p: Record<string, unknown>) => void) => ReactNode }) {
  const { toast } = useNav();
  const isNew = rec === "new";
  const [draft, setDraft] = useState<Record<string, unknown>>(() => (isNew ? { ...defaults } : { ...rec.data }));
  const [confirm, setConfirm] = useState(false);
  const set = (k: string, v: unknown) => setDraft((d) => { const n = { ...d, [k]: v }; if (v === undefined || v === "") delete n[k]; return n; });

  const save = () => {
    if (isNew) put(collection, draft as T); else patch(rec, draft as Partial<T>);
    onClose();
  };
  const del = () => {
    if (isNew) return;
    remove(rec); onClose();
    toast(`Deleted "${recTitle(rec as Rec)}"`, () => restore(rec));
  };

  return (
    <Sheet title={isNew ? `New ${title}` : title} onCancel={onClose} onSave={save}>
      {groups.map((g, i) => (
        <FormSection key={i} title={g.title} footer={g.footer}>
          {g.fields.map((f) => <FieldRow key={f.key} f={f} value={draft[f.key]} set={(v) => set(f.key, v)} />)}
        </FormSection>
      ))}
      {extra?.(draft, (p) => setDraft((d) => ({ ...d, ...p })))}
      <LinksEditor links={(draft.links as Link[]) ?? []} onChange={(l) => set("links", l.length ? l : undefined)} />
      {!isNew && <Button variant="danger" block onClick={() => setConfirm(true)}>Delete</Button>}
      {confirm && <Dialog title="Delete this?" message={`"${recTitle(rec as Rec)}" will be removed on all your devices.`} confirm="Delete" danger onConfirm={del} onCancel={() => setConfirm(false)} />}
    </Sheet>
  );
}

function FieldRow({ f, value, set }: { f: Field; value: unknown; set: (v: unknown) => void }) {
  switch (f.kind) {
    case "long":
      return <FormRow label={f.label} tall><TextField multiline value={(value as string) ?? ""} onChange={set} /></FormRow>;
    case "bool":
      return <FormRow label={f.label}><Toggle checked={!!value} onChange={(v) => set(v || undefined)} label={f.label} /></FormRow>;
    case "date":
      return <FormRow label={f.label}><DateField value={value as string} onChange={set} /></FormRow>;
    case "select":
      return <FormRow label={f.label}><Select value={value as string} options={f.options} onChange={(v) => set(v || undefined)} label={label} empty={f.empty} /></FormRow>;
    case "ref": {
      const opts = list(f.collection).sort((a, b) => recTitle(a).localeCompare(recTitle(b)));
      const titles = Object.fromEntries(opts.map((o) => [o.id, recTitle(o)]));
      return <FormRow label={f.label}><Select value={value as string} options={opts.map((o) => o.id)} onChange={(v) => set(v || undefined)} label={(id) => titles[id]} empty={f.empty ?? "None"} /></FormRow>;
    }
    case "money":
      return <FormRow label={f.label}><MoneyInput cents={value as number | undefined} onChange={set} /></FormRow>;
    case "int":
      return <FormRow label={f.label}><input className="bare num" inputMode="numeric" value={(value as number) ?? ""} onChange={(e) => set(e.target.value === "" ? undefined : parseInt(e.target.value) || 0)} /></FormRow>;
    default:
      return <FormRow label={f.label}><TextField bare value={(value as string) ?? ""} onChange={set} placeholder={f.kind === "url" ? "https://" : ""} /></FormRow>;
  }
}

function MoneyInput({ cents, onChange }: { cents?: number; onChange: (v?: number) => void }) {
  const [text, setText] = useState(cents === undefined ? "" : (cents / 100).toLocaleString("nl-NL"));
  return <input className="bare num" inputMode="decimal" value={text} placeholder="0" onChange={(e) => { setText(e.target.value); onChange(parseMoney(e.target.value)); }} />;
}

// ---------- Smart links ----------

export function LinkChips({ links }: { links?: Link[] }) {
  const { go } = useNav();
  if (!links?.length) return null;
  return (
    <div className="row wrap">
      {links.map((l) => {
        const r = get(l.id);
        return <Chip key={l.id} onClick={() => r && go(pageFor[l.collection], l.id)} title={l.collection}><Link2 size={12} strokeWidth={3} />{l.label ?? recTitle(r)}</Chip>;
      })}
    </div>
  );
}

function LinksEditor({ links, onChange }: { links: Link[]; onChange: (l: Link[]) => void }) {
  const [col, setCol] = useState<Collection | "">("");
  const { go } = useNav();
  const opts = col ? list(col).filter((r) => !links.some((l) => l.id === r.id)) : [];
  const titles = Object.fromEntries(opts.map((o) => [o.id, recTitle(o)]));
  return (
    <FormSection title="Links" footer="Link this to a task, document, note or anything else.">
      {links.length > 0 && (
        <div className="frow wrap">
          {links.map((l) => (
            <span key={l.id} className="chip">
              <span style={{ cursor: "pointer" }} onClick={() => go(pageFor[l.collection], l.id)}>{l.label ?? recTitle(get(l.id))}</span>
              <X size={12} strokeWidth={3} style={{ cursor: "pointer" }} onClick={() => onChange(links.filter((x) => x.id !== l.id))} aria-label="Remove link" />
            </span>
          ))}
        </div>
      )}
      <div className="frow">
        <Select value={col} options={COLLECTIONS.filter((c) => c !== "settings")} onChange={(v) => setCol(v)} label={label} empty="Link to…" />
        {col && <Select value="" options={opts.map((o) => o.id)} label={(id) => titles[id]} empty="Pick one" onChange={(id) => { if (id) { onChange([...links, { collection: col, id }]); setCol(""); } }} />}
      </div>
    </FormSection>
  );
}
