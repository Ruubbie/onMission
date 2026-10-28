// Local preview: node dev.mjs → http://localhost:8788
// Serves ./public like the Worker does. The pages talk to the real server in content/site.json, like the live site.
// SAMPLE=1 answers the public API routes here with SAMPLE data instead (the letters are in dev-letters.mjs), so the
// live numbers, prayers, letters, sign-up and giving-page message can be tried without the real server.
import { createServer } from "node:http";
import { sampleList, sampleLetter, samplePhoto, sampleSummaryLetters } from "./dev-letters.mjs";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(fileURLToPath(new URL(".", import.meta.url)), "public");
const port = Number(process.env.PORT) || 8788;
const types = { ".html": "text/html; charset=utf-8", ".css": "text/css", ".js": "text/javascript", ".svg": "image/svg+xml", ".woff2": "font/woff2", ".json": "application/json", ".jpg": "image/jpeg", ".png": "image/png", ".webp": "image/webp" };

const sample = {
  today: new Date().toISOString().slice(0, 10),
  departureDate: "2027-01-05",
  daysToDeparture: Math.round((Date.parse("2027-01-05") - Date.parse(new Date().toISOString().slice(0, 10))) / 864e5),
  support: { percentOfTarget: 62 },
  // Set GIVING=0 to see Give before the bank details are filled in.
  giving: process.env.GIVING === "0" ? null : { iban: "NL00 TEST 0123 4567 89", holder: "Sample Holder", reference: "Queenstown", url: "https://example.com/give" },
  prayers: [
    { id: "1", text: "Voor de visumaanvraag: dat alles op tijd rondkomt.", addedAt: "2026-10-04", answeredAt: null },
    { id: "2", text: "Voor de kerkavond op 13 november, en wie daar komen.", addedAt: "2026-10-09", answeredAt: null },
    { id: "3", text: "Voor een goed afscheid van mijn familie.", addedAt: "2026-09-28", answeredAt: null },
    { id: "4", text: "Dat YWAM Queenstown snel antwoord geeft over mijn rol.", addedAt: "2026-09-12", answeredAt: "2026-10-01" },
  ],
  // Set LETTERS=0 to see the page before any letter is online.
};
const noLetters = process.env.LETTERS === "0";
const useSample = process.env.SAMPLE === "1";

createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${port}`);
  const lang = url.searchParams.get("lang") === "en" ? "en" : "nl";
  if (!useSample && url.pathname.startsWith("/v1/")) return send(res, 404, "text/plain", "Start with SAMPLE=1 for sample data.");
  if (url.pathname === "/v1/public/summary") {
    return send(res, 200, "application/json", JSON.stringify({ ...sample, letters: noLetters ? [] : sampleSummaryLetters(lang) }));
  }
  if (url.pathname === "/v1/public/letters") {
    return send(res, 200, "application/json", JSON.stringify(noLetters ? { letters: [] } : sampleList(lang)));
  }
  const one = url.pathname.match(/^\/v1\/public\/letters\/([^/]+)$/);
  if (one) {
    const data = noLetters ? null : sampleLetter(lang, decodeURIComponent(one[1]));
    return data ? send(res, 200, "application/json", JSON.stringify(data)) : send(res, 404, "application/json", '{"error":{"code":"not_found","message":"No such letter."}}');
  }
  const pic = url.pathname.match(/^\/v1\/public\/photos\/sample-(\d+)$/);
  if (pic) return send(res, 200, "image/svg+xml", samplePhoto(Number(pic[1])));
  if (url.pathname === "/v1/public/subscribe" && req.method === "POST") {
    let body = "";
    for await (const chunk of req) body += chunk;
    console.log("sign-up (sample, not stored):", body);
    return setTimeout(() => send(res, 201, "application/json", JSON.stringify({ ok: true })), 600);
  }
  if (url.pathname === "/v1/public/message" && req.method === "POST") {
    let body = "";
    for await (const chunk of req) body += chunk;
    console.log("message (sample, not stored):", body);
    return setTimeout(() => send(res, 201, "application/json", JSON.stringify({ ok: true })), 600);
  }
  if (url.pathname === "/") { res.writeHead(302, { Location: "/nl/" }); return res.end(); }
  let path = normalize(decodeURIComponent(url.pathname)).replace(/^([/\\])+/, "");
  if (path === "" || path.endsWith("\\") || path.endsWith("/")) path = join(path, "index.html");
  const file = join(root, path);
  if (!file.startsWith(root)) return send(res, 403, "text/plain", "no");
  try {
    let data = await readFile(file);
    if (useSample && extname(file) === ".html") data =Buffer.from(String(data).replace(/(<meta name="hesent-api" content=")[^"]*/, "$1"));
    send(res, 200, types[extname(file)] || "application/octet-stream", data);
  } catch {
    try { await readFile(join(file, "index.html")); res.writeHead(302, { Location: url.pathname + "/" }); res.end(); }
    catch { send(res, 404, "text/html; charset=utf-8", await readFile(join(root, "404.html"))); }
  }
}).listen(port, () => console.log(`hesent.me preview on http://localhost:${port} (${useSample ? "sample data" : "live data from the server in content/site.json"})`));

function send(res, status, type, body) {
  res.writeHead(status, { "Content-Type": type, "Cache-Control": "no-store" });
  res.end(body);
}
