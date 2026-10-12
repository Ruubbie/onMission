// Ctrl+K: search every record and jump to it.
import { useState } from "react";
import { SearchField, useEscape } from "../ui";
import { allRecords } from "../data/store";
import { label } from "../data/format";
import { pageFor, recTitle, useNav } from "./common";

export default function SearchDialog({ onClose }: { onClose: () => void }) {
  const [q, setQ] = useState("");
  const { go } = useNav();
  useEscape(onClose);
  const hits = q.trim().length < 2 ? [] : allRecords()
    .filter((r) => r.collection !== "settings" && JSON.stringify(r.data).toLowerCase().includes(q.toLowerCase()))
    .slice(0, 30);
  return (
    <div className="scrim" onClick={onClose}>
      <div className="box dialog" style={{ margin: "10vh auto auto", width: "min(640px, calc(100% - 32px))" }} onClick={(e) => e.stopPropagation()}>
        <div className="row" onKeyDown={(e) => { if (e.key === "Enter" && hits[0]) { go(pageFor[hits[0].collection], hits[0].id); onClose(); } }}>
          <SearchField value={q} onChange={setQ} placeholder="Search everything" autoFocus />
        </div>
        <div style={{ maxHeight: "55vh", overflow: "auto", marginTop: 12 }}>
          {hits.map((r) => (
            <div key={r.id} className="lrow click" onClick={() => { go(pageFor[r.collection], r.id); onClose(); }}>
              <span className="grow ellipsis bold">{recTitle(r)}</span><span className="caption muted">{label(r.collection)}</span>
            </div>
          ))}
          {q.trim().length >= 2 && !hits.length && <p className="muted">Nothing found.</p>}
        </div>
      </div>
    </div>
  );
}
