// A letter's sections and how they are arranged on hesent.me, shared by the Write page (letter.js) and the
// Arrange page (arrange.js).
//
// A letter is written as sections: an optional heading and its text, in Dutch and English. `body` and `bodyEn`
// are kept as the sections joined into Markdown, so the iPhone and Windows apps (which edit the body) and the
// excerpts keep working. When the body was edited elsewhere and no longer matches, the sections are read from
// the body again, keeping their ids by position so the arrangement mostly survives.
//
// The arrangement (`layout`) is which photo leads in the header (`cover`), which pieces go in each of the three
// columns top to bottom (`columns`), which go in the footer under them, side by side (`footer`), and which stay off
// the page (`off`). Pieces are "s:<section id>", "p:<photo id>", "prayers", "note", "next" (next time and the
// sign-up) and "funds" (the support so far and how to give). Without a layout the letter is arranged automatically,
// with next time and funds together in the footer.
// The server applies the same rules (resolve below) in missions/app/server/src/index.js, arranged().

import { api } from "../api.js";
import { newId } from "../util.js";

const mdOf = (title, body) => [title && `## ${title}`, body].filter(Boolean).join("\n\n");
const flat = (md) => (typeof md === "string" ? md : "").replace(/\r/g, "").replace(/[ \t]+$/gm, "").replace(/\n{3,}/g, "\n\n").trim();
const clean = (s) => (typeof s === "string" && s.trim() ? s.trim() : null);
export const words = (t) => ((t || "").match(/\S+/g) || []).length;

/** The sections as one Markdown body in a language: what goes in `body` or `bodyEn`. */
export function joinBody(sections, lang) {
  const en = lang === "en";
  return sections.map((s) => mdOf(clean(en ? s.titleEn : s.title), (en ? s.bodyEn : s.body)?.trim() ?? "")).filter(Boolean).join("\n\n");
}

