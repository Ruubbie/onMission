// The home page of one language: its sections and the helpers every page shares. Copy lives in ../content/*.json;
// this file is structure only. The head, header and footer are in shell.mjs.
// Styles: public/assets/tokens.css (values), components.css (parts), site.css (this page).
// Illustrations: public/assets/art/*.webp (cut-outs), the logo in public/assets/logo-*.webp.

import { existsSync } from "node:fs";

export const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
export const fill = (text, values) => text.replace(/\{(\w+)\}/g, (_, k) => values[k] ?? "");

// A heading from the copy, with the words between *stars* set on a highlighter pill in the section's colour,
// and optionally a doodle stuck to the pill (see sticker()): hanging under its end, or on its top corner where a
// line of the heading runs on underneath. The pill and the punctuation after it stay on one line.
export const hl = (s, kind, top = false) => esc(s).replace(/\*(.+?)\*(\S*)/g, (_, words, after) =>
  `<span class="hl-keep"><mark class="hl">${words}${kind ? sticker(kind, top) : ""}</mark>${after}</span>`);

// The plane, as drawn on the globe: pointing right, centred on 0,0.
export const planePath =
  "M0.408 -0.082 A0.082 0.082 0 0 1 0.408 0.082 L0.112 0.082 L-0.087 0.413 Q-0.112 0.459 -0.163 0.459 L-0.179 0.459 Q-0.235 0.459 -0.219 0.403 L-0.143 0.082 L-0.306 0.082 L-0.383 0.204 Q-0.403 0.235 -0.439 0.235 Q-0.49 0.235 -0.48 0.184 L-0.449 0 L-0.48 -0.184 Q-0.49 -0.235 -0.439 -0.235 Q-0.403 -0.235 -0.383 -0.204 L-0.306 -0.082 L-0.143 -0.082 L-0.219 -0.403 Q-0.235 -0.459 -0.179 -0.459 L-0.163 -0.459 Q-0.112 -0.459 -0.087 -0.413 L0.112 -0.082 Z";

export const icon = {
  mail: '<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="5.5" width="18" height="13" rx="1.5"/><path d="m3.5 6.5 8.5 6.5 8.5-6.5"/></svg>',
  arrow: '<svg class="icon icon--arrow" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 12h15"/><path d="m14 7 5 5-5 5"/></svg>',
  copy: '<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><rect x="8.5" y="8.5" width="11" height="11" rx="1.5"/><path d="M15.5 5.5v-1a1 1 0 0 0-1-1h-9a1 1 0 0 0-1 1v9a1 1 0 0 0 1 1h1"/></svg>',
  plane: `<svg viewBox="-0.55 -0.5 1.1 1" aria-hidden="true"><path d="${planePath}" transform="rotate(-8)"/></svg>`,
};

// The top of the footer: an inked range of peaks with a few strokes of snow. Stretches to any width.
export const ridge = `<svg viewBox="0 0 1440 160" preserveAspectRatio="none" aria-hidden="true" focusable="false">
  <path class="range" d="M0 160V118l60-6 60-16 50 8 70-34 45 18 45-28 50 24 50 16 70-8 60-34 40 16 50-44 50 36 40-12 50 26 70 16 70-10 60-36 40 14 50-42 40 26 50-8 50 32 70 20 60-8 50 16 40-4v64Z"/>
  <path class="snow" d="M634 50 650 34l12 16 10-6M1064 42l16-16 14 18 10-6M978 64l12-10 10 10M546 74l14-12 12 12M318 76l12-12 10 10"/>
</svg>`;

export const img = (src, cls, w, h, alt = "") =>
  `<img class="${cls}" src="/assets/${src}" alt="${esc(alt)}" width="${w}" height="${h}" loading="lazy" decoding="async">`;

