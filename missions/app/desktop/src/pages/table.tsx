// A card holding a sortable-free, clickable table, plus CSV export of the same columns.
import type { ReactNode } from "react";
import { Download } from "lucide-react";
import { Button } from "../ui";
import type { Rec } from "../data/types";
import { download, toCsv } from "../data/format";

export interface Col<T> { head: string; cell: (r: Rec<T>) => ReactNode; csv?: (r: Rec<T>) => unknown; align?: "right" }

export function DataTable<T>({ cols, rows, onOpen, empty }: { cols: Col<T>[]; rows: Rec<T>[]; onOpen: (r: Rec<T>) => void; empty?: ReactNode }) {
  if (!rows.length) return <>{empty}</>;
  return (
    <div className="box" style={{ overflowX: "auto" }}>
      <table className="table">
        <thead><tr>{cols.map((c) => <th key={c.head} style={{ textAlign: c.align }}>{c.head}</th>)}</tr></thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id} className="click" onClick={() => onOpen(r)}>
              {cols.map((c) => <td key={c.head} style={{ textAlign: c.align }} className={c.align ? "num" : undefined}>{c.cell(r)}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function CsvButton<T>({ name, cols, rows }: { name: string; cols: Col<T>[]; rows: Rec<T>[] }) {
  const exp = () => {
    const heads = cols.map((c) => c.head);
    const data = rows.map((r) => Object.fromEntries(cols.map((c) => [c.head, c.csv ? c.csv(r) : c.cell(r)])));
    download(`${name}.csv`, toCsv(data, heads), "text/csv");
  };
  return <Button variant="secondary" onClick={exp}><Download size={16} strokeWidth={3} />CSV</Button>;
}
