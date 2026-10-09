// "Fri 9 Oct", "€ 750", labels and small file helpers.

export const today = () => new Date().toISOString().slice(0, 10);

export function shortDate(d?: string) {
  if (!d) return "";
  const dt = new Date(d.length === 10 ? d + "T12:00:00" : d);
  return dt.toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" }).replace(",", "");
}

export function daysUntil(d?: string) {
  if (!d) return undefined;
  return Math.round((new Date(d + "T00:00:00").getTime() - new Date(today() + "T00:00:00").getTime()) / 86_400_000);
}

const SYMBOL: Record<string, string> = { EUR: "€", NZD: "NZ$", USD: "$", GBP: "£" };
export function money(cents?: number, currency = "EUR") {
  const v = Math.round(cents ?? 0) / 100;
  return `${SYMBOL[currency] ?? currency} ${v.toLocaleString("nl-NL", { minimumFractionDigits: v % 1 ? 2 : 0, maximumFractionDigits: 2 })}`;
}
/** Parses "750", "750,50", "1.000,25" or "1,000.25" into cents. */
export function parseMoney(s: string): number | undefined {
  const t = s.replace(/[^\d.,-]/g, "");
  if (!t) return undefined;
  const lastSep = Math.max(t.lastIndexOf(","), t.lastIndexOf("."));
  const decimals = lastSep >= 0 && t.length - lastSep - 1 <= 2 ? t.slice(lastSep + 1) : "";
  const whole = (decimals ? t.slice(0, lastSep) : t).replace(/[.,]/g, "");
  return Math.round(parseFloat(`${whole}.${decimals || 0}`) * 100);
}

export const label = (s: string) => (s.charAt(0).toUpperCase() + s.slice(1)).replace(/-/g, " ");

export function download(name: string, text: string, type = "text/plain") {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([text], { type }));
  a.download = name; a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

/** CSV with ; separator and BOM, so Dutch Excel opens it directly. */
export function toCsv(rows: Record<string, unknown>[], columns: string[]) {
  const esc = (v: unknown) => { const s = v == null ? "" : String(v); return /[";\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; };
  return "﻿" + [columns.join(";"), ...rows.map((r) => columns.map((c) => esc(r[c])).join(";"))].join("\r\n");
}
