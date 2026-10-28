// Builds public/nl/ and public/en/ (the home page, the letters front page, the letter page and the giving page) from content/*.json,
// and public/assets/land.json for the globe.
// Run: node build.mjs
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { render, renderLetters, renderLetter, renderGiving } from "./src/shell.mjs";
import { worldPaths } from "./src/world.mjs";

const root = dirname(fileURLToPath(import.meta.url));
const read = (p) => JSON.parse(readFileSync(join(root, p), "utf8"));
const site = read("content/site.json");

// The departure date comes from the server (Settings in the app), so the page is built with the real one.
// Offline, or before the public routes are deployed, the date in site.json stays.
try {
  const res = await fetch(`${site.api.replace(/\/+$/, "")}/v1/public/summary`, { signal: AbortSignal.timeout(8000) });
  const live = res.ok ? await res.json() : null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(live?.departureDate || "")) site.departureDate = live.departureDate;
  console.log(live ? `departure ${site.departureDate} (from ${site.api})` : `departure ${site.departureDate} (from site.json; ${site.api} answered ${res.status})`);
} catch (err) {
  console.log(`departure ${site.departureDate} (from site.json; ${site.api} not reachable: ${err.message})`);
}

// The globe's land: the Natural Earth outlines are stored as equirectangular points in a 1000×500 box.
// Turn them into [lon, lat, lon, lat, …] rings (one array per ring), rounded to a tenth of a degree.
const rings = worldPaths
  .split("M")
  .filter(Boolean)
  .map((chunk) => {
    const pts = [];
    for (const [, x, y] of chunk.matchAll(/(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/g)) {
      pts.push(Math.round((Number(x) / 1000 * 360 - 180) * 10) / 10, Math.round((90 - Number(y) / 500 * 180) * 10) / 10);
    }
    return pts;
  })
  .filter((r) => r.length >= 6);
mkdirSync(join(root, "public", "assets"), { recursive: true });
writeFileSync(join(root, "public", "assets", "land.json"), JSON.stringify(rings));
console.log(`built public/assets/land.json (${rings.length} rings)`);

const copy = Object.fromEntries(["nl", "en"].map((lang) => [lang, read(`content/${lang}.json`)]));
// The letter pages and the giving page have their own word in each language (brieven/letters, brief/letter,
// geven/give); the language switch links them.
const slugs = {
  index: { nl: copy.nl.paper.index.slug, en: copy.en.paper.index.slug },
  letter: { nl: copy.nl.paper.letter.slug, en: copy.en.paper.letter.slug },
  giving: { nl: copy.nl.giving.slug, en: copy.en.giving.slug },
};
const write = (dir, html) => {
  mkdirSync(join(root, "public", dir), { recursive: true });
  writeFileSync(join(root, "public", dir, "index.html"), html);
  console.log(`built public/${dir}/index.html (${(html.length / 1024).toFixed(1)} KB)`);
};
for (const [lang, c] of Object.entries(copy)) {
  write(lang, render(c, site));
  write(`${lang}/${slugs.index[lang]}`, renderLetters(c, site, slugs));
  write(`${lang}/${slugs.letter[lang]}`, renderLetter(c, site, slugs));
  write(`${lang}/${slugs.giving[lang]}`, renderGiving(c, site, slugs));
}