// On the home page the links jump to the sections. Elsewhere they lead back to them, except Letters, which goes to
// the letters front page. The link the page belongs under (page.current: Letters on the letter pages, Get involved
// on the giving page) is marked as the current one.
export function nav(c, page) {
  return c.nav.items.map((it) => {
    const toLetters = !!page && it.id === c.letters.id;
    const href = toLetters ? lettersHref(c) : `${page ? `/${c.lang}/` : ""}#${it.id}`;
    return `<a href="${esc(href)}"${page?.current === it.id ? ' aria-current="true"' : ""}>${esc(it.label)}</a>`;
  }).join("");
}

export const lettersHref = (c) => `/${c.lang}/${c.paper.index.slug}/`;
export const letterHref = (c) => `/${c.lang}/${c.paper.letter.slug}/`;
export const givingHref = (c) => `/${c.lang}/${c.giving.slug}/`;

// The language switch links to the same page in both languages. site.js stores the choice in a cookie, which the Worker reads.
export function langSwitch(c, paths = { nl: "/nl/", en: "/en/" }) {
  const link = (lang, label) => `<a href="${paths[lang]}" hreflang="${lang}" data-lang="${lang}"${c.lang === lang ? ' aria-current="true"' : ""}>${label}</a>`;
  return `<div class="lang-switch" role="group" aria-label="${esc(c.footer.language)}">${link("nl", "Nederlands")}${link("en", "English")}</div>`;
}

// The flags for the header's language button, drawn on a disc.
const flag = {
  nl: '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="var(--color-flag-red)" d="M0 0h24v8H0Z"/><path fill="var(--color-paper)" d="M0 8h24v8H0Z"/><path fill="var(--color-flag-blue)" d="M0 16h24v8H0Z"/></svg>',
  en: '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="var(--color-flag-blue)" d="M0 0h24v24H0Z"/><path stroke="var(--color-paper)" stroke-width="5" d="m0 0 24 24M24 0 0 24"/><path stroke="var(--color-flag-red)" stroke-width="1.6" d="m0 0 24 24M24 0 0 24"/><path stroke="var(--color-paper)" stroke-width="8" d="M12 0v24M0 12h24"/><path stroke="var(--color-flag-red)" stroke-width="4.5" d="M12 0v24M0 12h24"/></svg>',
};

// The header's language button: the other language's flag in an inked ring, taking you to the same page in that language.
export function langButton(c, paths = { nl: "/nl/", en: "/en/" }) {
  const to = c.lang === "nl" ? "en" : "nl";
  const name = to === "nl" ? "Nederlands" : "English";
  return `<a class="button lang-button" href="${paths[to]}" hreflang="${to}" lang="${to}" data-lang="${to}" aria-label="${name}" title="${name}"><span class="flag">${flag[to]}</span></a>`;
}

