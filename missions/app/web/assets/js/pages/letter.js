// One letter: write it in Dutch and English as sections, add photos with captions, and choose whether hesent.me
// shows it once it's sent. Every field saves when you leave it. Where each piece goes on the page is chosen on the
// Arrange page (arrange.js); see sections.js for how sections, the body and the arrangement fit together.

import { api } from "../api.js";
import { store } from "../store.js";
import { I } from "../motion.js";
import { esc, toast, mkPills } from "../ui.js";
import { NEWSLETTER_STATUSES, newId } from "../util.js";
import { patch } from "./common.js";
import { sectionsOf, withSections, resolve, words, thumbSrc, keepThumb, fillThumbs } from "./sections.js";

export const title = "Letter";
export const parent = "newsletter";
export const kick = "Letter";
export const cream = true;

const MAX_SIDE = 1800;     // photos are scaled down to this many pixels on their long side before upload
const LANGS = [["nl", "Nederlands"], ["en", "English"]];
const STATUS_LABEL = { idea: "Idea", draft: "Draft", ready: "Ready", sent: "Sent" };
let lang = "nl";           // which language the fields show; kept while you stay on the page
let focusNext = null;      // a section just added, whose heading takes the cursor after the redraw

// The fields that exist once per language: Dutch under the plain name, English with En after it.
const HEAD = [
  ["title", "Title", "input", "Een nieuw hoofdstuk"],
  ["subtitle", "Subtitle", "input", "Van de bergen, naar de mensen."],
];
const AFTER = [
  ["prayers", "Prayer points, one per line", "list", "Voor de mensen die ik hier mag ontmoeten."],
  ["note", "Side note or quote", "input", "Soms zijn het de kleine dingen die het meest doen."],
  ["nextTime", "Next time", "input", "Meer over de YWAM base."],
  ["funds", "Support, in your own words (optional)", "input", "Nog even en ik ben er: wil je meedoen?"],
];
const key = (k) => (lang === "en" ? `${k}En` : k);
const WHERE = ["Column 1", "Column 2", "Column 3"];

export function build(ctx) {
  const n = store.get("newsletters", ctx.id);
  if (!n) return `<div class="abs hand hi in">Gone</div><div class="sheet"><div class="rw"><div class="tx"><div class="t1">This letter is gone.</div></div></div></div>`;
  const name = n.title || n.titleEn || "Untitled letter";
  const big = name.length > 40 ? 40 : name.length > 22 ? 54 : 68;
  const photos = n.photos ?? [];
  const { sections } = sectionsOf(n);
  const arr = resolve(n, sections);
  const where = (ref) => {
    const i = arr.columns.findIndex((c) => c.includes(ref));
    return i >= 0 ? WHERE[i] : arr.footer.includes(ref) ? "Footer" : arr.cover && ref === `p:${arr.cover}` ? "Header" : "Off the page";
  };
  return `
    <div class="abs hand hi in">${esc(n.number ? `Letter ${n.number}` : "Letter")}</div>
    <div class="abs in" style="left:22px;right:22px;top:146px"><div class="disp" data-name style="font-size:${big}px;line-height:.9">${esc(name)}</div><div class="cap" data-line style="margin:16px 0 0 2px">${esc(lineFor(n, sections))}</div></div>
    <div class="sheet"><div class="scroll led">
      <div class="led-write">
        <div class="pills tight" data-lang style="margin-top:4px"></div>
        ${HEAD.map(([k, label, kind, ph]) => field(n, k, label, kind, ph)).join("")}
        <div class="sec led-secs-title">Sections <b>${sections.length}</b></div>
        <div class="led-secs" data-secs>${sections.map((s, i) => sectionCard(s, i, where(`s:${s.id}`))).join("")}</div>
        <button class="btn o wide led-add-sec" data-add-sec>${I.plus}Add a section</button>
        ${AFTER.map(([k, label, kind, ph]) => field(n, k, label, kind, ph)).join("")}
      </div>
      <div class="led-side">
        <a class="led-arrange" href="#/arrange/${esc(n.id)}">
          <span class="led-arrange-map" aria-hidden="true">${miniMap(arr)}</span>
          <span><b>Arrange the page</b><em>${arr.auto ? "Arranged automatically for now. Drag the pieces where you want them." : "Arranged by you. New pieces join at the end."}</em></span>
        </a>
        <div class="sec">Photos <b>${photos.length}</b></div>
        <div class="led-photos" data-photos>${photos.map((p) => photoRow(p, where(`p:${p.id}`))).join("")}</div>
        <label class="btn o wide led-add">${I.plus}Add photos<input type="file" accept="image/*" multiple data-add hidden></label>
        <div class="sgap"></div><div class="sec">Issue</div>
        <label class="set"><span class="lbl">Number</span><input type="number" min="1" step="1" data-f="number" value="${esc(n.number ?? "")}"></label>
        <label class="set"><span class="lbl">Place</span><input type="text" data-f="place" value="${esc(n.place ?? "")}" placeholder="Queenstown, NZ" maxlength="80"></label>
        <label class="set"><span class="lbl">Planned for</span><input type="date" data-f="plannedDate" value="${esc(n.plannedDate ?? "")}"></label>
        <div class="pills tight" data-status style="margin-top:10px"></div>
        <label class="set led-toggle"><span class="lbl">Show on hesent.me once sent</span><input type="checkbox" data-public ${n.public ? "checked" : ""}></label>
        <p class="empty-note">${esc(siteNote(n))}</p>
      </div>
    </div></div>`;
}

