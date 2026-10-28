// The frame every page shares: head, header, footer and the strings for the page's script.
// page.mjs builds the home page inside it; the letters front page, a single letter and the giving page are built here too.

import { esc, fill, hl, icon, img, ridge, stamp, mark, nav, pose, langSwitch, langButton, lettersHref, letterHref, givingHref, give, messageForm, home, planePath } from "./page.mjs";

// page: null for the home page, otherwise { path, paths (the same page per language), title, description, strings,
// current (the nav link it belongs under) and script ("letters", the default, or "site") }.
export function shell(c, site, page, main) {
  const [y, m] = site.departureDate.split("-").map(Number);
  const departure = `${c.months[m - 1]} ${y}`;
  const year = new Date().getFullYear();
  const homePath = `/${c.lang}/`;
  const path = page ? page.path : homePath;
  const paths = page ? page.paths : { nl: "/nl/", en: "/en/" };
  const title = page ? `${page.title} · hesent.me` : c.meta.title;
  const description = page ? page.description : c.meta.description;
  const loop = `${page ? homePath : ""}#${esc(c.loop.id)}`;
  const strings = page ? page.strings : homeStrings(c);
  const script = page?.script || (page ? "letters" : "site");

  return `<!doctype html>
<html lang="${c.lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<meta name="theme-color" content="#F4EDE1">
<meta name="hesent-api" content="${esc(site.api)}">
<link rel="canonical" href="${site.domain}${path}">
<link rel="alternate" hreflang="nl" href="${site.domain}${paths.nl}">
<link rel="alternate" hreflang="en" href="${site.domain}${paths.en}">
${page ? "" : `<link rel="alternate" hreflang="x-default" href="${site.domain}/">\n`}<meta property="og:type" content="${page ? "article" : "website"}">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${site.domain}${path}">
<meta property="og:locale" content="${c.lang === "nl" ? "nl_NL" : "en_GB"}">
<link rel="icon" href="/assets/logo-192.png" type="image/png">
<link rel="apple-touch-icon" href="/assets/logo-192.png">
<link rel="preload" href="/assets/fonts/archivo.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="/assets/tokens.css">
<link rel="stylesheet" href="/assets/components.css">
<link rel="stylesheet" href="/assets/site.css">
${script === "letters" ? `<link rel="stylesheet" href="/assets/letters.css">\n` : ""}</head>
<body>

<a class="skip-link" href="#main">${esc(c.skip)}</a>

<header class="site-header">
  <div class="container site-header__inner">
    <a class="logo" href="${homePath}"><img src="/assets/logo-192.webp" alt="hesent.me" width="192" height="188"></a>
    <nav class="nav" aria-label="${esc(c.nav.label)}">${nav(c, page)}</nav>
    ${langButton(c, paths)}
    <a class="button" href="${loop}">${esc(c.loop.label)} ${icon.mail}</a>
  </div>
</header>

<main id="main">
${main(departure)}
</main>

<footer class="site-footer">
  <div class="site-footer__ridge">
    ${img("art/plants-left.webp", "art", 312, 560)}
    ${pose("wave")}
    ${ridge}
    ${img("art/plants-right.webp", "art", 575, 640)}
  </div>
  <div class="site-footer__body">
    <div class="container">
      <div class="site-footer__grid">
        <div class="site-footer__brand">
          <a class="site-footer__mark" href="${homePath}">
            <img src="/assets/logo-512.webp" alt="hesent.me" width="512" height="502" loading="lazy">
          </a>
          <p class="site-footer__tagline">${esc(c.footer.tagline)}</p>
          <a class="button button--light" href="${loop}">${esc(c.loop.label)} ${icon.mail}</a>
        </div>
        <nav aria-label="${esc(c.footer.navLabel)}">
          <p class="site-footer__heading">${esc(c.footer.navLabel)}</p>
          <div class="nav">${nav(c, page)}</div>
        </nav>
        <div>
          <p class="site-footer__heading">${esc(c.footer.language)}</p>
          ${langSwitch(c, paths)}
        </div>
      </div>
      <div class="site-footer__flight" aria-hidden="true">${icon.plane}</div>
      <div class="site-footer__base">
        <p>${esc(fill(c.footer.line, { departure }))}</p>
        <p>© ${year} Ruben · hesent.me</p>
      </div>
    </div>
  </div>
</footer>

<script id="strings" type="application/json">${JSON.stringify(strings).replace(/</g, "\\u003c")}</script>
<script src="/assets/header.js" defer></script>
<script src="/assets/${script}.js" defer></script>
</body>
</html>
`;
}

// What site.js needs on the home page (and on the giving page, which has the same Give).
function homeStrings(c) {
  return {
    form: c.loop.form,
    months: c.months,
    letterHref: letterHref(c),
    involved: { answered: c.involved.pray.answered, progress: c.involved.give.progress, progressLabel: c.involved.give.progressLabel, copied: c.involved.give.copied, share: c.involved.share },
  };
}

export function render(c, site) {
  return shell(c, site, null, (departure) => home(c, site, departure));
}

