// Arrange a letter's page on hesent.me (#/arrange/<id>, from the letter). The page is drawn the way the site draws
// it (letters.js and letters.css in missions/site): the headline with the cover photo beside it, then three columns
// that start at different heights, with the text set as text, the photos as taped prints, the asides as pinned
// sheets, and under the columns the footer, where next time on its airmail envelope and the funds stand side by side.
// Beside it, a tray of pieces that stay off the page. Drag a piece to move it (on a touch screen, press and hold it
// first), or tap it and use its buttons; with the keyboard, arrows move it, 1 to 3 pick a column, 4 the footer and
// Delete takes it off the page. Every move saves at once, and Undo steps back.
// See sections.js for the rules.

import { store } from "../store.js";
import { I } from "../motion.js";
import { esc, toast, mkPills, hold } from "../ui.js";
import { patch } from "./common.js";
import { supportTotals } from "./money.js";
import { sectionsOf, withSections, resolve, auto, toLayout, words, thumbSrc, fillThumbs } from "./sections.js";

export const title = "Arrange";
export const parent = "letter";
export const back = (r) => `#/letter/${encodeURIComponent(r.id ?? "")}`;
export const kick = "Arrange the page";
export const cream = true;

const LANGS = [["nl", "Nederlands"], ["en", "English"]];
let lang = "nl";
let picked = null;            // the piece tapped last, whose buttons show; kept across redraws
const undo = new Map();       // letter id → earlier layouts, newest last

// The site's words for the parts of a letter (missions/site/content/*.json, paper.letter).
const WORDS = {
  nl: { issue: "Brief", prayers: "Gebedspunten", next: "Volgende keer", signup: "Krijg de volgende in je mailbox", locale: "nl-NL",
    funds: "Help me er te komen", fundsBody: "Staf bij YWAM krijgt geen salaris: ik leef van de steun van de mensen die me uitzenden.", progress: "{percent}% van mijn maandelijkse steun is rond", give: "Geef" },
  en: { issue: "Letter", prayers: "Prayer points", next: "Next time", signup: "Get the next one in your inbox", locale: "en-GB",
    funds: "Help me get there", fundsBody: "YWAM staff don’t get a salary: I live on the support of the people who send me.", progress: "{percent}% of my monthly support is in place", give: "Give" },
};