function field(n, k, label, kind, ph) {
  const v = n[key(k)];
  const id = `led-${k}`;
  const placeholder = lang === "nl" ? ph : "";
  if (kind === "input") {
    return `<label class="led-f" for="${id}"><span>${esc(label)}</span><input id="${id}" type="text" data-t="${k}" value="${esc(v ?? "")}" placeholder="${esc(placeholder)}"></label>`;
  }
  const text = Array.isArray(v) ? v.join("\n") : "";
  return `<label class="led-f" for="${id}"><span>${esc(label)}</span><textarea id="${id}" rows="4" data-t="${k}" data-kind="${kind}" placeholder="${esc(placeholder)}">${esc(text)}</textarea></label>`;
}

// One section: its heading and its text in the language shown, where it sits on the page, and a way to remove it.
function sectionCard(s, i, where) {
  const title = lang === "en" ? s.titleEn : s.title;
  const body = lang === "en" ? s.bodyEn : s.body;
  const other = lang === "en" ? s.body : s.bodyEn;
  const ph = i === 0 ? (lang === "en" ? "Hi everyone,\n\nIt’s so good that you…" : "Hoi lieve mensen,\n\nWat fijn dat je weer de tijd neemt…") : (lang === "en" ? "Write in English…" : "Schrijf hier…");
  return `<div class="led-sec" data-sec="${esc(s.id)}">
    <div class="led-sec-top">
      <input type="text" data-st value="${esc(title ?? "")}" placeholder="${i === 0 ? "Heading (optional, the opening often has none)" : "Heading"}" aria-label="Section ${i + 1} heading" maxlength="140">
      <span class="led-sec-where">${esc(where)}</span>
      <button class="round" data-del-sec aria-label="Remove section ${i + 1}">${I.plus}</button>
    </div>
    <textarea data-sb rows="5" placeholder="${esc(ph)}" aria-label="Section ${i + 1} text">${esc(body ?? "")}</textarea>
    <div class="led-sec-foot"><span data-count>${words(body)} words</span>${!body?.trim() && other?.trim() ? `<span>${lang === "en" ? "Written in Dutch so far" : "Written in English so far"}</span>` : ""}<em>Empty line: new paragraph · **bold** · *italic* · - list</em></div>
  </div>`;
}

function photoRow(p, where) {
  const cap = lang === "en" ? p.captionEn : p.caption;
  const src = thumbSrc(p.id);
  return `<div class="led-ph" data-ph="${esc(p.id)}">
    <img alt="" data-thumb="${esc(p.id)}" ${src ? `src="${src}"` : ""}>
    <input type="text" data-cap value="${esc(cap ?? "")}" placeholder="${lang === "en" ? "Caption (English)" : "Onderschrift"}" maxlength="200">
    <div class="led-ph-acts"><span class="led-sec-where">${esc(where)}</span><button class="round" data-del aria-label="Remove photo">${I.plus}</button></div>
  </div>`;
}

// A thumbnail of the arrangement: the header, three columns and the footer, a bar per piece.
function miniMap(arr) {
  const bar = (r) => `<i class="${r.startsWith("p:") ? "ph" : r.startsWith("s:") ? "tx" : "as"}"></i>`;
  return `<span class="mm-head">${arr.cover ? `<i class="ph"></i>` : ""}</span><span class="mm-cols">${arr.columns.map((c) => `<span>${c.map(bar).join("")}</span>`).join("")}</span>${arr.footer.length ? `<span class="mm-foot">${arr.footer.map(bar).join("")}</span>` : ""}`;
}