// The chapter marks: one small drawing per chapter, picked by its "icon" in the copy. Every stroke has
// pathLength 1 so site.css can draw it in; the part named in class moves gently once it is drawn.
const marks = {
  place: '<path d="M3 17.5 8.5 10l3 4 3.5-5.5 6 9"/><path class="mark__move" d="M5 20.5c1.5-1 3-1 4.5 0s3 1 4.5 0 3-1 4.5 0"/>',
  people: '<circle class="mark__move" cx="9" cy="8" r="2.7"/><path d="M4 19.5c0-3 2.2-5.2 5-5.2s5 2.2 5 5.2"/><circle class="mark__move mark__move--late" cx="16.5" cy="9" r="2.2"/><path d="M15.4 14.4c2.5-.3 4.6 1.7 4.6 4.6"/>',
  plan: '<path d="M3.5 20.5c4.5 0 4-5.5 8.5-5.5s4-5 6.5-5"/><path d="M18.5 10V3"/><path class="mark__move" d="M18.5 3.5h3.5l-1.2 1.8 1.2 1.8h-3.5"/>',
  team: '<path class="mark__move" d="M12 20s-7.5-4.6-7.5-10A4 4 0 0 1 12 7.6 4 4 0 0 1 19.5 10c0 5.4-7.5 10-7.5 10Z"/>',
  // The journey's stops: the list ticks, the paper plane drifts, the heart in the house beats.
  pack: '<path d="M6.5 4.5H5v16h14v-16h-1.5"/><path d="M9 3h6v3H9Z"/><path d="M8.5 10.5h7"/><path d="M8.5 14h3.5"/><path class="mark__move" d="m13.5 16.5 1.8 1.8 3.7-4.3"/>',
  fly: '<path class="mark__move" d="M3 11.5 21 4l-5.5 16-4-6.5Z"/><path d="M11.5 13.5 21 4"/><path d="M3.5 19.5c2 0 3.3-.8 4.5-2.3"/>',
  serve: '<path d="M3.5 11.5 12 4.5l8.5 7"/><path d="M6 9.5V20h12V9.5"/><path class="mark__move" d="M12 17.5s-3-1.8-3-3.9a1.5 1.5 0 0 1 3-.6 1.5 1.5 0 0 1 3 .6c0 2.1-3 3.9-3 3.9Z"/>',
  // The letters: the envelope flap lifts, the candle flickers, the lens focuses, the date ticks.
  letter: '<path d="M3.5 7.5h17v11h-17Z"/><path class="mark__move" d="m3.5 7.5 8.5 6.5 8.5-6.5"/>',
  pray: '<path d="M8.5 20.5h7"/><path d="M10 20.5v-8h4v8"/><path class="mark__move" d="M12 9.5c-1.7-1.3-1.7-3.3 0-6 1.7 2.7 1.7 4.7 0 6Z"/>',
  photo: '<path d="M3.5 8.5h4L9 6h6l1.5 2.5h4v10.5h-17Z"/><circle class="mark__move" cx="12" cy="13.5" r="3.2"/>',
  month: '<path d="M4 6.5h16V20H4Z"/><path d="M4 10.5h16"/><path d="M8.5 4v4M15.5 4v4"/><path class="mark__move" d="m9.5 15.3 1.8 1.8 3.4-3.6"/>',
  // Get involved: a coin drops into the jar, the lid lifts off the gift, a reply pops up beside the message.
  monthly: '<path d="M6.5 9h11v9.5a2 2 0 0 1-2 2h-7a2 2 0 0 1-2-2Z"/><path d="M9.5 9V7h5v2"/><path d="M9.5 16.5h5"/><circle class="mark__move" cx="12" cy="3.6" r="1.6"/>',
  once: '<path d="M5.5 11.5h13v9h-13Z"/><path d="M12 11.5v9"/><path class="mark__move" d="M4.5 8h15v3.5h-15Z"/><path class="mark__move" d="M12 8c-.8-2.6-4-3.2-4-1.4S10.2 8 12 8c1.8 0 4-.2 4-1.4S12.8 5.4 12 8Z"/>',
  share: '<path d="M3.5 4.5h11v7.5h-6l-3 2.5V12h-2Z"/><path class="mark__move" d="M17 8.5h3.5V16h-2v2.5l-3-2.5H10v-1.5"/>',
};
export const mark = (name, cls = "chapter__mark") =>
  `<svg class="${cls} mark--${name}" viewBox="0 0 24 24" aria-hidden="true" focusable="false">${(marks[name] ?? "").replace(/<(path|circle)/g, '<$1 pathLength="1"')}</svg>`;