export function build(ctx) {
  const n = store.get("newsletters", ctx.id);
  if (!n) return `<div class="abs hand hi in">Gone</div><div class="sheet"><div class="rw"><div class="tx"><div class="t1">This letter is gone.</div></div></div></div>`;
  const { sections } = sectionsOf(n);
  const arr = resolve(n, sections);
  const name = (lang === "en" ? n.titleEn : n.title) || n.title || n.titleEn || "Untitled letter";
  const sub = (lang === "en" ? n.subtitleEn : n.subtitle) || "";
  const piece = card(n, sections);
  const texts = arr.columns.flat().filter((r) => r.startsWith("s:"));

  // What the site does to a piece because of where it stands (letters.js, arranged()): the first text opens with
  // the greeting, the last text ends with the mountains, a photo at the top of the first or second column gets the
  // traveller taking it, and every second thing in a column (text that follows text counts as one) leans the other way.
  const placed = (col, i) => {
    let at = 0;
    return col.map((r, k) => {
      const text = r.startsWith("s:");
      if (!(text && col[k - 1]?.startsWith("s:"))) at++;
      return piece(r, {
        hello: r === texts[0],
        end: r === texts[texts.length - 1],
        snap: r.startsWith("p:") && k === 0 && i < 2 && !arr.columns.slice(0, i).some((c) => c[0]?.startsWith("p:")),
        tilt: !text && r !== "next" && at % 2 === 0,
      });
    }).join("");
  };

  return `
    <div class="abs hand hi in">Arrange</div>
    <div class="abs in" style="left:22px;right:22px;top:146px"><div class="disp" style="font-size:54px;line-height:.9">${esc(name)}</div><div class="cap" style="margin:16px 0 0 2px">Drag the pieces where you want them. Each move saves straight away.</div></div>
    <div class="sheet"><div class="scroll arr" data-arr>
      <div class="arr-bar">
        <div class="pills tight" data-lang></div>
        <span class="arr-state" data-state>${arr.auto ? "Automatic for now" : "Arranged by you"}</span>
        <button class="btn o" data-undo ${undo.get(n.id)?.length ? "" : "disabled"}>${I.back}Undo</button>
        <button class="btn o" data-auto>Arrange for me</button>
      </div>
      <div class="arr-stage"><div class="arr-board">
        <div class="arr-page" aria-label="The page on hesent.me">
          <div class="arr-head">
            <div class="arr-headline">
              <h1 class="arr-title">${esc(name)}</h1>
              ${sub ? `<p class="arr-subtitle">${esc(sub)}</p>` : ""}
              ${meta(n) ? `<p class="arr-dateline">${esc(meta(n))}</p>` : ""}
              ${FLIGHT}
            </div>
            <div class="arr-zone arr-cover" data-zone="cover" aria-label="Cover photo">
              ${postmark(n)}${art("traveller-write", "arr-me arr-me--write")}
              ${arr.cover ? piece(`p:${arr.cover}`, { lead: true }) : ""}
              <p class="arr-empty">Drop a photo here to lead the letter</p>
            </div>
          </div>
          <div class="arr-cols">
            ${arr.columns.map((col, i) => `<div class="arr-zone arr-col arr-col--${i + 1}" data-zone="${i}" aria-label="Column ${i + 1}">${placed(col, i)}<p class="arr-empty">Drop pieces here</p></div>`).join("")}
          </div>
          <div class="arr-zone arr-footer" data-zone="footer" aria-label="Footer">${placed(arr.footer, 3)}<p class="arr-empty">Drop pieces here to close the letter with them, side by side</p></div>
        </div>
        <div class="arr-tray">
          <div class="arr-tray-top">Not on the page</div>
          <div class="arr-zone" data-zone="off" aria-label="Not on the page">${arr.off.map((r) => piece(r)).join("")}<p class="arr-empty">Drag a piece here to leave it out. It stays in your letter.</p></div>
        </div>
      </div></div>
      <p class="empty-note arr-help">On a phone, press and hold a piece to drag it, or tap it for its buttons. With a keyboard: Tab to a piece, arrows to move it, 1–3 for a column, 4 for the footer, Delete to take it off the page.</p>
    </div></div>`;
}

const textOf = (s) => (s ? (lang === "en" ? s.bodyEn : s.body) || "" : "");
const art = (name, cls) => `<img class="arr-art ${cls}" src="assets/art/${name}.webp" alt="" draggable="false">`;
const dayOf = (iso) => new Date(`${iso.slice(0, 10)}T00:00:00Z`);