// What letters.js needs on both letter pages: the copy, the months, where the pages live, and what it draws (the
// candle mark, the stamp and the plane), and for the funds: the support line and where Give lives on the home page.
function letterStrings(c) {
  return {
    paper: c.paper,
    months: c.months,
    lettersHref: lettersHref(c),
    letterHref: letterHref(c),
    loop: `/${c.lang}/#${c.loop.id}`,
    give: givingHref(c),
    progress: c.involved.give.progress,
    progressLabel: c.involved.give.progressLabel,
    marks: { pray: mark("pray", "aside__mark") },
    stamp,
    plane: planePath,
    planeIcon: icon.plane,
    arrow: icon.arrow,
    mail: icon.mail,
  };
}

const pagePaths = (slug) => ({ nl: `/nl/${slug.nl}/`, en: `/en/${slug.en}/` });

// The letters front page: the newest letter as the lead story, the next four side by side, and every older one listed
// by year. letters.js fills it from /v1/public/letters; before any letter is online (or offline) the note from the copy shows.
export function renderLetters(c, site, slugs) {
  const p = c.paper.index;
  const k = c.letters.card;
  return shell(c, site, {
    path: lettersHref(c),
    paths: pagePaths(slugs.index),
    title: p.title,
    description: p.lede,
    strings: letterStrings(c),
    current: c.letters.id,
  }, (departure) => `  <div class="container paper">
    <header class="front__head">
      <div>
        <h1 class="front__title">${esc(p.title)}</h1>
        <p class="front__lede">${esc(p.lede)}</p>
      </div>
      ${img("art/letters.webp", "front__art", 640, 640, c.letters.art)}
    </header>
    <div class="front" data-front aria-busy="true">
      <p class="paper__status" data-front-status>${esc(p.loading)}</p>
      <article class="letter front__empty" data-front-empty hidden>
        ${stamp}
        <h2 class="letter__title">${esc(k.title)}</h2>
        <div class="letter__text">
          <p>${esc(k.greeting)}</p>
          ${k.body.map((t) => `<p>${esc(fill(t, { departure }))}</p>`).join("\n          ")}
        </div>
        <p class="letter__sign">${esc(k.sign)}</p>
        <a class="button letter__read" href="/${c.lang}/#${esc(c.loop.id)}">${esc(p.signup)} ${icon.mail}</a>
      </article>
    </div>
  </div>`);
}

// One letter, laid out like a newspaper page: the headline beside the lead photo, the text in columns with the photos,
// the prayer points and the side note placed among them, and "next time" at the foot. letters.js reads the letter's key
// from the address (/nl/brief/?3-een-nieuw-hoofdstuk) and fills the page from /v1/public/letters/{key}.
export function renderLetter(c, site, slugs) {
  const p = c.paper.letter;
  return shell(c, site, {
    path: letterHref(c),
    paths: pagePaths(slugs.letter),
    title: p.title,
    description: c.paper.index.lede,
    strings: letterStrings(c),
    current: c.letters.id,
  }, () => `  <div class="container paper">
    <article class="issue" data-issue aria-busy="true">
      <p class="paper__status" data-issue-status>${esc(p.loading)}</p>
    </article>
  </div>`);
}

// The giving page: the heading and lede beside the coin jar, then how to give (the support route and the bank details,
// as in Give on the home page) beside a sheet of paper with a message form, for givers who want to get to know Ruben.
// site.js fills Give from the public summary and posts the message to /v1/public/message.
export function renderGiving(c, site, slugs) {
  const p = c.giving;
  return shell(c, site, {
    path: givingHref(c),
    paths: pagePaths(slugs.giving),
    title: p.metaTitle,
    description: p.lede,
    strings: { ...homeStrings(c), message: p.message },
    current: c.involved.id,
    script: "site",
  }, () => `  <div class="flow">
  <section class="section giving" aria-labelledby="giving-title">
    <div class="container giving__inner">
      <header class="giving__head">
        <div>
          <h1 class="section__title giving__title" id="giving-title">${hl(p.title, "heart")}</h1>
          <p class="giving__lede">${esc(p.lede)}</p>
        </div>
        ${img("art/jar.webp", "giving__art", 640, 830, p.art)}
      </header>
      <div class="giving__grid">
        <section class="way way--give giving__give" id="${esc(c.involved.give.id)}" aria-labelledby="giving-give">
          <h2 class="way__title" id="giving-give">${esc(p.give.title)}</h2>
          <p class="way__lede">${esc(p.give.body)}</p>
          ${give(c, p.give.note)}
        </section>
        <article class="letter giving__letter" id="message" aria-labelledby="giving-message">
          ${pose("write")}
          ${stamp}
          ${img("art/flower-pink.webp", "art letter__flower", 112, 120)}
          <h2 class="letter__title" id="giving-message">${esc(p.message.title)}</h2>
          <p class="giving__letter-body">${esc(p.message.body)}</p>
          ${messageForm(c)}
        </article>
      </div>
    </div>
  </section>
  </div>`);
}