// The doodles stuck to the highlighter pills: one per heading, drawn in ink like the chapter marks (every stroke
// has pathLength 1, so site.css can draw them in) and filled in one of the four colours. The paper plane flies
// out past the full stop on a dashed loop.
const doodles = {
  heart: '<path class="sticker__fill" d="M24 40S7 30 7 18a8.5 8.5 0 0 1 17-2 8.5 8.5 0 0 1 17 2c0 12-17 22-17 22Z"/>',
  star: '<path class="sticker__fill" d="m24 5 5.6 12 13 1.4-9.8 8.8 2.8 12.8L24 33.4 12.4 40l2.8-12.8-9.8-8.8 13-1.4Z"/>',
  sparkle: '<path class="sticker__fill" d="M24 5c1.6 10.5 4.3 13.4 15 19-10.7 5.6-13.4 8.5-15 19-1.6-10.5-4.3-13.4-15-19 10.7-5.6 13.4-8.5 15-19Z"/>',
  plane: '<path class="sticker__trail" d="M4 50C24 50 30 34 46 34s16 14 6 16-10-14 12-22 40-6 60-14"/>' +
    '<g transform="translate(132 14) rotate(-14) scale(.9) translate(-24 -24)"><path class="sticker__fill" d="M5 22 43 7 33 41l-9.5-11.5Z"/><path d="M23.5 29.5 43 7"/><path d="m23.5 29.5-1 9 5-4.6"/></g>',
};
const sticker = (kind, top) =>
  `<span class="sticker sticker--${kind}${top ? " sticker--top" : ""}" aria-hidden="true"><svg viewBox="${kind === "plane" ? "0 -10 158 66" : "0 0 48 48"}" focusable="false">` +
  `${doodles[kind].replace(/<path(?![^>]*class="sticker__fill")(?![^>]*class="sticker__trail")/g, '<path pathLength="1"')}</svg></span>`;

// The traveller from the hero, along the way in other poses, each standing on something: peeking over the vision
// card in My story, walking the flight path from where I am now, sitting on the letter card writing one, and
// waving goodbye from a peak of the ridge above the footer (shell.mjs). A pose shows once its drawing is in public/assets/art/traveller-<pose>.webp.
// Until the peeking one is there, My story crops the hero's drawing to his head and shoulders.
const hasArt = (file) => existsSync(new URL(`../public/assets/art/${file}`, import.meta.url));
const poseSize = { peek: [440, 297], walk: [360, 719], write: [400, 448], wave: [360, 829] };
export function pose(name) {
  const [w, h] = poseSize[name];
  if (hasArt(`traveller-${name}.webp`))
    return `<img class="pose pose--${name}" src="/assets/art/traveller-${name}.webp" alt="" width="${w}" height="${h}" loading="lazy" decoding="async">`;
  if (name === "peek")
    return `<span class="pose pose--peek pose--crop"><img src="/assets/art/traveller.webp" alt="" width="544" height="908" loading="lazy" decoding="async"></span>`;
  return "";
}

// My story: the intro and the one-sentence vision on the left, four chapters with a drawn mark each, joined
// by the dashed flight path, on the right (stacked on a phone).
function story(c, departure) {
  const s = c.story;
  const chapters = s.chapters
    .map((ch) => `<li class="chapter">
          ${mark(ch.icon)}
          <h3 class="chapter__title">${esc(ch.title)}</h3>
          <p>${esc(ch.body)}</p>
        </li>`)
    .join("\n        ");
  return `<section class="section story" id="${esc(s.id)}" aria-labelledby="${esc(s.id)}-title">
    <div class="container story__inner">
      <div class="story__intro">
        <h2 class="section__title" id="${esc(s.id)}-title">${hl(s.title, "star", true)}</h2>
        <p class="story__lede">${esc(fill(s.lede, { departure }))}</p>
        <figure class="story__vision">
          ${pose("peek")}
          ${img("art/flower-sage.webp", "art story__flower", 112, 120)}
          <blockquote><p>${esc(s.vision)}</p></blockquote>
        </figure>
      </div>
      <div class="story__path">
        <ol class="story__chapters">
        ${chapters}
        </ol>
        <a class="button story__cta" href="#${esc(s.target)}">${esc(s.cta)} ${icon.arrow}</a>
      </div>
    </div>
  </section>`;
}

