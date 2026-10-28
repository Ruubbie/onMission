// hesent.me letters: the front page (/nl/brieven/, /en/letters/) and one letter (/nl/brief/?key, /en/letter/?key).
// Both read the sync server named in <meta name="hesent-api"> (dev.mjs with SAMPLE=1 empties it, so its sample routes answer).
// The layout is a newspaper's: the newest letter leads, the text runs in columns, photos and asides sit among them.
(() => {
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (!reduce) document.documentElement.classList.add("has-motion");

  const lang = document.documentElement.lang === "en" ? "en" : "nl";
  const API = (document.querySelector('meta[name="hesent-api"]')?.content || "").replace(/\/+$/, "");
  const S = JSON.parse(document.getElementById("strings")?.textContent || "{}");
  const P = S.paper || {};
  const fill = (t, v) => t.replace(/\{(\w+)\}/g, (_, k) => v[k] ?? "");
  const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  const longDate = (iso) => {
    const [y, m, d] = iso.split("-").map(Number);
    return `${d} ${S.months[m - 1]} ${y}`;
  };
  const href = (l) => `${S.letterHref}?${encodeURIComponent(l.key)}`;
  // "Brief 3 · 20 oktober 2026 · Queenstown, NZ": the line under a headline, never above it.
  const meta = (l) => [l.number && fill(P.index.issue, { number: l.number }), l.sentAt && longDate(l.sentAt), l.place].filter(Boolean).map(esc).join(" · ");

  // The language switch remembers the choice (see site.js); on a letter it opens the same letter in the other language.
  const key = decodeURIComponent(location.search.slice(1)).split("&")[0];
  document.querySelectorAll("a[data-lang]").forEach((a) => {
    a.addEventListener("click", () => { document.cookie = `lang=${a.dataset.lang}; path=/; max-age=31536000; SameSite=Lax`; });
    if (key && document.querySelector("[data-issue]")) a.href += `?${encodeURIComponent(key.split("-")[0])}`;
  });

  const get = (path) => {
    const ctl = new AbortController();
    setTimeout(() => ctl.abort(), 8000);
    return fetch(`${API}${path}`, { signal: ctl.signal }).then((res) => {
      if (res.status === 404) return { missing: true };
      return res.ok ? res.json() : Promise.reject(new Error(String(res.status)));
    });
  };

  // A photo as printed in the paper: the picture with its caption under it. width/height keep the space while it loads.
  const photo = (p, cls, { eager = false, link } = {}) => {
    if (!p) return "";
    const size = p.width && p.height ? ` width="${p.width}" height="${p.height}"` : "";
    const pic = `<img src="${esc(API + p.url)}" alt="${esc(p.caption || "")}"${size} ${eager ? 'fetchpriority="high"' : 'loading="lazy"'} decoding="async">`;
    return `<figure class="photo ${cls}">${link ? `<a href="${esc(link)}" tabindex="-1" aria-hidden="true">${pic}</a>` : pic}${p.caption && !link ? `<figcaption>${esc(p.caption)}</figcaption>` : ""}</figure>`;
  };

  // ---------- Markdown ----------
  // What a letter may use: paragraphs, ## headings (a new section), ### subheadings, lists, > quotes, **bold**,
  // *italic* and links. Everything is escaped first, so nothing in a letter can add its own HTML.
  const inline = (t) => esc(t)
    .replace(/\[([^\]]+)\]\(((?:https?:\/\/|mailto:)[^)\s]+)\)/g, '<a href="$2" rel="noopener">$1</a>')
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/(^|[^*])\*([^*\n]+)\*/g, "$1<em>$2</em>")
    .replace(/\n/g, "<br>");
  const words = (t) => (t.match(/\S+/g) || []).length;

  // The body as sections: a new one starts at every # or ## heading, and what comes before the first is the opening.
  // Each section is its title, its blocks of HTML and its length in words.
  function sections(md) {
    const parts = [{ title: null, blocks: [], words: 0 }];
    const part = () => parts[parts.length - 1];
    // A heading line stands on its own even without blank lines around it or a space after the #s
    // ("##Next steps" straight above its text), so it is split off into a paragraph of its own first.
    const paras = (md || "").replace(/\r/g, "").replace(/^[ \t]*(#{1,3})[ \t]*(\S.*)$/gm, "\n$1 $2\n").split(/\n\s*\n/);
    for (const raw of paras) {
      const b = raw.trim();
      if (!b || /^(!\[[^\]]*\]\([^)]*\)|-{3,}|\*{3,})$/.test(b)) continue;
      const h = b.match(/^(#{1,3}) (.+)$/);
      if (h && h[1].length < 3) { parts.push({ title: inline(h[2]), blocks: [], words: 0 }); continue; }
      if (h) { part().blocks.push(`<h3>${inline(h[2])}</h3>`); continue; }
      const lines = b.split("\n");
      if (lines.every((l) => /^\s*[-*]\s+/.test(l))) part().blocks.push(`<ul>${lines.map((l) => `<li>${inline(l.replace(/^\s*[-*]\s+/, ""))}</li>`).join("")}</ul>`);
      else if (lines.every((l) => /^\s*\d+[.)]\s+/.test(l))) part().blocks.push(`<ol>${lines.map((l) => `<li>${inline(l.replace(/^\s*\d+[.)]\s+/, ""))}</li>`).join("")}</ol>`);
      else if (lines.every((l) => /^>/.test(l))) part().blocks.push(`<blockquote><p>${inline(lines.map((l) => l.replace(/^>\s?/, "")).join("\n"))}</p></blockquote>`);
      else part().blocks.push(`<p>${inline(b)}</p>`);
      part().words += words(b);
    }
    return parts.filter((p) => p.title || p.blocks.length);
  }

  // ---------- the front page ----------
  const front = document.querySelector("[data-front]");
  if (front) {
    get(`/v1/public/letters?lang=${lang}`)
      .then((data) => {
        const all = (data.letters || []).filter((l) => l.key && l.title);
        front.querySelector("[data-front-status]").remove();
        if (!all.length) { front.querySelector("[data-front-empty]").hidden = false; return; }
        const [lead, ...rest] = all;
        const next = rest.slice(0, 4);
        const older = rest.slice(4);
        const read = (l) => `<a class="button" href="${esc(href(l))}" aria-label="${esc(fill(P.index.readLabel, { title: l.title }))}">${esc(P.index.read)} ${S.arrow}</a>`;
        let html = `<article class="front__lead${lead.photo ? "" : " front__lead--text"}">
          ${photo(lead.photo, "front__lead-photo", { eager: true, link: href(lead) })}
          <div class="front__lead-copy">
            <h2 class="front__lead-title"><a href="${esc(href(lead))}">${esc(lead.title)}</a></h2>
            ${lead.subtitle ? `<p class="front__lead-subtitle">${esc(lead.subtitle)}</p>` : ""}
            <p class="paper__meta">${meta(lead)}</p>
            ${lead.excerpt ? `<p class="front__lead-excerpt">${esc(lead.excerpt)}</p>` : ""}
            ${read(lead)}
          </div>
        </article>`;
        if (next.length) {
          // A letter without a photo shows its opening on a sheet of paper in the photo's place, so the row stays even.
          html += `<ul class="front__row">${next.map((l) => `<li class="story">
            ${l.photo ? photo(l.photo, "story__photo", { link: href(l) }) : `<a class="story__sheet" href="${esc(href(l))}" tabindex="-1" aria-hidden="true"><span>${esc(l.excerpt || l.title)}</span></a>`}
            <h3 class="story__title"><a href="${esc(href(l))}">${esc(l.title)}</a></h3>
            <p class="paper__meta">${meta(l)}</p>
            ${l.excerpt && l.photo ? `<p class="story__excerpt">${esc(l.excerpt)}</p>` : ""}
          </li>`).join("")}</ul>`;
        }
        if (older.length) {
          const years = [...new Set(older.map((l) => l.sentAt.slice(0, 4)))];
          html += `<section class="front__older" aria-labelledby="older-title">
            <h2 class="front__older-title" id="older-title">${esc(P.index.older)}</h2>
            <div>${years.map((y) => `<div class="front__year"><h3>${y}</h3><ul>${older.filter((l) => l.sentAt.startsWith(y)).map((l) =>
              `<li><a href="${esc(href(l))}"><span>${esc(l.title)}</span><time datetime="${esc(l.sentAt)}">${esc(longDate(l.sentAt))}</time></a></li>`).join("")}</ul></div>`).join("")}</div>
          </section>`;
        }
        front.insertAdjacentHTML("afterbegin", html);
      })
      .catch(() => { front.querySelector("[data-front-status]").textContent = P.index.offline; })
      .finally(() => front.removeAttribute("aria-busy"));
  }

  // ---------- one letter ----------
  const issue = document.querySelector("[data-issue]");
  if (issue) {
    const status = issue.querySelector("[data-issue-status]");
    const L = P.letter;
    const done = () => issue.removeAttribute("aria-busy");
    let support = null;     // the monthly support as a percentage of the target, for the funds; null when unknown
    if (!key) {
      status.innerHTML = `${esc(L.missing)} <a href="${esc(S.lettersHref)}">${esc(L.all)}</a>`;
      done();
    } else {
      get(`/v1/public/letters/${encodeURIComponent(key)}?lang=${lang}`)
        .then((data) => {
          if (data.missing || !data.letter) {
            status.innerHTML = `${esc(L.missing)} <a href="${esc(S.lettersHref)}">${esc(L.all)}</a>`;
            return;
          }
          const l = data.letter;
          document.title = `${l.title} · hesent.me`;
          if (l.key !== key) history.replaceState(null, "", href(l));
          support = typeof data.support?.percentOfTarget === "number" ? data.support.percentOfTarget : null;
          issue.innerHTML = layout(l, data.newer, data.older);
          issue.querySelectorAll(".aside").forEach((el) => el.classList.add("is-drawn"));
        })
        .catch(() => { status.textContent = L.offline; })
        .finally(done);
    }

    // A cut-out from the site's illustrations, placed by letters.css. Decoration only.
    const art = (name, cls) => `<img class="art ${cls}" src="/assets/art/${name}.webp" alt="" loading="lazy" decoding="async">`;

    // The postmark over the lead photo's corner: the place and issue round the ring, the day in the middle, and the
    // wavy cancel lines running off to the right, like the stamp on an airmail envelope.
    function postmark(l) {
      const ring = [l.place, l.number && fill(P.index.issue, { number: l.number })].filter(Boolean).join(" · ");
      let day = "";
      if (l.sentAt) {
        const [y, m, d] = l.sentAt.split("-").map(Number);
        const mon = new Intl.DateTimeFormat(lang === "en" ? "en-GB" : "nl-NL", { month: "short", timeZone: "UTC" })
          .format(new Date(Date.UTC(y, m - 1, d))).replace(".", "");
        day = `<text class="postmark__day" x="60" y="62" text-anchor="middle">${d}</text>
          <text class="postmark__month" x="60" y="77" text-anchor="middle">${esc(mon)} ${y}</text>`;
      }
      return `<svg class="postmark" viewBox="0 0 196 120" aria-hidden="true" focusable="false">
          <defs><path id="postmark-ring" d="M60 60m-42 0a42 42 0 1 1 84 0a42 42 0 1 1-84 0"/></defs>
          <circle cx="60" cy="60" r="55"/><circle cx="60" cy="60" r="33"/>
          ${ring ? `<text class="postmark__ring"><textPath href="#postmark-ring" textLength="258" lengthAdjust="spacingAndGlyphs">${esc(ring.toUpperCase())} ·</textPath></text>` : ""}
          ${day}
          <path class="postmark__waves" d="M110 40q9-7 18 0t18 0 18 0 18 0M116 60q9-7 18 0t18 0 18 0 18 0M110 80q9-7 18 0t18 0 18 0 18 0"/>
        </svg>`;
    }

    // The dashed flight path from the headline into the letter, with the plane at its end (it bobs; the dashes march).
    const flight = `<svg class="flight" viewBox="0 0 340 96" aria-hidden="true" focusable="false">
        <path class="flight__path" d="M6 78C46 82 78 64 96 44c18-20 4-38-12-30-18 9-6 44 34 50 46 7 92-26 170-38"/>
        <g class="flight__plane"><path d="${S.plane}" transform="translate(312 24) rotate(-10) scale(30)"/></g>
      </svg>`;

    // The text as one run of blocks, each with its length in words: a ## heading is just a heading in the run, so the
    // letter reads straight on instead of breaking into boxed-off parts.
    function run(md) {
      const out = [];
      for (const p of sections(md)) {
        if (p.title) out.push({ html: `<h2>${p.title}</h2>`, words: 0, head: true });
        for (const b of p.blocks) out.push({ html: b, words: words(b.replace(/<[^>]+>/g, " ")) });
      }
      return out;
    }

    // Where the text breaks from the first column into the second: as near the middle as it can, counting the photo
    // at the top of the second column as words, and rather just before a heading. A column never ends on a heading.
    function split(blocks, head) {
      const total = blocks.reduce((n, b) => n + b.words, 0);
      const goal = (total + head) / 2;
      let best = blocks.length, cost = Infinity, sum = 0;
      for (let i = 1; i < blocks.length; i++) {
        sum += blocks[i - 1].words;
        if (blocks[i - 1].head) continue;
        const c = Math.abs(sum - goal) * (blocks[i].head ? 0.5 : 1);
        if (c < cost) { cost = c; best = i; }
      }
      return total < 160 ? blocks.length : best;
    }

    // A short opening line ("Hoi lieve mensen,") is set large, like a greeting written across the top.
    const hello = (blocks) => {
      const first = blocks[0]?.html;
      if (first?.startsWith("<p>") && blocks[0].words <= 8) blocks[0].html = first.replace("<p>", '<p class="issue__hello">');
    };

    // The foot: next time and the sign-up, on an airmail envelope that the traveller is posting.
    const foot = (l) => `<footer class="issue__foot">
        <div class="issue__envelope">
          ${S.stamp}
          ${l.nextTime ? `<h2 class="aside__title">${esc(L.nextTime)}</h2><p>${esc(l.nextTime)}</p>` : ""}
          <a class="button button--solid" href="${esc(S.loop)}">${esc(L.signup)} ${S.mail}</a>
        </div>
        ${art("traveller-post", "issue__me issue__me--post")}
      </footer>`;

    // The funds: a pinned sheet with Ruben's line about the support (or the standard one), the plane on the dashed
    // route to Queenstown as far as the monthly support is pledged, and the way to Give on the home page.
    const funds = (l) => `<aside class="aside aside--funds" aria-labelledby="funds-title">
        <h2 class="aside__title" id="funds-title">${esc(L.funds)}</h2>
        <p>${esc(l.funds || L.fundsBody)}</p>
        ${support === null ? "" : `<p class="aside__progress">${esc(fill(S.progress, { percent: support }))}</p>
        <div class="route" role="img" aria-label="${esc(fill(S.progressLabel, { percent: support }))}" style="--progress:${Math.min(Math.max(support, 0), 100)}">
          <span class="route__done"></span><span class="route__plane">${S.planeIcon}</span>
        </div>`}
        <a class="button button--solid" href="${esc(S.give)}">${esc(L.give)} ${S.arrow}</a>
      </aside>`;

    // The footer under the columns: its pieces side by side, standing on one line. Next time and funds by default.
    const footer = (html) => (html ? `<div class="issue__footer">${html}</div>` : "");

    // A letter Ruben arranged himself (Arrange in the web app): each column holds its pieces top to bottom, and the
    // footer holds its own. Text sections that follow each other run on as one text; a photo that opens the first or
    // second column gets the traveller taking it, and the mountains close the last text.
    function arranged(l, { note, prayers }) {
      const photos = new Map((l.photos || []).map((p) => [`p:${p.id}`, p]));
      const secs = new Map(l.sections.map((s) => [`s:${s.id}`, s]));
      const shown = (c) => c.filter((r) => secs.has(r) || photos.has(r) || r === "next" || r === "funds" || (r === "note" && note) || (r === "prayers" && prayers));
      const cols = l.layout.columns.map(shown);
      const closing = shown(l.layout.footer || []);
      const last = [...cols, closing].flat().filter((r) => secs.has(r)).pop();
      let opened = false, snapped = false;
      const column = (refs, i) => {
        let html = "";
        for (let k = 0; k < refs.length; k++) {
          const r = refs[k];
          if (secs.has(r)) {
            const bs = [];
            for (; k < refs.length && secs.has(refs[k]); k++) {
              const s = secs.get(refs[k]);
              bs.push(...run([s.title && `## ${s.title}`, s.body].filter(Boolean).join("\n\n")));
            }
            const end = refs[--k] === last;
            if (!opened) { hello(bs); opened = true; }
            html += `<div class="issue__text">${bs.map((b) => b.html).join("")}${end ? art("mountains", "issue__end") : ""}</div>`;
          } else if (photos.has(r)) {
            const snap = !snapped && k === 0 && i < 2;
            if (snap) snapped = true;
            html += snap ? `<div class="issue__snap">${photo(photos.get(r), "photo--print")}${art("traveller-photo", "issue__me issue__me--photo")}</div>` : photo(photos.get(r), "photo--print");
          } else html += r === "next" ? foot(l) : r === "funds" ? funds(l) : r === "note" ? note : prayers;
        }
        return html;
      };
      const filled = cols.map((c, i) => (c.length ? `<div class="issue__set-col issue__set-col--${i + 1}">${column(c, i)}</div>` : "")).filter(Boolean);
      return { body: `<div class="issue__set issue__set--${filled.length}">${filled.join("")}</div>`, foot: footer(column(closing, 3)) };
    }

    function layout(l, newer, older) {
      if (l.layout && l.sections) return page(l, newer, older, l.photos?.find((p) => p.id === l.layout.cover), true);
      return page(l, newer, older, (l.photos || [])[0], false);
    }

    function page(l, newer, older, lead, set) {
      const more = (l.photos || []).filter((p) => p !== lead);
      const blocks = set ? [] : run(l.body);
      hello(blocks);
      const flame = S.marks.pray;
      const prayers = l.prayers?.length ? `<aside class="aside aside--prayers" aria-labelledby="prayers-title">
          <h2 class="aside__title" id="prayers-title">${esc(L.prayers)}</h2>
          <ul class="aside__list">${l.prayers.map((t) => `<li>${flame}<p>${esc(t)}</p></li>`).join("")}</ul>
        </aside>` : "";
      const note = l.note ? `<aside class="aside aside--note">${art("flower-pink", "aside__flower")}<p>${esc(l.note)}</p><p class="aside__sign">${esc(L.sign)}</p></aside>` : "";
      // Unless the letter is arranged: three columns, like the reference page. The text runs down the first and on into the second (which opens with
      // the second photo), and the third holds the side note (when there is no lead photo), the prayer points and the
      // other photos. Next time and the funds close the letter side by side in the footer.
      const [snap, ...rest] = more;
      const top = snap ? `<div class="issue__snap">${photo(snap, "photo--print")}${art("traveller-photo", "issue__me issue__me--photo")}</div>` : "";
      const at = split(blocks, top ? 60 : 0);
      const text = (bs, end) => `<div class="issue__text">${bs.map((b) => b.html).join("")}${end ? art("mountains", "issue__end") : ""}</div>`;
      const side = [lead ? "" : note, prayers, ...rest.map((p) => photo(p, "photo--print"))].filter(Boolean).join("");
      const { body, foot: end } = set ? arranged(l, { note, prayers }) : {
        body: `<div class="issue__cols">
          <div class="issue__col issue__col--a">${text(blocks.slice(0, at), at === blocks.length)}</div>
          ${top || at < blocks.length ? `<div class="issue__col issue__col--b">${top}${at < blocks.length ? text(blocks.slice(at), true) : ""}</div>` : ""}
        </div>
        ${side ? `<div class="issue__side">${side}</div>` : ""}`,
        foot: footer(foot(l) + funds(l)),
      };
      const link = (x, label, cls) => (x ? `<a class="issue__step ${cls}" href="${esc(href(x))}"><span>${esc(label)}</span><strong>${esc(x.title)}</strong></a>` : "");

      return `<header class="issue__head${lead ? "" : " issue__head--text"}">
          <div class="issue__headline">
            <h1 class="issue__title">${esc(l.title)}</h1>
            ${l.subtitle ? `<p class="issue__subtitle">${esc(l.subtitle)}</p>` : ""}
            <p class="paper__meta">${meta(l)}</p>
            ${flight}
          </div>
          ${lead ? "" : art("traveller-read", "issue__me issue__me--read")}
          ${lead ? `<div class="issue__lead">${postmark(l)}${art("traveller-write", "issue__me issue__me--write")}${photo(lead, "photo--print photo--lead", { eager: true })}${set ? "" : note}</div>` : ""}
        </header>
        <div class="issue__body${set ? " issue__body--set" : side ? "" : " issue__body--plain"}">${body}</div>
        ${end}
        <nav class="issue__steps" aria-label="${esc(L.all)}">
          ${link(older, L.older, "issue__step--older")}
          <a class="issue__all" href="${esc(S.lettersHref)}">${esc(L.all)}</a>
          ${link(newer, L.newer, "issue__step--newer")}
        </nav>`;
    }
  }
})();