// "Brief 3 · 20 oktober 2026 · Queenstown, NZ", the line under the headline.
function meta(n) {
  const W = WORDS[lang];
  const day = n.sentAt ? new Intl.DateTimeFormat(W.locale, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" }).format(dayOf(n.sentAt)) : "";
  return [n.number && `${W.issue} ${n.number}`, day, n.place].filter(Boolean).join(" · ");
}

// The postmark on the cover's corner, as on the site: the place and number round the ring, the day in the middle.
function postmark(n) {
  const ring = [n.place, n.number && `${WORDS[lang].issue} ${n.number}`].filter(Boolean).join(" · ");
  let day = "";
  if (n.sentAt) {
    const d = dayOf(n.sentAt);
    const mon = new Intl.DateTimeFormat(WORDS[lang].locale, { month: "short", timeZone: "UTC" }).format(d).replace(".", "");
    day = `<text class="arr-pm-day" x="60" y="62" text-anchor="middle">${d.getUTCDate()}</text><text class="arr-pm-month" x="60" y="77" text-anchor="middle">${esc(mon)} ${d.getUTCFullYear()}</text>`;
  }
  return `<svg class="arr-postmark" viewBox="0 0 196 120" aria-hidden="true">
    <defs><path id="arr-pm-ring" d="M60 60m-42 0a42 42 0 1 1 84 0a42 42 0 1 1-84 0"/></defs>
    <circle cx="60" cy="60" r="55"/><circle cx="60" cy="60" r="33"/>
    ${ring ? `<text class="arr-pm-ring"><textPath href="#arr-pm-ring" textLength="258" lengthAdjust="spacingAndGlyphs">${esc(ring.toUpperCase())} ·</textPath></text>` : ""}
    ${day}
    <path class="arr-pm-waves" d="M110 40q9-7 18 0t18 0 18 0 18 0M116 60q9-7 18 0t18 0 18 0 18 0M110 80q9-7 18 0t18 0 18 0 18 0"/>
  </svg>`;
}

// The drawings from the site (missions/site/src/page.mjs): the plane, the candle, the stamp and the envelope icon.
const PLANE = "M0.408 -0.082 A0.082 0.082 0 0 1 0.408 0.082 L0.112 0.082 L-0.087 0.413 Q-0.112 0.459 -0.163 0.459 L-0.179 0.459 Q-0.235 0.459 -0.219 0.403 L-0.143 0.082 L-0.306 0.082 L-0.383 0.204 Q-0.403 0.235 -0.439 0.235 Q-0.49 0.235 -0.48 0.184 L-0.449 0 L-0.48 -0.184 Q-0.49 -0.235 -0.439 -0.235 Q-0.403 -0.235 -0.383 -0.204 L-0.306 -0.082 L-0.143 -0.082 L-0.219 -0.403 Q-0.235 -0.459 -0.179 -0.459 L-0.163 -0.459 Q-0.112 -0.459 -0.087 -0.413 L0.112 -0.082 Z";
const FLIGHT = `<svg class="arr-flight" viewBox="0 0 340 96" aria-hidden="true">
  <path class="arr-flight-path" d="M6 78C46 82 78 64 96 44c18-20 4-38-12-30-18 9-6 44 34 50 46 7 92-26 170-38"/>
  <path class="arr-flight-plane" d="${PLANE}" transform="translate(312 24) rotate(-18) scale(30)"/>
</svg>`;
const CANDLE = `<svg class="arr-mark" viewBox="0 0 24 24" aria-hidden="true"><path d="M8.5 20.5h7"/><path d="M10 20.5v-8h4v8"/><path class="arr-mark-flame" d="M12 9.5c-1.7-1.3-1.7-3.3 0-6 1.7 2.7 1.7 4.7 0 6Z"/></svg>`;
const STAMP = `<svg class="arr-stamp" viewBox="0 0 44 52" aria-hidden="true"><path class="arr-stamp-edge" d="M2 2h40v48H2Z"/><path class="arr-stamp-sky" d="M7 7h30v31H7Z"/><path class="arr-stamp-peak" d="m7 38 10-15 5 6 5-8 10 17Z"/><path class="arr-stamp-snow" d="m14.5 26.7 2.5-3.7 2.2 2.6M24.6 24.6 27 21l3 5"/></svg>`;
const MAIL = `<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="5.5" width="18" height="13" rx="1.5"/><path d="m3.5 6.5 8.5 6.5 8.5-6.5"/></svg>`;
const ARROW = `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>`;
const PLANE_ICON = `<svg viewBox="-0.55 -0.5 1.1 1" aria-hidden="true"><path d="${PLANE}" transform="rotate(-8)"/></svg>`;

// A section's text as the site sets it (letters.js, sections()): paragraphs, ## headings, ### subheadings, lists,
// > quotes, **bold**, *italic* and links, everything escaped first. A short first line is the greeting.
const inline = (t) => esc(t)
  .replace(/\[([^\]]+)\]\(((?:https?:\/\/|mailto:)[^)\s]+)\)/g, "<u>$1</u>")
  .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
  .replace(/(^|[^*])\*([^*\n]+)\*/g, "$1<em>$2</em>")
  .replace(/\n/g, "<br>");
function setText(md, hello) {
  const out = [];
  const paras = md.replace(/\r/g, "").replace(/^[ \t]*(#{1,3})[ \t]*(\S.*)$/gm, "\n$1 $2\n").split(/\n\s*\n/);
  for (const raw of paras) {
    const b = raw.trim();
    if (!b || /^(!\[[^\]]*\]\([^)]*\)|-{3,}|\*{3,})$/.test(b)) continue;
    const h = b.match(/^(#{1,3}) (.+)$/);
    if (h) { out.push(h[1].length < 3 ? `<h2>${inline(h[2])}</h2>` : `<h3>${inline(h[2])}</h3>`); continue; }
    const lines = b.split("\n");
    if (lines.every((l) => /^\s*[-*]\s+/.test(l))) out.push(`<ul>${lines.map((l) => `<li>${inline(l.replace(/^\s*[-*]\s+/, ""))}</li>`).join("")}</ul>`);
    else if (lines.every((l) => /^\s*\d+[.)]\s+/.test(l))) out.push(`<ol>${lines.map((l) => `<li>${inline(l.replace(/^\s*\d+[.)]\s+/, ""))}</li>`).join("")}</ol>`);
    else if (lines.every((l) => /^>/.test(l))) out.push(`<blockquote><p>${inline(lines.map((l) => l.replace(/^>\s?/, "")).join("\n"))}</p></blockquote>`);
    else out.push(`<p${hello && !out.length && words(b) <= 8 ? ' class="arr-hello"' : ""}>${inline(b)}</p>`);
  }
  return out.join("");
}