/** A Markdown body cut at its # and ## headings: what comes before the first heading is a section without one. */
function cut(md) {
  const out = [];
  let cur = { title: null, lines: [] };
  for (const line of flat(md).split("\n")) {
    const h = line.match(/^[ \t]*#{1,2}(?!#)[ \t]*(\S.*)$/);
    if (h) {
      if (cur.title || cur.lines.join("").trim()) out.push(cur);
      cur = { title: h[1].trim(), lines: [] };
    } else cur.lines.push(line);
  }
  if (cur.title || cur.lines.join("").trim()) out.push(cur);
  return out.map((s) => ({ title: s.title, body: s.lines.join("\n").trim() }));
}

/**
 * The letter's sections, read from the body when there are none yet or the body was edited elsewhere.
 * `changed` says they differ from what is stored, so the page saves them (and the tidied body) once.
 */
export function sectionsOf(n) {
  const stored = Array.isArray(n.sections) ? n.sections.filter((s) => s && s.id) : [];
  const same = (lang) => flat(joinBody(stored, lang)) === flat(lang === "en" ? n.bodyEn : n.body);
  if (stored.length && same("nl") && same("en")) return { sections: stored, changed: false };
  if (!stored.length && !flat(n.body) && !flat(n.bodyEn)) return { sections: [], changed: false };
  const nl = cut(n.body), en = cut(n.bodyEn);
  const sections = Array.from({ length: Math.max(nl.length, en.length) }, (_, i) => ({
    id: stored[i]?.id ?? newId(),
    title: nl[i]?.title ?? null, body: nl[i]?.body ?? "",
    titleEn: en[i]?.title ?? null, bodyEn: en[i]?.body ?? "",
  }));
  return { sections, changed: true };
}

/** The fields to save after changing the sections: the sections and both bodies made from them. */
export function withSections(sections) {
  return { sections, body: joinBody(sections, "nl"), bodyEn: joinBody(sections, "en") };
}

/** Every piece the letter has, in either language, in writing order. */
export function piecesOf(n, sections) {
  const filled = (a, b) => (Array.isArray(a) && a.length) || (Array.isArray(b) && b.length);
  return [
    ...sections.map((s) => `s:${s.id}`),
    ...(n.photos ?? []).map((p) => `p:${p.id}`),
    ...(filled(n.prayers, n.prayersEn) ? ["prayers"] : []),
    ...(clean(n.note) || clean(n.noteEn) ? ["note"] : []),
    "next",
    "funds",
  ];
}

/**
 * The arrangement as the page shows it: the stored layout with pieces that no longer exist dropped and new ones
 * added where they go by themselves, or the automatic one when there is no layout yet. A layout from before the
 * footer existed gets one: next time moves into it, with funds beside it.
 */
export function resolve(n, sections) {
  const L = n.layout;
  if (!L || !Array.isArray(L.columns)) return auto(n, sections);
  const has = new Set(piecesOf(n, sections));
  const cover = typeof L.cover === "string" && has.has(`p:${L.cover}`) ? L.cover : null;
  const seen = new Set(cover ? [`p:${cover}`] : []);
  const keep = (r) => typeof r === "string" && has.has(r) && !seen.has(r) && seen.add(r);
  const old = !Array.isArray(L.footer);
  const columns = [0, 1, 2].map((i) => (Array.isArray(L.columns[i]) ? L.columns[i] : []).filter((r) => !(old && r === "next") && keep(r)));
  const footer = (old ? [] : L.footer).filter(keep);
  const off = (Array.isArray(L.off) ? L.off : []).filter(keep);
  for (const r of has) {
    if (seen.has(r)) continue;
    if (r.startsWith("s:")) {
      const col = columns[[2, 1, 0].find((i) => columns[i].some((x) => x.startsWith("s:"))) ?? 0];
      col.splice(col.findLastIndex((x) => x.startsWith("s:")) + 1, 0, r);
    } else (r === "next" || r === "funds" ? footer : columns[2]).push(r);
  }
  return { cover, columns, footer, off, auto: false };
}

/**
 * The automatic arrangement, close to what hesent.me does on its own: the first photo leads, the text runs down
 * the first column and on into the second (which opens with the second photo), split between sections near the
 * middle; the note, the prayer points and the other photos go in the third column, and next time and funds in the
 * footer.
 */
export function auto(n, sections) {
  const photos = (n.photos ?? []).map((p) => `p:${p.id}`);
  const [cover, top, ...rest] = photos;
  const len = sections.map((s) => words(s.body) + words(s.title) + 0.6 * (words(s.bodyEn) + words(s.titleEn)));
  const total = len.reduce((a, b) => a + b, 0) + (top ? 60 : 0);
  let at = sections.length, best = Infinity, sum = 0;
  for (let i = 1; i < sections.length; i++) {
    sum += len[i - 1];
    if (Math.abs(sum - total / 2) < best) { best = Math.abs(sum - total / 2); at = i; }
  }
  if (sections.length < 2) at = sections.length;
  const text = sections.map((s) => `s:${s.id}`);
  const has = new Set(piecesOf(n, sections));
  return {
    cover: cover ? cover.slice(2) : null,
    columns: [
      text.slice(0, at),
      [...(top ? [top] : []), ...text.slice(at)],
      ["note", "prayers", ...rest].filter((r) => has.has(r)),
    ],
    footer: ["next", "funds"],
    off: [],
    auto: true,
  };
}

/** The layout to store from an arrangement. */
export const toLayout = ({ cover, columns, footer, off }) => ({ cover: cover ?? null, columns: columns.map((c) => [...c]), footer: [...footer], off: [...off] });

// Photo thumbnails need the login token, so they are fetched rather than linked, and kept while the app is open.
const thumbs = new Map();
export const thumbSrc = (id) => thumbs.get(id) ?? null;
export function keepThumb(id, url) { thumbs.set(id, url); }
export function fillThumbs(root) {
  root.querySelectorAll("img[data-thumb]:not([src])").forEach(async (img) => {
    const id = img.dataset.thumb;
    try {
      if (!thumbs.has(id)) thumbs.set(id, URL.createObjectURL(await api.blob(`/v1/files/${id}`)));
      img.src = thumbs.get(id);
    } catch { img.alt = "Photo missing"; }
  });
}