function lineFor(n, sections) {
  const status = STATUS_LABEL[n.status] ?? "Idea";
  const langs = [n.title && "NL", n.titleEn && "EN"].filter(Boolean).join(" + ") || "No title yet";
  const count = sections ?? sectionsOf(n).sections;
  return `${status} · ${langs} · ${count.length} sections · ${(n.photos ?? []).length} photos`;
}

function siteNote(n) {
  if (!n.public) return "Only in your app. Tick the box to put it on hesent.me once it's sent.";
  const missing = [!n.title && "Dutch", !n.titleEn && "English"].filter(Boolean);
  const where = missing.length ? ` It needs a title in ${missing.join(" and ")} to show in that language.` : "";
  return (n.status === "sent" ? "On hesent.me now." : "Goes on hesent.me when you mark it sent.") + where;
}

export function init(el, ctx) {
  const n = store.get("newsletters", ctx.id);
  if (!n) return;
  const id = n.id;
  const current = () => store.get("newsletters", id);
  const fail = (err) => toast(err.message || "That didn't save.", { bad: true });

  // A letter written before sections (or edited on the iPhone since) gets its sections from the body, once.
  const first = sectionsOf(n);
  if (first.changed) patch("newsletters", id, withSections(first.sections)).catch(fail);

  // Only the poster changes after typing; a full redraw would take the cursor out of the next field.
  const poster = () => {
    const n2 = current(), name = el.querySelector("[data-name]"), line = el.querySelector("[data-line]");
    if (!n2 || !name) return;
    name.textContent = n2.title || n2.titleEn || "Untitled letter";
    line.textContent = lineFor(n2);
  };

  mkPills(el.querySelector("[data-lang]"), LANGS, lang, (to) => {
    lang = to;
    ctx.refresh();
  });
  mkPills(el.querySelector("[data-status]"), NEWSLETTER_STATUSES.map((s) => [s, STATUS_LABEL[s]]), n.status ?? "idea", async (status) => {
    const sentAt = status === "sent" ? (current().sentAt ?? new Date().toISOString()) : current().sentAt ?? null;
    await patch("newsletters", id, { status, sentAt });
    ctx.refresh();
    toast(status === "sent" ? "Marked as sent" : `Moved to ${STATUS_LABEL[status].toLowerCase()}`);
  });

  // Saves after a short pause in typing and when you leave the field, so a shortcut or tab switch straight from
  // the field doesn't lose what you wrote.
  const autosave = (f, save) => {
    let timer = null;
    const now = () => { clearTimeout(timer); save(); };
    f.addEventListener("input", () => { clearTimeout(timer); timer = setTimeout(now, 800); });
    f.addEventListener("change", now);
  };
  el.querySelectorAll("[data-t]").forEach((f) => autosave(f, () => {
    const k = key(f.dataset.t);
    const value = f.dataset.kind === "list" ? f.value.split("\n").map((s) => s.trim()).filter(Boolean) : f.value.trim() || null;
    if (JSON.stringify(value) === JSON.stringify(current()?.[k] ?? null)) return;
    patch("newsletters", id, { [k]: value }).then(poster).catch(fail);
  }));

  // Sections: each heading and text saves into its own section, and the bodies are made again from all of them.
  const saveSection = (sid, changes) => {
    const { sections } = sectionsOf(current());
    if (!sections.some((s) => s.id === sid)) return Promise.resolve();
    return patch("newsletters", id, withSections(sections.map((s) => (s.id === sid ? { ...s, ...changes } : s)))).then(poster).catch(fail);
  };
  const box = el.querySelector("[data-secs]");
  box.querySelectorAll("[data-sec]").forEach((card) => {
    const sid = card.dataset.sec;
    const head = card.querySelector("[data-st]"), text = card.querySelector("[data-sb]");
    const grow = () => { text.style.height = "auto"; text.style.height = `${text.scrollHeight + 2}px`; };
    grow();
    text.addEventListener("input", () => {
      grow();
      card.querySelector("[data-count]").textContent = `${words(text.value)} words`;
    });
    autosave(head, () => saveSection(sid, { [lang === "en" ? "titleEn" : "title"]: head.value.trim() || null }));
    autosave(text, () => saveSection(sid, { [lang === "en" ? "bodyEn" : "body"]: text.value.replace(/\s+$/, "") }));
    // Enter in the heading goes on to the text, like a paragraph after its title.
    head.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); text.focus(); } });
  });
  if (focusNext) {
    box.querySelector(`[data-sec="${CSS.escape(focusNext)}"] [data-st]`)?.focus();
    focusNext = null;
  }
  el.querySelector("[data-add-sec]").addEventListener("click", async () => {
    const { sections } = sectionsOf(current());
    const s = { id: newId(), title: null, body: "", titleEn: null, bodyEn: "" };
    focusNext = s.id;
    await patch("newsletters", id, withSections([...sections, s])).catch(fail);
    ctx.refresh();
  });
  box.addEventListener("click", async (e) => {
    const b = e.target.closest("[data-del-sec]");
    if (!b) return;
    const sid = b.closest("[data-sec]").dataset.sec;
    const { sections } = sectionsOf(current());
    const s = sections.find((x) => x.id === sid);
    if (s && (s.body?.trim() || s.bodyEn?.trim()) && !window.confirm(`Remove the section${s.title ? ` "${s.title}"` : ""} and its text, in both languages?`)) return;
    await patch("newsletters", id, { ...withSections(sections.filter((x) => x.id !== sid)), layout: drop(current().layout, `s:${sid}`) }).catch(fail);
    ctx.refresh();
  });

  el.querySelectorAll("[data-f]").forEach((f) => f.addEventListener("change", () => {
    const k = f.dataset.f;
    const value = k === "number" ? (parseInt(f.value, 10) > 0 ? parseInt(f.value, 10) : null) : f.value.trim() || null;
    patch("newsletters", id, { [k]: value });
  }));
  el.querySelector("[data-public]").addEventListener("change", async (e) => {
    await patch("newsletters", id, { public: e.target.checked });
    toast(e.target.checked ? "Will show on hesent.me" : "Only in your app now");
    ctx.refresh();
  });

  // Photos: upload, caption, remove. Where they go is chosen on the Arrange page.
  el.querySelector("[data-add]").addEventListener("change", async (e) => {
    const files = [...e.target.files];
    e.target.value = "";
    for (const file of files) {
      toast(`Uploading ${file.name}…`);
      try {
        const { blob, width, height } = await shrink(file);
        const fileId = newId();
        await api.upload(`/v1/files/${fileId}`, blob, file.name.replace(/\.\w+$/, "") + ".jpg");
        keepThumb(fileId, URL.createObjectURL(blob));
        const photos = [...(current().photos ?? []), { id: fileId, caption: "", captionEn: "", width, height }];
        await patch("newsletters", id, { photos });
      } catch (err) {
        toast(err.message || "That photo didn't upload.", { bad: true });
      }
    }
    toast("Photos added");
    ctx.refresh();
  });
  const photoBox = el.querySelector("[data-photos]");
  photoBox.addEventListener("change", (e) => {
    if (!e.target.matches("[data-cap]")) return;
    const pid = e.target.closest("[data-ph]").dataset.ph;
    const field = lang === "en" ? "captionEn" : "caption";
    patch("newsletters", id, { photos: (current().photos ?? []).map((p) => (p.id === pid ? { ...p, [field]: e.target.value.trim() } : p)) });
  });
  photoBox.addEventListener("click", async (e) => {
    if (!e.target.closest("[data-del]")) return;
    const pid = e.target.closest("[data-ph]").dataset.ph;
    if (!window.confirm("Remove this photo from the letter?")) return;
    const photos = (current().photos ?? []).filter((p) => p.id !== pid);
    await patch("newsletters", id, { photos, layout: drop(current().layout, `p:${pid}`) });
    ctx.refresh();
    api.del(`/v1/files/${pid}`).catch(() => {});
  });

  fillThumbs(el);
}

/** A stored layout without one piece, so removed sections and photos don't linger in it. */
function drop(layout, ref) {
  if (!layout || !Array.isArray(layout.columns)) return layout ?? null;
  return {
    ...layout,
    cover: ref === `p:${layout.cover}` ? null : layout.cover ?? null,
    columns: layout.columns.map((c) => (Array.isArray(c) ? c.filter((r) => r !== ref) : [])),
    off: (layout.off ?? []).filter((r) => r !== ref),
  };
}

/** Scales a photo down to MAX_SIDE on its long side and re-encodes it as JPEG, so letters stay light. */
async function shrink(file) {
  const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
  const scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height));
  const width = Math.round(bitmap.width * scale), height = Math.round(bitmap.height * scale);
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  canvas.getContext("2d").drawImage(bitmap, 0, 0, width, height);
  bitmap.close?.();
  const blob = await new Promise((resolve, reject) => canvas.toBlob((b) => (b ? resolve(b) : reject(new Error("That photo couldn't be read."))), "image/jpeg", 0.85));
  return { blob, width, height };
}