// A piece as the site draws it, in a card that can be picked up. The card itself stays straight, so the outline
// when it is picked and its buttons don't lean with the print or sheet inside it.
function card(n, sections) {
  const photos = new Map((n.photos ?? []).map((p) => [p.id, p]));
  const other = lang === "en" ? "Only in Dutch so far" : "Only in English so far";
  const W = WORDS[lang];
  const acts = (isPhoto) => `<div class="arr-acts" role="group" aria-label="Move">
    <button data-to="0">1</button><button data-to="1">2</button><button data-to="2">3</button><button data-to="footer">Footer</button>
    ${isPhoto ? `<button data-to="cover">Cover</button>` : ""}<button data-to="off">Off</button>
    <button data-step="-1" aria-label="Up">${I.back}</button><button data-step="1" aria-label="Down">${I.back}</button>
  </div>`;
  return (ref, o = {}) => {
    const on = picked === ref ? " on" : "";
    const shell = (kind, label, inner) =>
      `<div class="arr-card arr-card--${kind}${on}${o.tilt ? " is-tilted" : ""}" data-ref="${esc(ref)}" data-kind="${kind}" tabindex="0" aria-label="${esc(label)}">${inner}${acts(kind === "photo")}</div>`;
    if (ref.startsWith("s:")) {
      const s = sections.find((x) => `s:${x.id}` === ref);
      const title = lang === "en" ? s.titleEn : s.title;
      const body = textOf(s);
      const text = setText([title && `## ${title}`, body].filter(Boolean).join("\n\n"), o.hello);
      return shell("text", title || "Section without a heading",
        `<div class="arr-in arr-text">${text}${body ? "" : `<p class="arr-other">${esc(other)}</p>`}${o.end ? art("mountains", "arr-end") : ""}</div>`);
    }
    if (ref.startsWith("p:")) {
      const p = photos.get(ref.slice(2));
      const cap = lang === "en" ? p.captionEn : p.caption;
      const ratio = p.width && p.height ? `${p.width} / ${p.height}` : "4 / 3";
      const src = thumbSrc(p.id);
      const print = `<figure class="arr-in arr-print${o.lead ? " arr-print--lead" : ""}"><img alt="" draggable="false" data-thumb="${esc(p.id)}" style="aspect-ratio:${ratio}" ${src ? `src="${src}"` : ""}>${cap ? `<figcaption>${esc(cap)}</figcaption>` : ""}</figure>`;
      return shell("photo", cap || "Photo", o.snap ? `<div class="arr-snap">${print}${art("traveller-photo", "arr-me arr-me--photo")}</div>` : print);
    }
    if (ref === "prayers") {
      const list = (lang === "en" ? n.prayersEn : n.prayers) ?? [];
      return shell("aside", W.prayers, `<div class="arr-in arr-aside arr-aside--prayers"><h2>${esc(W.prayers)}</h2>${list.length ? `<ul>${list.map((t) => `<li>${CANDLE}<p>${esc(t)}</p></li>`).join("")}</ul>` : `<p class="arr-other">${esc(other)}</p>`}</div>`);
    }
    if (ref === "note") {
      const t = lang === "en" ? n.noteEn : n.note;
      return shell("aside", "Side note", `<div class="arr-in arr-aside arr-aside--note">${art("flower-pink", "arr-flower")}${t ? `<p class="arr-quote">${esc(t)}</p><p class="arr-sign">Ruben</p>` : `<p class="arr-other">${esc(other)}</p>`}</div>`);
    }
    if (ref === "funds") {
      const t = (lang === "en" ? n.fundsEn : n.funds) || W.fundsBody;
      const { pct, target } = supportTotals();
      const route = target ? `<p class="arr-funds-pct">${esc(W.progress.replace("{percent}", pct))}</p><div class="arr-route" style="--progress:${Math.min(Math.max(pct, 0), 100)}"><i></i>${PLANE_ICON}</div>` : "";
      return shell("aside", "Funds", `<div class="arr-in arr-aside arr-aside--funds"><h2>${esc(W.funds)}</h2><p>${esc(t)}</p>${route}<span class="arr-button">${esc(W.give)} ${ARROW}</span></div>`);
    }
    const t = lang === "en" ? n.nextTimeEn : n.nextTime;
    return shell("next", "Next time and sign-up", `<div class="arr-in arr-foot"><div class="arr-envelope">${STAMP}${t ? `<h2>${esc(W.next)}</h2><p>${esc(t)}</p>` : ""}<span class="arr-button">${esc(W.signup)} ${MAIL}</span></div>${art("traveller-post", "arr-me arr-me--post")}</div>`);
  };
}