// The journey: the heading and lede beside the packed suitcase and its countdown tag, then the four stretches of
// the road side by side on one dashed flight path (stacked on a phone). The stop marked "here" carries a pulse.
// The countdown is written at build time and kept current by site.js from data-departure.
function journey(c, site, departure) {
  const j = c.journey;
  const days = Math.ceil((Date.parse(site.departureDate) - Date.now()) / 864e5);
  const stops = j.stops
    .map((st) => `<li class="stop${st.here ? " is-here" : ""}">
          ${mark(st.icon, "stop__mark")}${st.here ? pose("walk") : ""}
          <h3 class="stop__title">${esc(st.title)}</h3>
          <p class="stop__when">${esc(fill(st.when, { departure }))}${st.here ? ` <span class="visually-hidden">(${esc(j.here)})</span>` : ""}</p>
          <p>${esc(st.body)}</p>
        </li>`)
    .join("\n        ");
  return `<section class="section journey" id="${esc(j.id)}" aria-labelledby="${esc(j.id)}-title">
    <div class="container journey__inner">
      <div class="journey__head">
        <div class="journey__intro">
          <h2 class="section__title" id="${esc(j.id)}-title">${hl(j.title, "sparkle")}</h2>
          <p class="journey__lede">${esc(j.lede)}</p>
        </div>
        <figure class="journey__bag">
          ${img("art/suitcase.webp", "art journey__suitcase", 640, 627, j.suitcase)}
          <p class="journey__tag" data-countdown data-departure="${esc(site.departureDate)}" data-today="${esc(j.countdown.today)}" data-after="${esc(fill(j.countdown.after, { departure }))}">
            <strong data-days>${Math.max(days, 0)}</strong> <span>${esc(j.countdown.before)}</span>
          </p>
        </figure>
      </div>
      <ol class="journey__stops">
        ${stops}
      </ol>
      <a class="button journey__cta" href="#${esc(j.target)}">${esc(j.cta)} ${icon.arrow}</a>
    </div>
  </section>`;
}

// A postage stamp for the letter card: a perforated edge round a little peak, like the one on the envelopes.
export const stamp = `<svg class="letter__stamp" viewBox="0 0 44 52" aria-hidden="true" focusable="false">
  <path class="letter__stamp-edge" d="M2 2h40v48H2Z"/>
  <path class="letter__stamp-sky" d="M7 7h30v31H7Z"/>
  <path class="letter__stamp-peak" d="m7 38 10-15 5 6 5-8 10 17Z"/>
  <path class="letter__stamp-snow" d="m14.5 26.7 2.5-3.7 2.2 2.6M24.6 24.6 27 21l3 5"/>
</svg>`;

// The sign-up form. Posts to the sync server's /v1/public/subscribe (site.js); "website" is a hidden bot trap.
function signup(c) {
  const f = c.loop.form;
  return `<form class="signup" novalidate data-signup>
          <div class="signup__fields">
            <label class="field"><span>${esc(f.name)}</span><input name="name" autocomplete="given-name" autocapitalize="words" enterkeyhint="next" maxlength="80" required></label>
            <label class="field"><span>${esc(f.email)}</span><input name="email" type="email" autocomplete="email" inputmode="email" autocapitalize="off" spellcheck="false" enterkeyhint="send" maxlength="200" required></label>
          </div>
          <fieldset class="choice">
            <legend>${esc(f.lang)}</legend>
            <div class="choice__options">
              ${[["nl", "Nederlands"], ["en", "English"]].map(([v, t]) => `<label class="choice__option"><input type="radio" name="lang" value="${v}"${c.lang === v ? " checked" : ""}><span>${t}</span></label>`).join("\n              ")}
            </div>
          </fieldset>
          <div class="signup__trap" aria-hidden="true"><label>Website<input name="website" tabindex="-1" autocomplete="off"></label></div>
          <button class="button button--solid" type="submit"><span data-label>${esc(f.submit)}</span> ${icon.mail}</button>
          <p class="signup__msg" role="status" aria-live="polite"></p>
          <p class="signup__done" hidden></p>
          <p class="signup__privacy">${esc(f.privacy)}</p>
        </form>`;
}

