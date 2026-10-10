import { useState } from "react";
import { Users } from "lucide-react";
import { AddButton, EmptyState, SearchField } from "../ui";
import { list, useStore } from "../data/store";
import type { Contact } from "../data/types";
import { PageHead, RecordSheet, useOpenFromNav } from "./common";
import { CsvButton, DataTable, type Col } from "./table";

const cols: Col<Contact>[] = [
  { head: "Name", cell: (r) => <b>{r.data.name}</b>, csv: (r) => r.data.name },
  { head: "Role", cell: (r) => r.data.role ?? "" },
  { head: "Organisation", cell: (r) => r.data.organisation ?? "" },
  { head: "Email", cell: (r) => r.data.email ?? "" },
  { head: "Phone", cell: (r) => r.data.phone ?? "" },
];

export default function Contacts() {
  useStore();
  const [editing, setEditing] = useOpenFromNav<Contact>("contacts");
  const [q, setQ] = useState("");
  const rows = list<Contact>("contacts").filter((c) => !q || JSON.stringify(c.data).toLowerCase().includes(q.toLowerCase())).sort((a, b) => a.data.name.localeCompare(b.data.name));
  return (
    <>
      <PageHead title="Contacts"><CsvButton name="contacts" cols={cols} rows={rows} /></PageHead>
      <div className="row" style={{ marginBottom: 12 }}><SearchField value={q} onChange={setQ} placeholder="Search contacts" /></div>
      <DataTable cols={cols} rows={rows} onOpen={setEditing} empty={<EmptyState accent="grey" icon={<Users size={30} strokeWidth={2.5} />} title="No contacts" message="Add YWAM staff and other people you deal with." />} />
      <AddButton title="Add contact" onClick={() => setEditing("new")} />
      {editing && <RecordSheet title="Contact" collection="contacts" rec={editing} onClose={() => setEditing(null)}
        groups={[{ fields: [{ key: "name", label: "Name", kind: "text" }, { key: "role", label: "Role", kind: "text" }, { key: "organisation", label: "Organisation", kind: "text" },
          { key: "email", label: "Email", kind: "text" }, { key: "phone", label: "Phone", kind: "text" }, { key: "address", label: "Address", kind: "text" }, { key: "notes", label: "Notes", kind: "long" }] }]} />}
    </>
  );
}
