// Renders one language of the site. Content lives in ../content/*.json; this file is structure only.
import { worldPaths } from "./world.mjs";

const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const paras = (list) => list.map((p) => `<p>${esc(p)}</p>`).join("");

// Amsterdam and Queenstown on the 1000×500 equirectangular map.
const FROM = { x: 527.8, y: 105.4 };
const TO = { x: 968.5, y: 375.1 };
const route = `M${FROM.x} ${FROM.y} Q 760 -10 ${TO.x} ${TO.y}`;

// The sign-up is deliberately short: a first name, an email, one button.
// wantsContact stays in the form as a hidden box so the script can read it.
function form(f, id) {
  return `<form class="signup" id="${id}" novalidate data-api-form>
  <label class="field"><span>${esc(f.name)}</span><input name="name" autocomplete="given-name" maxlength="80" required></label>
  <label class="field"><span>${esc(f.email)}</span><input name="email" type="email" autocomplete="email" inputmode="email" maxlength="200" required></label>
  <input type="checkbox" name="wantsContact" hidden tabindex="-1" aria-hidden="true">
  <div class="trap" aria-hidden="true"><label>Website<input name="website" tabindex="-1" autocomplete="off"></label></div>
  <button class="btn" type="submit"><span data-label>${esc(f.submit)}</span></button>
  <p class="msg" role="status" aria-live="polite"></p>
  <p class="done" hidden><span class="done-tx"></span></p>
</form>`;
}

export function render(c, site) {
  const [y, m] = site.departureDate.split("-").map(Number);
  const departure = `${c.months[m - 1]} ${y}`;
  // Build-time count; the script refreshes it from the live summary.
  const days = Math.round((Date.parse(site.departureDate + "T00:00:00Z") - Date.now()) / 864e5);
  const strings = { form: c.form, give: { copied: c.give.copied }, pray: c.pray, months: c.months, monthsShort: c.monthsShort };

  return `<!doctype html>
<html lang="${c.lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(c.meta.title)}</title>
<meta name="description" content="${esc(c.meta.description)}">
<meta name="theme-color" content="#D2462B">
<meta name="hesent-api" content="${esc(site.api)}">
<link rel="canonical" href="${site.domain}/${c.lang}/">
<link rel="alternate" hreflang="nl" href="${site.domain}/nl/">
<link rel="alternate" hreflang="en" href="${site.domain}/en/">
<link rel="alternate" hreflang="x-default" href="${site.domain}/">
<meta property="og:type" content="website">
<meta property="og:title" content="${esc(c.meta.title)}">
<meta property="og:description" content="${esc(c.meta.description)}">
<meta property="og:url" content="${site.domain}/${c.lang}/">
<meta property="og:locale" content="${c.lang === "nl" ? "nl_NL" : "en_GB"}">
<link rel="icon" href="/assets/icon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/assets/site.css">
</head>
<body>

<header class="bar">
  <a class="mark" href="#top">hesent<span>.me</span></a>
  <nav aria-label="${esc(c.nav.label)}">
    ${c.nav.items.map((it) => `<a href="#${it.id}" data-nav="${it.id}">${esc(it.label)}</a>`).join("")}
  </nav>
  <a class="lang" href="${c.other.href}" hreflang="${c.other.lang}" lang="${c.other.lang}" data-lang="${c.other.lang}" aria-label="${esc(c.other.long)}">${c.other.label}</a>
</header>

<main>
<section class="hero" id="top">
  <div class="hero-copy">
    <p class="now" data-days data-departure="${site.departureDate}">
      <b data-days-n>${Math.abs(days)}</b>
      <span data-days-cap data-cap-before="${esc(c.cover.daysCap)}" data-cap-after="${esc(c.cover.daysCapAfter)}">${esc(days >= 0 ? c.cover.daysCap : c.cover.daysCapAfter)}</span>
    </p>
    <h1>${esc(c.cover.title)}</h1>
    <p class="lede">${esc(c.cover.hand)}</p>
    <a class="btn" href="#waar">${esc(c.cover.scroll)}</a>
  </div>

  <figure class="map">
    <svg viewBox="0 0 1000 500" role="img" aria-label="${esc(c.where.figLabel)}">
      <g class="land">${worldPaths.length ? `<path d="${worldPaths}"/>` : ""}</g>
      <path class="route" pathLength="1" d="${route}"/>
      <g class="pin" transform="translate(${FROM.x} ${FROM.y})"><circle r="5"/></g>
      <g class="pin" transform="translate(${TO.x} ${TO.y})"><circle r="7"/>
        <text x="-14" y="-14" text-anchor="end">Queenstown</text></g>
      <path class="plane" d="M-9 0 L9 -4.5 L4 0 L9 4.5 Z">
        <animateMotion dur="7s" repeatCount="indefinite" rotate="auto" path="${route}"/>
      </path>
    </svg>
  </figure>
</section>

<section class="block" id="waar">
  <h2>${esc(c.where.title)}</h2>
  <div class="prose">${paras(c.where.body)}</div>
</section>

<section class="block" id="wat">
  <h2>${esc(c.what.title)}</h2>
  <ol class="steps">${c.what.steps.map((s) => `<li><span class="when"${s.when === "{departure}" ? " data-departure-text" : ""}>${esc(s.when.replace("{departure}", departure))}</span> ${esc(s.what)}</li>`).join("")}</ol>
  <div class="prose">${paras(c.what.body)}</div>
</section>

<section class="block" id="bidden">
  <h2>${esc(c.pray.title)}</h2>
  <p class="prose">${esc(c.pray.body)}</p>
  <p class="prayer" data-prayer-text>${esc(c.pray.fallback[0])}</p>
  <div class="row">
    <button class="btn" type="button" data-pray>${esc(c.pray.button)}</button>
    <span class="amen" data-amen aria-hidden="true">${esc(c.pray.prayed)}</span>
  </div>
</section>

<section class="block" id="steunen">
  <h2>${esc(c.give.title)}</h2>
  <div class="prose">${paras(c.give.body)}</div>
  <dl class="bank">
    <div><dt>${esc(c.give.ibanLabel)}</dt><dd data-iban>${esc(c.give.iban)}</dd></div>
    <div><dt>${esc(c.give.holderLabel)}</dt><dd>${esc(c.give.holder)}</dd></div>
  </dl>
  <button class="btn" type="button" data-copy>${esc(c.give.copy)}</button>
</section>

<section class="block" id="lees-mee">
  <h2>${esc(c.back.title)}</h2>
  <p class="prose">${esc(c.back.body)}</p>
  ${form(c.form, "signup")}
</section>
</main>

<footer>
  <span>${esc(c.back.colophon)}</span>
  <a href="${c.other.href}" hreflang="${c.other.lang}" lang="${c.other.lang}" data-lang="${c.other.lang}">${esc(c.other.long)}</a>
</footer>

<div class="toast" role="status" aria-live="polite" data-toast><span data-toast-tx></span></div>
<script id="strings" type="application/json">${JSON.stringify(strings).replace(/</g, "\\u003c")}</script>
<script src="/assets/site.js" defer></script>
</body>
</html>
`;
}