// Letters: the heading and lede, then the earlier letters and the way to the sign-up (in Get involved), beside the
// latest letter on a sheet of paper. Until a letter is online the sheet holds a short note from the copy; site.js
// swaps in the newest sent letter from the public summary, and lists the earlier ones.
function letters(c, departure) {
  const l = c.letters;
  const k = l.card;
  return `<section class="section letters" id="${esc(l.id)}" aria-labelledby="${esc(l.id)}-title">
    <div class="container letters__inner">
      <div class="letters__intro">
        <h2 class="section__title" id="${esc(l.id)}-title">${hl(l.title, "plane")}</h2>
        <p class="letters__lede">${esc(l.lede)}</p>
      </div>
      <div class="letters__more">
        <nav class="letters__earlier" aria-labelledby="${esc(l.id)}-earlier" data-letters-earlier hidden>
          <h3 class="letters__earlier-title" id="${esc(l.id)}-earlier">${esc(l.earlier)}</h3>
          <ul></ul>
        </nav>
        <div class="letters__actions">
          <a class="button" href="${esc(lettersHref(c))}" data-letters-all hidden>${esc(c.paper.index.all)} ${icon.arrow}</a>
          <a class="button button--solid" href="#${esc(c.loop.id)}">${esc(c.loop.title)} ${icon.mail}</a>
        </div>
      </div>
      <article class="letter" data-letter data-read-label="${esc(k.readLabel)}">
            ${pose("write")}
            ${stamp}
            ${img("art/flower-pink.webp", "art letter__flower", 112, 120)}
            <p class="letter__when" data-letter-when hidden></p>
            <h3 class="letter__title" data-letter-title>${esc(k.title)}</h3>
            <div class="letter__text" data-letter-text>
              <p>${esc(k.greeting)}</p>
              ${k.body.map((p) => `<p>${esc(fill(p, { departure }))}</p>`).join("\n              ")}
            </div>
            <p class="letter__sign" data-letter-sign>${esc(k.sign)}</p>
            <a class="button letter__read" data-letter-link href="#${esc(c.loop.id)}" hidden>${esc(k.read)} ${icon.arrow}</a>
      </article>
    </div>
  </section>`;
}

// How to give: the support as a plane on the dashed route, then the bank details with Copy IBAN and "Give online".
// site.js fills it from the public summary (Settings > Giving in the app); until there is an IBAN it says they follow
// soon. Used in Give under Get involved and on the giving page, each with its own note under the details.
export function give(c, note) {
  const g = c.involved.give;
  const row = (label, key) => `<div data-give-row="${key}"><dt>${esc(label)}</dt><dd data-give="${key}"></dd></div>`;
  return `<div class="give__progress" data-progress hidden>
            <p class="give__progress-text" data-progress-text></p>
            <div class="route" role="img" data-progress-route>
              <span class="route__done"></span>
              <span class="route__plane">${icon.plane}</span>
            </div>
          </div>
          <div class="give__details" data-give-details hidden>
            <dl class="give__bank">
              ${row(g.iban, "iban")}
              ${row(g.holder, "holder")}
              ${row(g.reference, "reference")}
            </dl>
            <div class="give__actions">
              <button class="button" type="button" data-copy>${esc(g.copy)} ${icon.copy}</button>
              <a class="button button--solid" data-give-online rel="noopener" hidden>${esc(g.online)} ${icon.arrow}</a>
            </div>
            <p class="give__note">${esc(note)}</p>
          </div>
          <p class="give__pending" data-give-pending>${esc(g.pending)}</p>`;
}

// The message form on the giving page. Posts to the sync server's /v1/public/message (site.js), which puts the
// message on the partner in the app with a follow-up for today; "website" is a hidden bot trap.
export function messageForm(c) {
  const m = c.giving.message;
  return `<form class="signup message" novalidate data-message>
          <div class="signup__fields">
            <label class="field"><span>${esc(m.name)}</span><input name="name" autocomplete="name" autocapitalize="words" enterkeyhint="next" maxlength="80" required></label>
            <label class="field"><span>${esc(m.email)}</span><input name="email" type="email" autocomplete="email" inputmode="email" autocapitalize="off" spellcheck="false" enterkeyhint="next" maxlength="200" required></label>
          </div>
          <label class="field"><span>${esc(m.message)}</span><textarea name="message" rows="6" maxlength="2000" required></textarea></label>
          <div class="signup__trap" aria-hidden="true"><label>Website<input name="website" tabindex="-1" autocomplete="off"></label></div>
          <button class="button button--solid" type="submit"><span data-label>${esc(m.submit)}</span> ${icon.mail}</button>
          <p class="signup__msg" role="status" aria-live="polite"></p>
          <p class="signup__done" hidden></p>
          <p class="signup__privacy">${esc(m.privacy)}</p>
        </form>`;
}