export function init(el, ctx) {
  const n = store.get("newsletters", ctx.id);
  if (!n) return;
  const id = n.id;
  const current = () => store.get("newsletters", id);
  const board = el.querySelector(".arr-board");

  // A letter written before sections gets them from its body, once, so its pieces have ids to arrange.
  const first = sectionsOf(n);
  if (first.changed) patch("newsletters", id, withSections(first.sections));

  mkPills(el.querySelector("[data-lang]"), LANGS, lang, (to) => { lang = to; ctx.refresh(); });
  fillThumbs(el);

  // ---------- reading and saving the board ----------
  const zone = (name) => board.querySelector(`[data-zone="${name}"]`);
  const refsIn = (z) => [...z.querySelectorAll(":scope > .arr-card")].map((c) => c.dataset.ref);
  const read = () => ({
    cover: refsIn(zone("cover"))[0]?.slice(2) ?? null,
    columns: [0, 1, 2].map((i) => refsIn(zone(i))),
    footer: refsIn(zone("footer")),
    off: refsIn(zone("off")),
  });
  const save = async (layout, message) => {
    const before = current().layout ? toLayout(resolve(current(), sectionsOf(current()).sections)) : null;
    const stack = undo.get(id) ?? [];
    stack.push(before);
    undo.set(id, stack.slice(-40));
    try {
      await patch("newsletters", id, { layout });
      if (message) toast(message);
    } catch (err) {
      toast(err.message || "That didn't save.", { bad: true });
    }
    ctx.refresh();
  };
  const commit = () => save(toLayout(read()));

  el.querySelector("[data-undo]").addEventListener("click", undoLast);
  el.querySelector("[data-auto]").addEventListener("click", () => {
    save(toLayout(auto(current(), sectionsOf(current()).sections)), "Arranged like hesent.me would. Undo brings yours back.");
  });
  function undoLast() {
    const stack = undo.get(id);
    if (!stack?.length) return;
    const layout = stack.pop();
    patch("newsletters", id, { layout }).then(() => { toast("Undone"); ctx.refresh(); });
  }
  const onKey = (e) => {
    if (!el.isConnected) return document.removeEventListener("keydown", onKey);
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "z" && !/INPUT|TEXTAREA/.test(document.activeElement?.tagName)) { e.preventDefault(); undoLast(); }
  };
  document.addEventListener("keydown", onKey);

  // ---------- moving a piece by its buttons or the keyboard ----------
  // Cover takes one photo: one that is there already goes where the new one came from.
  function place(c, to, index = Infinity) {
    const from = c.parentElement;
    const target = zone(to);
    if (to === "cover") {
      const old = target.querySelector(":scope > .arr-card");
      if (old && old !== c) from.insertBefore(old, c);
    }
    const cards = [...target.querySelectorAll(":scope > .arr-card")].filter((x) => x !== c);
    target.insertBefore(c, cards[index] ?? target.querySelector(":scope > .arr-empty"));
  }
  const move = (c, how) => {
    const ref = c.dataset.ref;
    const moved = flip(() => {
      if (how.step) {
        const z = c.parentElement;
        const cards = [...z.querySelectorAll(":scope > .arr-card")];
        const i = cards.indexOf(c) + how.step;
        if (i < 0 || i >= cards.length) return false;
        place(c, z.dataset.zone, i);
      } else {
        if (how.to === "cover" && c.dataset.kind !== "photo") return false;
        place(c, how.to);
      }
    });
    picked = ref;
    if (moved) commit();
  };
  board.addEventListener("click", (e) => {
    const b = e.target.closest(".arr-acts button");
    const c = e.target.closest(".arr-card");
    if (b && c) {
      e.stopPropagation();
      return move(c, b.dataset.step ? { step: +b.dataset.step } : { to: b.dataset.to });
    }
    if (!c || dragged) return;
    picked = picked === c.dataset.ref ? null : c.dataset.ref;
    board.querySelectorAll(".arr-card").forEach((x) => x.classList.toggle("on", x.dataset.ref === picked));
  });
  board.addEventListener("keydown", (e) => {
    const c = e.target.closest?.(".arr-card");
    if (!c || e.target !== c) return;
    const go = { ArrowUp: { step: -1 }, ArrowDown: { step: 1 }, 1: { to: "0" }, 2: { to: "1" }, 3: { to: "2" }, 4: { to: "footer" }, Delete: { to: "off" }, Backspace: { to: "off" } }[e.key];
    if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
      const order = ["cover", "0", "1", "2", "footer", "off"];
      let i = order.indexOf(c.parentElement.dataset.zone) + (e.key === "ArrowLeft" ? -1 : 1);
      if (order[i] === "cover" && c.dataset.kind !== "photo") i += e.key === "ArrowLeft" ? -1 : 1;
      if (!order[i]) return;
      e.preventDefault();
      return move(c, { to: order[i] });
    }
    if (e.key === "Enter" || e.key === " ") { e.preventDefault(); c.click(); return; }
    if (!go) return;
    e.preventDefault();
    move(c, go);
  });
  // After a redraw the piece that moved keeps the focus, so the keyboard can carry on.
  if (picked) board.querySelector(`.arr-card[data-ref="${CSS.escape(picked)}"]`)?.focus({ preventScroll: true });

  // ---------- dragging ----------
  // With a mouse a card drags as soon as it moves. On a touch screen it is pressed and held first, so a swipe still
  // scrolls the page; once it is lifted the page stops scrolling under the finger.
  // The card itself moves through the board as the placeholder, and a copy follows the pointer.
  let dragged = null;
  const noScroll = (e) => {
    if (!el.isConnected) return window.removeEventListener("touchmove", noScroll);
    if (dragged) e.preventDefault();
  };
  window.addEventListener("touchmove", noScroll, { passive: false });
  board.addEventListener("contextmenu", (e) => { if (e.target.closest(".arr-card")) e.preventDefault(); });
  board.addEventListener("pointerdown", (e) => {
    const c = e.target.closest(".arr-card");
    if (!c || e.button !== 0 || e.target.closest(".arr-acts")) return;
    const touch = e.pointerType !== "mouse";
    const start = { x: e.clientX, y: e.clientY };
    let drag = null, last = e;
    const timer = touch && setTimeout(() => { drag = lift(c, last); navigator.vibrate?.(8); }, 380);
    const onMove = (ev) => {
      last = ev;
      if (!drag) {
        const far = Math.hypot(ev.clientX - start.x, ev.clientY - start.y);
        if (touch) { if (far > 8) end(ev); return; }
        if (far < 6) return;
        drag = lift(c, ev);
      }
      ev.preventDefault();
      drag.move(ev);
    };
    const end = (ev) => {
      clearTimeout(timer);
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", end);
      window.removeEventListener("pointercancel", end);
      if (drag) drag.drop(ev.type === "pointercancel");
    };
    window.addEventListener("pointermove", onMove, { passive: false });
    window.addEventListener("pointerup", end);
    window.addEventListener("pointercancel", end);
  });

  function lift(c, ev) {
    hold.on = true;
    dragged = c;
    const home = { zone: c.parentElement, next: c.nextElementSibling };
    const r = c.getBoundingClientRect();
    const off = { x: ev.clientX - r.left, y: ev.clientY - r.top };
    const ghost = c.cloneNode(true);
    ghost.classList.add("arr-ghost");
    ghost.classList.remove("on");
    ghost.style.width = `${r.width}px`;
    ghost.style.fontSize = getComputedStyle(c).fontSize;
    document.body.append(ghost);
    c.classList.add("is-lifted");
    board.classList.add("is-dragging");
    const scroller = scrollParent(board);
    let last = ev, raf = 0;
    const isPhoto = c.dataset.kind === "photo";
    board.querySelector('[data-zone="cover"]').classList.toggle("is-closed", !isPhoto);

    const at = (x, y) => {
      ghost.style.transform = `translate(${x - off.x}px, ${y - off.y}px) rotate(1.5deg)`;
      const under = document.elementFromPoint(x, y)?.closest?.("[data-zone]");
      board.querySelectorAll(".arr-zone").forEach((z) => z.classList.toggle("is-over", z === under));
      if (!under || !board.contains(under) || (under.dataset.zone === "cover" && !isPhoto)) return;
      const cards = [...under.querySelectorAll(":scope > .arr-card")].filter((x2) => x2 !== c);
      const i = cards.findIndex((x2) => { const b = x2.getBoundingClientRect(); return y < b.top + b.height / 2; });
      const before = i < 0 ? under.querySelector(":scope > .arr-empty") : cards[i];
      if (under.dataset.zone === "cover") {
        if (c.parentElement !== under) flip(() => under.insertBefore(c, under.firstChild));
        return;
      }
      if (c.parentElement === under && (c.nextElementSibling === before || before === c)) return;
      flip(() => under.insertBefore(c, before));
    };
    // Near the top or bottom of the screen the page scrolls along.
    const tick = () => {
      const h = window.innerHeight, edge = 70;
      const dy = last.clientY < edge ? -(edge - last.clientY) / 4 : last.clientY > h - edge ? (last.clientY - (h - edge)) / 4 : 0;
      if (dy && scroller) { scroller.scrollTop += dy; at(last.clientX, last.clientY); }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    at(ev.clientX, ev.clientY);

    return {
      move(e) { last = e; at(e.clientX, e.clientY); },
      drop(cancelled) {
        cancelAnimationFrame(raf);
        if (cancelled) home.zone.insertBefore(c, home.next);
        // A photo dropped on a cover that has one swaps with it.
        const cover = zone("cover");
        const covers = [...cover.querySelectorAll(":scope > .arr-card")];
        if (covers.length > 1) home.zone.insertBefore(covers.find((x) => x !== c), home.next);
        const to = c.getBoundingClientRect();
        const anim = ghost.animate([{ transform: ghost.style.transform }, { transform: `translate(${to.left}px, ${to.top}px)` }], { duration: 180, easing: "cubic-bezier(.2,.8,.2,1)" });
        anim.onfinish = () => {
          ghost.remove();
          c.classList.remove("is-lifted");
          board.classList.remove("is-dragging");
          board.querySelectorAll(".arr-zone").forEach((z) => z.classList.remove("is-over", "is-closed"));
          hold.on = false;
          setTimeout(() => { dragged = null; }, 0);
          const moved = home.zone !== c.parentElement || home.next !== c.nextElementSibling;
          picked = c.dataset.ref;
          if (moved && !cancelled) commit();
        };
      },
    };
  }
}

/** Runs a change to the board and slides every card from where it was to where it lands. False: nothing changed. */
function flip(change) {
  const cards = [...document.querySelectorAll(".arr-board .arr-card:not(.is-lifted)")];
  const before = new Map(cards.map((c) => [c, c.getBoundingClientRect()]));
  if (change() === false) return false;
  if (matchMedia("(prefers-reduced-motion: reduce)").matches) return true;
  for (const c of cards) {
    const a = before.get(c), b = c.getBoundingClientRect();
    const dx = a.left - b.left, dy = a.top - b.top;
    if (dx || dy) c.animate([{ transform: `translate(${dx}px, ${dy}px)` }, { transform: "none" }], { duration: 200, easing: "cubic-bezier(.2,.8,.2,1)" });
  }
  return true;
}

function scrollParent(el) {
  for (let p = el.parentElement; p; p = p.parentElement) {
    const o = getComputedStyle(p).overflowY;
    if ((o === "auto" || o === "scroll") && p.scrollHeight > p.clientHeight) return p;
  }
  return document.scrollingElement;
}
