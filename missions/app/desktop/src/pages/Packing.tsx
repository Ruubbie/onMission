import { Luggage } from "lucide-react";
import { AddButton, CheckBox, EmptyState, Progress, QuickAdd, SectionHeader } from "../ui";
import { list, patch, put, useStore } from "../data/store";
import { BAGS, type PackingItem } from "../data/types";
import { label } from "../data/format";
import { PageHead, RecordSheet, useOpenFromNav } from "./common";

const LIMIT_KG: Record<string, number> = { checked: 23, "carry-on": 7 };

export default function Packing() {
  useStore();
  const [editing, setEditing] = useOpenFromNav<PackingItem>("packing");
  const all = list<PackingItem>("packing").sort((a, b) => a.data.name.localeCompare(b.data.name));
  const kg = (xs: typeof all) => xs.reduce((s, p) => s + (p.data.weightGrams ?? 0) * (p.data.quantity ?? 1), 0) / 1000;

  return (
    <>
      <PageHead title="Packing" />
      {!all.length && <EmptyState accent="lime" icon={<Luggage size={30} strokeWidth={2.5} />} title="Nothing on the list" message="Add what you will take." />}
      {BAGS.map((bag) => {
        const items = all.filter((p) => (p.data.bag ?? "checked") === bag);
        const limit = LIMIT_KG[bag];
        const w = kg(items);
        const packed = items.filter((p) => p.data.packed).length;
        return (
          <section key={bag}>
            <SectionHeader title={label(bag)} accent="lime" count={`${packed}/${items.length} packed${w ? ` · ${w.toFixed(1)} kg` : ""}${limit ? ` of ${limit}` : ""}`} />
            {limit && w > 0 && <div style={{ marginBottom: 8 }}><Progress value={w / limit} accent={w > limit ? "pink" : "lime"} thin /></div>}
            {items.map((p) => (
              <div key={p.id} className="lrow click" onClick={() => setEditing(p)}>
                <CheckBox checked={!!p.data.packed} onChange={(v) => patch(p, { packed: v })} label="Packed" />
                <span className={`grow ${p.data.packed ? "strike" : "bold"}`}>{p.data.name}</span>
                {p.data.category && <span className="caption muted">{p.data.category}</span>}
                {(p.data.quantity ?? 1) > 1 && <span className="num">×{p.data.quantity}</span>}
                {p.data.weightGrams ? <span className="caption num">{p.data.weightGrams} g</span> : null}
              </div>
            ))}
            <QuickAdd placeholder={`Add to ${label(bag).toLowerCase()}`} onAdd={(name) => put<PackingItem>("packing", { name, bag, quantity: 1, packed: false })} />
          </section>
        );
      })}
      <AddButton title="Add item" onClick={() => setEditing("new")} />
      {editing && <RecordSheet title="Packing item" collection="packing" rec={editing} defaults={{ bag: "checked", quantity: 1, packed: false }} onClose={() => setEditing(null)}
        groups={[{ fields: [{ key: "name", label: "Item", kind: "text" }, { key: "bag", label: "Bag", kind: "select", options: BAGS }, { key: "category", label: "Category", kind: "text" },
          { key: "quantity", label: "Quantity", kind: "int" }, { key: "weightGrams", label: "Weight (g)", kind: "int" }, { key: "packed", label: "Packed", kind: "bool" }, { key: "notes", label: "Notes", kind: "long" }] }]} />}
    </>
  );
}