// Get involved: the heading and lede, then four ways to help, each with a drawn mark and the thing itself: the
// sign-up for the letters, the prayer requests, how to give and "Pass it on". site.js fills the prayers and the
// support route from the public summary, and makes "Pass it on" share or copy the page link. The bank details come
// from the summary too (Settings > Giving in the app); until there is an IBAN, Give says they follow soon.
function involved(c) {
  const v = c.involved;
  const content = {
    letters: () => signup(c),
    pray: () => `<ul class="prayers__list" data-prayers hidden></ul>
          <p class="prayers__empty" data-prayers-empty>${esc(v.pray.empty)}</p>`,
    give: () => `${give(c, v.give.note)}
          <a class="way__link" href="${esc(givingHref(c))}">${esc(c.giving.more)} ${icon.arrow}</a>`,
    share: (w) => `<button class="way__link" type="button" data-share>${esc(w.link)} ${icon.arrow}</button>`,
  };
  const ids = { letters: c.loop.id, pray: v.pray.id, give: v.give.id };
  const ways = v.ways
    .map((w) => `<li class="way way--${w.kind}"${ids[w.kind] ? ` id="${esc(ids[w.kind])}"` : ""}>
          ${mark(w.icon, "way__mark")}
          <h3 class="way__title">${esc(w.title)}</h3>
          <p class="way__lede">${esc(w.body)}</p>
          ${content[w.kind](w)}
        </li>`)
    .join("\n        ");
  return `<section class="section involved" id="${esc(v.id)}" aria-labelledby="${esc(v.id)}-title">
    <div class="container involved__inner">
      <div class="involved__intro">
        <h2 class="section__title" id="${esc(v.id)}-title">${hl(v.title, "heart")}</h2>
        <p class="involved__lede">${esc(v.lede)}</p>
      </div>
      <ul class="involved__ways">
        ${ways}
      </ul>
    </div>
  </section>`;
}

// The home page's main content: the hero with the globe, then the four sections in one flow.
export function home(c, site, departure) {
  return `  <section class="hero">
    <div class="container hero__inner">
      <div class="hero__copy">
        <h1 class="hero__title">${hl(c.hero.title)}</h1>
        <p class="hero__lede">${esc(c.hero.lede)}</p>
        <a class="button" href="#${esc(c.hero.target)}">${esc(c.hero.cta)} ${icon.arrow}</a>
      </div>

      <div class="hero__stage">
        ${img("art/mountains.webp", "art hero__mountains", 440, 173)}
        ${img("art/flower-coral.webp", "art hero__flower--coral", 113, 120)}
        ${img("art/flower-pink.webp", "art hero__flower--pink", 112, 120)}
        <figure class="globe" data-globe data-to="${esc(c.globe.to)}" tabindex="0" role="img" aria-label="${esc(c.globe.label)}">
          <canvas aria-hidden="true"></canvas>
        </figure>
        <img class="art hero__traveller" src="/assets/art/traveller.webp" alt="" width="544" height="908" fetchpriority="high">
        ${img("art/plants-left.webp", "art hero__plants--left", 312, 560)}
        ${img("art/plants-right.webp", "art hero__plants--right", 575, 640)}
      </div>
    </div>
  </section>

  <div class="flow">
${story(c, departure)}
${journey(c, site, departure)}
${letters(c, departure)}
${involved(c)}
  </div>`;
}
