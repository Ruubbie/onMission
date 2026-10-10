// Turns a newsletter (Markdown) into one self-contained HTML page in the house style.
// Used for the live preview, the website page export and the email export; the website can reuse it.
import { marked } from "marked";
import tokens from "../design/tokens.css?raw";

export interface NewsletterDoc { title: string; number?: number; plannedDate?: string; body?: string }

const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);

export function renderNewsletter(n: NewsletterDoc, opts: { appName: string; email?: boolean }) {
  const body = marked.parse(n.body ?? "", { async: false });
  const date = n.plannedDate ? new Date(n.plannedDate + "T12:00:00").toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" }) : "";
  // Email clients ignore most CSS, so the email version keeps it to inline-safe basics.
  const css = opts.email
    ? `body{margin:0;background:#FBF6EA;font-family:Segoe UI,Arial,sans-serif;color:#111}.wrap{max-width:640px;margin:0 auto;padding:24px}.card{background:#FFFDF7;border:2.5px solid #111;border-radius:10px;padding:24px}h1{font-size:30px;margin:0 0 4px}img{max-width:100%}a{color:#111}.meta{color:#6E6A60;font-size:13px}`
    : `${tokens}
body{margin:0;background:var(--background);font:16px/1.6 var(--font);color:var(--ink)}
.wrap{max-width:720px;margin:0 auto;padding:40px 20px}
.card{background:var(--paper);border:var(--border) solid var(--ink);border-radius:var(--radius-card);box-shadow:var(--shadow) var(--shadow) 0 var(--ink);padding:32px}
.tag{display:inline-block;background:var(--accent-pink);border:var(--border-thin) solid var(--ink);border-radius:999px;padding:2px 10px;font-weight:700;font-size:12px}
h1{font-size:40px;line-height:1.1;margin:12px 0 4px}h2{margin-top:32px}img{max-width:100%;border:var(--border) solid var(--ink);border-radius:var(--radius-small)}
blockquote{margin:16px 0;padding:8px 16px;background:var(--soft-yellow);border-left:var(--border) solid var(--ink)}.meta{color:var(--muted);font-size:13px}`;
  return `<!doctype html><html lang="nl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(n.title)}</title><style>${css}</style></head>
<body><div class="wrap"><div class="card">${opts.email ? "" : `<span class="tag">${esc(opts.appName)}${n.number ? ` #${n.number}` : ""}</span>`}
<h1>${esc(n.title)}</h1><div class="meta">${esc(date)}</div>${body}</div></div></body></html>`;
}
