// hesent.me: the globe, the letters, the sign-up and the language switch. The page reads fine without this file.
(() => {
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  // The plane, pointing right and centred on 0,0 (the same drawing as planePath in src/page.mjs).
  const planePath =
    "M0.408 -0.082 A0.082 0.082 0 0 1 0.408 0.082 L0.112 0.082 L-0.087 0.413 Q-0.112 0.459 -0.163 0.459 L-0.179 0.459 Q-0.235 0.459 -0.219 0.403 L-0.143 0.082 L-0.306 0.082 L-0.383 0.204 Q-0.403 0.235 -0.439 0.235 Q-0.49 0.235 -0.48 0.184 L-0.449 0 L-0.48 -0.184 Q-0.49 -0.235 -0.439 -0.235 Q-0.403 -0.235 -0.383 -0.204 L-0.306 -0.082 L-0.143 -0.082 L-0.219 -0.403 Q-0.235 -0.459 -0.179 -0.459 L-0.163 -0.459 Q-0.112 -0.459 -0.087 -0.413 L0.112 -0.082 Z";

  // Language switch: remember the choice, so the bare domain sends the visitor to the same language next time.
  document.querySelectorAll("[data-lang]").forEach((a) =>
    a.addEventListener("click", () => {
      document.cookie = `lang=${a.dataset.lang}; path=/; max-age=31536000; SameSite=Lax`;
    }),
  );

  document.querySelectorAll("[data-globe]").forEach((el) => initGlobe(el));

  // Countdown tag: the days until departure, counted in the visitor's own day; on and after the day, a line instead.
  document.querySelectorAll("[data-countdown]").forEach((el) => {
    const [y, m, d] = el.dataset.departure.split("-").map(Number);
    const now = new Date();
    const days = Math.round((new Date(y, m - 1, d) - new Date(now.getFullYear(), now.getMonth(), now.getDate())) / 864e5);
    if (days > 0) el.querySelector("[data-days]").textContent = days;
    else {
      el.classList.add("is-gone");
      el.querySelector("span").textContent = days === 0 ? el.dataset.today : el.dataset.after;
    }
  });

  // Chapter and stop marks: hide the strokes, then draw each mark in when it scrolls into view (see site.css). The
  // cards the traveller sits on are watched too, so he comes in with them.
  const chapters = document.querySelectorAll(".chapter, .stop, .way, .story__vision, .letter");
  if (!reduce && chapters.length && "IntersectionObserver" in window) {
    document.documentElement.classList.add("has-motion", "has-reveal");
    const seen = new IntersectionObserver((entries) => {
      for (const e of entries) {
        if (!e.isIntersecting) continue;
        e.target.classList.add("is-drawn");
        seen.unobserve(e.target);
      }
    }, { rootMargin: "0px 0px -15% 0px" });
    chapters.forEach((el) => seen.observe(el));
  }

  // The paper sheets lean toward the pointer and lift, on a spring, so they follow the hand with a little weight
  // and settle flat again when it leaves (site.css reads --tilt-x, --tilt-y, --lift). Only with a mouse or pen.
  if (!reduce && matchMedia("(hover: hover) and (pointer: fine)").matches) {
    document.querySelectorAll(".story__vision, .letter").forEach((el) => {
      const MAX = 3; // degrees
      const pos = { x: 0, y: 0, l: 0 };
      const vel = { x: 0, y: 0, l: 0 };
      const goal = { x: 0, y: 0, l: 0 };
      let last = 0;
      let raf = 0;
      const tick = (now) => {
        const dt = Math.min((now - (last || now)) / 1000, 1 / 30);
        last = now;
        let moving = false;
        for (const k of ["x", "y", "l"]) {
          // A spring with a stiffness of 170 and a damping of 20: quick, with a hint of give
          vel[k] += (170 * (goal[k] - pos[k]) - 20 * vel[k]) * dt;
          pos[k] += vel[k] * dt;
          if (Math.abs(goal[k] - pos[k]) > 1e-3 || Math.abs(vel[k]) > 1e-3) moving = true;
        }
        el.style.setProperty("--tilt-x", `${(pos.x * MAX).toFixed(3)}deg`);
        el.style.setProperty("--tilt-y", `${(pos.y * MAX).toFixed(3)}deg`);
        el.style.setProperty("--lift", pos.l.toFixed(3));
        raf = moving ? requestAnimationFrame(tick) : 0;
        if (!moving) last = 0;
      };
      const kick = () => { if (!raf) raf = requestAnimationFrame(tick); };
      el.addEventListener("pointermove", (e) => {
        if (e.pointerType === "touch") return;
        const r = el.getBoundingClientRect();
        goal.y = ((e.clientX - r.left) / r.width - 0.5) * 2;
        goal.x = -((e.clientY - r.top) / r.height - 0.5) * 2;
        goal.l = 1;
        kick();
      });
      el.addEventListener("pointerleave", () => {
        goal.x = goal.y = goal.l = 0;
        kick();
      });
    });
  }

  // ---------- letters and sign-up ----------
  // Both talk to the sync server named in <meta name="hesent-api"> (dev.mjs with SAMPLE=1 empties it, so its sample routes answer).
  const API = (document.querySelector('meta[name="hesent-api"]')?.content || "").replace(/\/+$/, "");
  const strings = JSON.parse(document.getElementById("strings")?.textContent || "{}");
  const fill = (t, v) => t.replace(/\{(\w+)\}/g, (_, k) => v[k] ?? "");
  const longDate = (iso) => {
    const [y, m, d] = iso.split("-").map(Number);
    return document.documentElement.lang === "nl" ? `${d} ${strings.months[m - 1].toLowerCase()} ${y}` : `${d} ${strings.months[m - 1]} ${y}`;
  };

  // The public summary, fetched once: the letters, the prayer requests and the support. null when offline.
  const ctl = new AbortController();
  setTimeout(() => ctl.abort(), 6000);
  const summary = fetch(`${API}/v1/public/summary?tz=Europe/Amsterdam&lang=${document.documentElement.lang}`, { signal: ctl.signal })
    .then((res) => (res.ok ? res.json() : null))
    .catch(() => null);

  // The latest letter that is online replaces the note on the sheet; up to four earlier ones are listed below it,
  // then a link to all of them. Each opens on its own page here (letters.js). Offline, or before any letter is
  // online, the note from the copy stays.
  const letter = document.querySelector("[data-letter]");
  if (letter && strings.months) {
    const href = (l) => `${strings.letterHref}?${encodeURIComponent(l.key)}`;
    summary
      .then((data) => {
        const [latest, ...earlier] = (data?.letters || []).filter((l) => l.title && l.key);
        if (!latest) return;
        document.querySelector("[data-letters-all]").hidden = false;
        const when = letter.querySelector("[data-letter-when]");
        when.textContent = longDate(latest.sentAt);
        when.hidden = !latest.sentAt;
        letter.querySelector("[data-letter-title]").textContent = latest.title;
        const text = letter.querySelector("[data-letter-text]");
        text.replaceChildren();
        if (latest.excerpt) text.append(Object.assign(document.createElement("p"), { textContent: latest.excerpt }));
        letter.querySelector("[data-letter-sign]").hidden = true;
        const link = letter.querySelector("[data-letter-link]");
        link.href = href(latest);
        link.setAttribute("aria-label", fill(letter.dataset.readLabel, { title: latest.title }));
        link.hidden = false;

        const list = document.querySelector("[data-letters-earlier]");
        if (!list || !earlier.length) return;
        list.querySelector("ul").replaceChildren(...earlier.slice(0, 4).map((l) => {
          const li = document.createElement("li");
          const a = Object.assign(document.createElement("a"), { href: href(l) });
          const time = Object.assign(document.createElement("time"), { dateTime: l.sentAt, textContent: longDate(l.sentAt) });
          a.append(Object.assign(document.createElement("span"), { textContent: l.title }), time);
          li.append(a);
          return li;
        }));
        list.hidden = false;
      })
      .catch(() => { /* offline or not deployed yet: the note stays */ });
  }

  // ---------- get involved ----------
  const I = strings.involved || {};
  const svg = (inner) => `<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">${inner}</svg>`;
  const flame = svg('<path d="M9.5 20.5h5"/><path d="M10.5 20.5v-6h3v6"/><path class="prayer__flame" d="M12 11.5c-1.6-1.2-1.6-3.1 0-5.6 1.6 2.5 1.6 4.4 0 5.6Z"/>');
  const tick = svg('<path d="m5.5 12.5 4 4 9-9.5"/>');

  // The prayer requests he marked public: open ones first with a flame, answered ones after with a tick and the day.
  // Until there are any (or offline) the note from the copy stays.
  const prayers = document.querySelector("[data-prayers]");
  if (prayers && strings.months) {
    summary.then((data) => {
      const list = (data?.prayers || []).filter((p) => p.text);
      if (!list.length) return;
      prayers.replaceChildren(...list.map((p) => {
        const li = Object.assign(document.createElement("li"), { className: `prayer${p.answeredAt ? " is-answered" : ""}` });
        li.innerHTML = p.answeredAt ? tick : flame;
        li.append(Object.assign(document.createElement("p"), { textContent: p.text }));
        if (p.answeredAt) {
          const done = Object.assign(document.createElement("p"), { className: "prayer__answered" });
          done.append(Object.assign(document.createElement("time"), { dateTime: p.answeredAt, textContent: fill(I.answered, { date: longDate(p.answeredAt) }) }));
          li.append(done);
        }
        return li;
      }));
      prayers.hidden = false;
      document.querySelector("[data-prayers-empty]").hidden = true;
    });
  }

  // The support: a plane on the dashed route to Queenstown, as far along as the monthly support is pledged.
  // It flies there when the route scrolls into view (straight there with reduced motion).
  const progress = document.querySelector("[data-progress]");
  if (progress) {
    summary.then((data) => {
      const pct = data?.support?.percentOfTarget;
      if (typeof pct !== "number") return;
      const route = progress.querySelector("[data-progress-route]");
      progress.querySelector("[data-progress-text]").textContent = fill(I.progress, { percent: pct });
      route.setAttribute("aria-label", fill(I.progressLabel, { percent: pct }));
      progress.hidden = false;
      const fly = () => route.style.setProperty("--progress", Math.min(Math.max(pct, 0), 100));
      if (reduce || !("IntersectionObserver" in window)) return fly();
      const seen = new IntersectionObserver((entries) => {
        if (!entries.some((e) => e.isIntersecting)) return;
        seen.disconnect();
        setTimeout(fly, 200);
      }, { rootMargin: "0px 0px -15% 0px" });
      seen.observe(route);
    });
  }

  // The bank details from Settings > Giving in the app. Without an IBAN (or offline) the "follow soon" note stays.
  const give = document.querySelector("[data-give-details]");
  if (give) {
    summary.then((data) => {
      const g = data?.giving;
      if (!g?.iban) return;
      for (const key of ["iban", "holder", "reference"]) {
        give.querySelector(`[data-give="${key}"]`).textContent = g[key] || "";
        give.querySelector(`[data-give-row="${key}"]`).hidden = !g[key];
      }
      const online = give.querySelector("[data-give-online]");
      if (/^https:\/\//.test(g.url || "")) { online.href = g.url; online.hidden = false; }
      give.hidden = false;
      document.querySelector("[data-give-pending]").hidden = true;
    });
  }

  // A short line at the foot of the screen after copying something.
  let toastTimer;
  const toast = (text) => {
    let el = document.querySelector(".toast");
    if (!el) {
      el = Object.assign(document.createElement("p"), { className: "toast" });
      el.setAttribute("role", "status");
      document.body.append(el);
    }
    el.textContent = text;
    requestAnimationFrame(() => el.classList.add("is-on"));
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove("is-on"), 2400);
  };
  const copy = async (text, done) => {
    try { await navigator.clipboard.writeText(text); toast(done); return true; } catch { return false; }
  };

  // Copy IBAN: without the spaces, so it pastes cleanly into a banking app. If the clipboard is blocked, select it.
  document.querySelectorAll("[data-copy]").forEach((button) =>
    button.addEventListener("click", async () => {
      const dd = document.querySelector('[data-give="iban"]');
      if (await copy(dd.textContent.replace(/\s+/g, ""), I.copied)) return;
      const r = document.createRange();
      r.selectNodeContents(dd);
      getSelection().removeAllRanges();
      getSelection().addRange(r);
    }),
  );

  // Pass it on: the phone's share sheet where there is one, otherwise copy the link to this page.
  document.querySelectorAll("[data-share]").forEach((button) =>
    button.addEventListener("click", async () => {
      const url = `${location.origin}/${document.documentElement.lang}/`;
      const S = I.share || {};
      if (navigator.share) {
        try { return await navigator.share({ title: S.title, text: S.text, url }); }
        catch (e) { if (e.name === "AbortError") return; }
      }
      copy(url, S.copied);
    }),
  );

  // Sign-up: check the two fields, post them, then thank the visitor by name in place of the form.
  const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
  document.querySelectorAll("[data-signup]").forEach((form) => {
    const S = strings.form;
    const msg = form.querySelector(".signup__msg");
    const done = form.querySelector(".signup__done");
    const button = form.querySelector("button[type=submit]");
    const label = button.querySelector("[data-label]");
    const { name: nameIn, email: mailIn } = form.elements;
    const fail = (text, input) => {
      msg.textContent = text;
      if (!input) return;
      input.setAttribute("aria-invalid", "true");
      input.focus();
      // The field shakes its head (components.css); restart it if it is already shaking
      input.classList.remove("is-shaking");
      void input.offsetWidth;
      input.classList.add("is-shaking");
    };
    form.addEventListener("animationend", (e) => e.target.classList.remove("is-shaking"));
    [nameIn, mailIn].forEach((i) => i.addEventListener("input", () => { i.removeAttribute("aria-invalid"); msg.textContent = ""; }));
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      const name = nameIn.value.trim();
      const email = mailIn.value.trim();
      if (!name) return fail(S.errName, nameIn);
      if (!EMAIL.test(email)) return fail(S.errEmail, mailIn);
      msg.textContent = "";
      button.disabled = true;
      label.textContent = S.sending;
      try {
        const res = await fetch(`${API}/v1/public/subscribe`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            name, email, lang: form.elements.lang.value || document.documentElement.lang,
            website: form.elements.website.value,
          }),
        });
        if (res.status === 429) return fail(S.errBusy);
        if (res.status === 400) {
          const j = await res.json().catch(() => ({}));
          if (j?.error?.code === "invalid_email") return fail(S.errEmail, mailIn);
          if (j?.error?.code === "invalid_name") return fail(S.errName, nameIn);
        }
        if (!res.ok) throw new Error(`http ${res.status}`);
        done.textContent = fill(S.thanks, { name, email });
        form.querySelectorAll(":scope > :not(.signup__done, .signup__privacy)").forEach((el) => (el.hidden = true));
        done.hidden = false;
        done.setAttribute("tabindex", "-1");
        done.focus();
      } catch {
        fail(S.errNetwork);
      } finally {
        button.disabled = false;
        label.textContent = S.submit;
      }
    });
  });

  // The message form on the giving page: name, email and a message, posted to /v1/public/message, where it waits in
  // the app with a follow-up for today. Wrong fields shake like in the sign-up; after sending, a thank-you takes its place.
  document.querySelectorAll("[data-message]").forEach((form) => {
    const S = strings.message;
    const msg = form.querySelector(".signup__msg");
    const done = form.querySelector(".signup__done");
    const button = form.querySelector("button[type=submit]");
    const label = button.querySelector("[data-label]");
    const { name: nameIn, email: mailIn, message: textIn } = form.elements;
    const fail = (text, input) => {
      msg.textContent = text;
      if (!input) return;
      input.setAttribute("aria-invalid", "true");
      input.focus();
      input.classList.remove("is-shaking");
      void input.offsetWidth;
      input.classList.add("is-shaking");
    };
    form.addEventListener("animationend", (e) => e.target.classList.remove("is-shaking"));
    [nameIn, mailIn, textIn].forEach((i) => i.addEventListener("input", () => { i.removeAttribute("aria-invalid"); msg.textContent = ""; }));
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      const name = nameIn.value.trim();
      const email = mailIn.value.trim();
      const message = textIn.value.trim();
      if (!name) return fail(S.errName, nameIn);
      if (!EMAIL.test(email)) return fail(S.errEmail, mailIn);
      if (!message) return fail(S.errMessage, textIn);
      if (message.length > 2000) return fail(S.errLong, textIn);
      msg.textContent = "";
      button.disabled = true;
      label.textContent = S.sending;
      try {
        const res = await fetch(`${API}/v1/public/message`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ name, email, message, lang: document.documentElement.lang, website: form.elements.website.value }),
        });
        if (res.status === 429) return fail(S.errBusy);
        if (res.status === 400) {
          const code = (await res.json().catch(() => ({})))?.error?.code;
          if (code === "invalid_email") return fail(S.errEmail, mailIn);
          if (code === "invalid_name") return fail(S.errName, nameIn);
          if (code === "invalid_message") return fail(S.errMessage, textIn);
        }
        if (!res.ok) throw new Error(`http ${res.status}`);
        done.textContent = fill(S.thanks, { name: name.split(" ")[0], email });
        form.querySelectorAll(":scope > :not(.signup__done, .signup__privacy)").forEach((el) => (el.hidden = true));
        done.hidden = false;
        done.setAttribute("tabindex", "-1");
        done.focus();
      } catch {
        fail(S.errNetwork);
      } finally {
        button.disabled = false;
        label.textContent = S.submit;
      }
    });
  });

  // ---------- the globe ----------
  // Drawn to look like the illustrations: mottled watercolour ocean and land, darker coasts, coral dry country,
  // paper specks, a hand-inked outline and a little plane flying the route.
  // Land comes from public/assets/land.json (lon/lat rings, built by build.mjs). It is painted once into an
  // equirectangular colour map; each frame samples that map per pixel, so the far side never shows through.
  function initGlobe(root) {
    const canvas = root.querySelector("canvas");
    const ctx = canvas.getContext("2d");
    const css = getComputedStyle(document.documentElement);
    const token = (name) => css.getPropertyValue(name).trim();
    const DEG = Math.PI / 180;

    const C = {
      ocean: rgb(token("--globe-ocean")),
      oceanDeep: rgb(token("--globe-ocean-deep")),
      oceanPale: rgb(token("--globe-ocean-pale")),
      land: rgb(token("--globe-land")),
      landDeep: rgb(token("--globe-land-deep")),
      landLight: rgb(token("--globe-land-light")),
      coral: rgb(token("--globe-coral")),
      coralDeep: rgb(token("--globe-coral-deep")),
      paper: rgb(token("--color-paper")),
    };
    const ink = token("--color-ink");
    const coral = token("--color-coral");
    const paper = token("--color-paper");

    // Where the route runs: from the Netherlands to Queenstown.
    const FROM = { lat: 52.37 * DEG, lon: 4.9 * DEG };
    const TO = { lat: -45.03 * DEG, lon: 168.66 * DEG };
    const toLabel = root.dataset.to || "";

    // state.lon / state.lat: the point at the centre of the view, in radians.
    // vel is a fling in radians per millisecond, spin the slow turn (eased in and out), glide what is left of an
    // arrow-key move. Dragged past a pole (LAT) the view gives less and less, and springs back when let go.
    const state = { lon: 95 * DEG, lat: 8 * DEG, vel: 0, spin: 0, glide: { lon: 0, lat: 0 }, drag: null, resumeAt: 0, last: 0, dirty: true };
    const LAT = 1.3;
    const SPIN = 0.000066; // the slow turn while nobody is touching it, about a turn every ninety seconds
    const MW = 1440;
    const MH = 720;
    let tex = makeTexture(null); // the colour map, MW × MH, as little-endian RGBA words

    // The share of the frame the sphere takes; the rest is room for the route arc and the plane.
    const BALL = 0.39;

    let S = 0; // canvas size in device pixels
    let R = 0; // sphere radius on screen, in device pixels
    let N = 0; // raster size (capped, then scaled up to 2R)
    let u = 1; // one design unit: S / 520, so the drawing scales with the frame
    let raster = null;
    let rctx = null;
    let img = null;
    let out = null;
    let samples = null; // disc pixels: x, y (−1…1), cos(c), and the index into the raster
    let grain = null;
    let running = true;
    let lastLon = NaN;
    let lastLat = NaN;

    fetch("/assets/land.json")
      .then((r) => r.json())
      .then((rings) => {
        const m = document.createElement("canvas");
        m.width = MW;
        m.height = MH;
        const mc = m.getContext("2d");
        mc.fillStyle = "#000";
        for (const ring of rings) {
          mc.beginPath();
          for (let i = 0; i < ring.length; i += 2) {
            const x = ((ring[i] + 180) / 360) * MW;
            const y = ((90 - ring[i + 1]) / 180) * MH;
            if (i === 0) mc.moveTo(x, y);
            else mc.lineTo(x, y);
          }
          mc.closePath();
          mc.fill();
        }
        const a = mc.getImageData(0, 0, MW, MH).data;
        const mask = new Float32Array(MW * MH);
        for (let k = 0; k < mask.length; k++) mask[k] = a[k * 4 + 3] / 255;
        tex = makeTexture(mask);
        state.dirty = true;
      })
      .catch(() => {
        // Without land the globe is an ocean ball with its route and pins; the page still works.
      });

    // ---------- the colour map ----------
    // Painted like the illustration's globe: land as rounded, slightly ragged blobs (no tiny islands or
    // sharp coastlines), stamped with hard-edged darker and lighter blotches and pale dry-brush scratches;
    // a grey-blue wash for the sea with pale blooms; whole stretches of dry country printed in coral.
    // Noise is taken on the unit sphere, so the texture has no seam at the date line and no pinch at the poles.
    function makeTexture(mask) {
      const words = new Uint32Array(MW * MH);
      let land = null;
      let near = null;
      if (mask) {
        // Round the coastline off, then tear it with noise, the way a brush would lay the shape down
        const soft = blur(mask, 5);
        land = new Float32Array(MW * MH);
        for (let j = 0; j < MH; j++) {
          const lat = Math.PI / 2 - ((j + 0.5) / MH) * Math.PI;
          for (let i = 0; i < MW; i++) {
            const lon = ((i + 0.5) / MW) * 2 * Math.PI - Math.PI;
            const [x, y, z] = onSphere(lat, lon);
            const k = j * MW + i;
            const tear = (fbm(x * 9 + 1, y * 9, z * 9) - 0.5) * 0.55 + (noise3(x * 34, y * 34, z * 34) - 0.5) * 0.16;
            land[k] = soft[k] + tear > 0.5 ? 1 : 0;
          }
        }
        near = blur(land, 6); // how much land is close by: < 1 on land means a coast, > 0 at sea means near one
      }
      for (let j = 0; j < MH; j++) {
        const lat = Math.PI / 2 - ((j + 0.5) / MH) * Math.PI;
        for (let i = 0; i < MW; i++) {
          const lon = ((i + 0.5) / MW) * 2 * Math.PI - Math.PI;
          const [x, y, z] = onSphere(lat, lon);
          const k = j * MW + i;
          const wash = fbm(x * 3.2, y * 3.2, z * 3.2); // big, soft variation
          // Sponge: the fine speckle of a stamped or rolled print
          const sponge = noise3(x * 42 + 7, y * 42, z * 42 - 3) * 0.65 + noise3(x * 96, y * 96 + 5, z * 96) * 0.35;
          const fleck = hash3(i, j, 5);
          let c;
          if (land && land[k]) {
            c = mix(C.land, C.landDeep, smooth(0.35, 0.8, wash) * 0.55);
            // Dry country: a whole stretch printed in coral, reaching to the coast. The inland edge is
            // warped and torn so it never reads as an oval.
            const wl = (noise3(x * 3 + 9, y * 3, z * 3) - 0.5) * 22;
            const wn = (noise3(x * 3, y * 3 + 9, z * 3) - 0.5) * 22;
            const dry = desert(lat / DEG + wl, lon / DEG + wn);
            if (dry > 0) {
              const t = smooth(0.2, 0.26, dry + (noise3(x * 18, y * 18 + 2, z * 18) - 0.5) * 0.3 + (sponge - 0.5) * 0.15);
              if (t > 0) c = mix(c, mix(C.coral, C.coralDeep, smooth(0.4, 0.8, wash) * 0.7), t);
            }
            c = mix(c, C.landLight, smooth(0.56, 0.64, sponge) * 0.55);
            c = mix(c, C.landDeep, smooth(0.36, 0.28, sponge) * 0.4);
            c = mix(c, C.landDeep, clamp01((1 - near[k]) * 1.6) * 0.25); // a touch more pigment at the edge
            // Dry-brush scratches where the paper shows through
            if (fleck > 0.975 || (sponge > 0.68 && fleck > 0.85)) c = mix(c, C.paper, 0.55);
          } else {
            c = mix(C.ocean, C.oceanDeep, smooth(0.3, 0.75, wash) * 0.7);
            const bloom = fbm(x * 4.5 - 4, y * 4.5 + 6, z * 4.5);
            c = mix(c, C.oceanPale, smooth(0.5, 0.72, bloom + (near ? near[k] * 0.2 : 0)) * 0.7); // soft watercolour blooms
            c = mix(c, C.oceanPale, smooth(0.58, 0.7, sponge) * 0.35);
            if (fleck > 0.985) c = mix(c, C.paper, 0.5);
          }
          words[k] = word(c);
        }
      }
      return words;
    }

    // Dry country, printed coral like the illustration: rough ellipses (lat, lon, half-height, half-width),
    // big enough to run out to the coast; makeTexture tears their edges.
    const DESERTS = [
      [21, 2, 12, 26], [23, 48, 10, 12], [-26, 126, 14, 22], [25, -106, 12, 14],
      [-34, -68, 16, 7], [-24, 17, 9, 9], [31, 62, 7, 12], [43, 98, 6, 14],
    ];
    function desert(lat, lon) {
      let best = 0;
      for (const [a, b, h, w] of DESERTS) {
        const d = ((lat - a) / h) ** 2 + ((lon - b) / w) ** 2;
        if (d < 1) best = Math.max(best, 1 - d);
      }
      return best;
    }

    // ---------- size ----------
    function resize() {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const cssW = root.clientWidth || 480;
      S = Math.round(cssW * dpr);
      canvas.width = S;
      canvas.height = S;
      u = S / 520;
      R = S * BALL;

      N = Math.min(Math.round(2 * R), 760);
      const r = N / 2;
      raster = document.createElement("canvas");
      raster.width = N;
      raster.height = N;
      rctx = raster.getContext("2d");
      img = rctx.createImageData(N, N);
      out = new Uint32Array(img.data.buffer);

      // Pixels inside the disc, with their unit-sphere position and the depth of the sphere there.
      const cap = Math.ceil(Math.PI * (r + 1) * (r + 1));
      samples = {
        x: new Float32Array(cap),
        y: new Float32Array(cap),
        c: new Float32Array(cap),
        at: new Uint32Array(cap),
        n: 0,
      };
      for (let j = 0; j < N; j++) {
        for (let i = 0; i < N; i++) {
          const x = (i + 0.5 - r) / r;
          const y = (r - j - 0.5) / r;
          const d = x * x + y * y;
          if (d > 1) continue;
          const k = samples.n++;
          samples.x[k] = x;
          samples.y[k] = y;
          samples.c[k] = Math.sqrt(1 - d);
          samples.at[k] = j * N + i;
        }
      }
      grain = makeGrain();
      state.dirty = true;
    }

    // A fixed print speckle laid over the sphere, like ink on rough paper. It does not turn with the globe.
    function makeGrain() {
      const g = document.createElement("canvas");
      g.width = 160;
      g.height = 160;
      const gc = g.getContext("2d");
      for (let i = 0; i < 1400; i++) {
        gc.fillStyle = i % 3 ? "rgba(255, 252, 244, 0.22)" : "rgba(40, 34, 28, 0.10)";
        const s = (0.6 + Math.random()) * u;
        gc.fillRect(Math.random() * 160, Math.random() * 160, s, s);
      }
      return ctx.createPattern(g, "repeat");
    }

    // ---------- projection (orthographic, centred on state.lon / state.lat) ----------
    function project(lat, lon, lift = 1) {
      const cp = Math.cos(lat);
      const sp = Math.sin(lat);
      const dl = lon - state.lon;
      const s1 = Math.sin(state.lat);
      const c1 = Math.cos(state.lat);
      const z = s1 * sp + c1 * cp * Math.cos(dl);
      return {
        X: S / 2 + cp * Math.sin(dl) * lift * R,
        Y: S / 2 - (c1 * sp - s1 * cp * Math.cos(dl)) * lift * R,
        z,
        // A lifted point stays visible a little past the rim, as it would in the air over the edge.
        seen: z > -Math.sqrt(Math.max(0, 1 - 1 / (lift * lift))) - 0.001,
      };
    }

    // Paint the sphere: for each disc pixel, look up the colour map at that point of the globe.
    function paint() {
      const sp = Math.sin(state.lat);
      const cp = Math.cos(state.lat);
      const { x: xs, y: ys, c: cs, at } = samples;
      for (let k = 0; k < samples.n; k++) {
        const x = xs[k];
        const y = ys[k];
        const lat = Math.asin(cs[k] * sp + y * cp);
        let t = (state.lon + Math.atan2(x, cp * cs[k] - y * sp)) / (2 * Math.PI) + 0.5;
        t -= Math.floor(t);
        const col = Math.min(MW - 1, (t * MW) | 0);
        const row = Math.min(MH - 1, Math.max(0, (((Math.PI / 2 - lat) / Math.PI) * MH) | 0));
        out[at[k]] = tex[row * MW + col];
      }
      rctx.putImageData(img, 0, 0);
    }

    // ---------- the route: a great circle, arcing up off the surface ----------
    function routePoints(steps) {
      const v = (p) => [Math.cos(p.lat) * Math.cos(p.lon), Math.cos(p.lat) * Math.sin(p.lon), Math.sin(p.lat)];
      const a = v(FROM);
      const b = v(TO);
      const theta = Math.acos(Math.min(1, Math.max(-1, a[0] * b[0] + a[1] * b[1] + a[2] * b[2])));
      const pts = [];
      for (let i = 0; i <= steps; i++) {
        const t = i / steps;
        const s0 = Math.sin((1 - t) * theta) / Math.sin(theta);
        const s1 = Math.sin(t * theta) / Math.sin(theta);
        const p = [0, 1, 2].map((k) => s0 * a[k] + s1 * b[k]);
        pts.push({ lat: Math.asin(p[2]), lon: Math.atan2(p[1], p[0]), lift: 1 + 0.2 * Math.sin(Math.PI * t) });
      }
      return pts;
    }
    const route = routePoints(220);

    function drawRoute() {
      ctx.save();
      ctx.strokeStyle = ink;
      ctx.lineWidth = 2.6 * u;
      ctx.lineCap = "round";
      ctx.setLineDash([11 * u, 8 * u]);
      ctx.beginPath();
      let pen = false;
      for (const p of route) {
        const q = project(p.lat, p.lon, p.lift);
        if (q.seen) {
          if (pen) ctx.lineTo(q.X, q.Y);
          else ctx.moveTo(q.X, q.Y);
          pen = true;
        } else {
          pen = false;
        }
      }
      ctx.stroke();
      ctx.restore();
    }

    // The plane: an ink silhouette pointing along +x, 1 unit long.
    const PLANE = new Path2D(planePath);

    function drawPlane(t) {
      const i = Math.min(route.length - 2, Math.max(0, Math.round(t * (route.length - 1))));
      const p = route[i];
      const q = project(p.lat, p.lon, p.lift);
      if (!q.seen) return;
      const n = project(route[i + 1].lat, route[i + 1].lon, route[i + 1].lift);
      ctx.save();
      ctx.translate(q.X, q.Y);
      ctx.rotate(Math.atan2(n.Y - q.Y, n.X - q.X));
      ctx.scale(54 * u, 54 * u); // big and bold, like the jet in the illustration
      ctx.fillStyle = ink;
      ctx.fill(PLANE);
      ctx.restore();
    }

    // ---------- pins ----------
    function origin(p) {
      const q = project(p.lat, p.lon);
      if (q.z <= 0) return;
      ctx.save();
      ctx.fillStyle = paper;
      ctx.strokeStyle = ink;
      ctx.lineWidth = 2.2 * u;
      ctx.beginPath();
      ctx.arc(q.X, q.Y, 5 * u, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.restore();
    }

    // The destination: a coral map pin standing on the spot, with a short label beside it.
    function destination(p) {
      const q = project(p.lat, p.lon);
      if (q.z <= 0.02) return;
      const s = 16 * u * (0.6 + 0.4 * Math.min(1, q.z * 2)); // shrinks a little towards the rim
      ctx.save();
      ctx.translate(q.X, q.Y);
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.bezierCurveTo(-s * 0.35, -s * 0.9, -s, -s * 1.3, -s, -s * 2);
      ctx.arc(0, -s * 2, s, Math.PI, 0);
      ctx.bezierCurveTo(s, -s * 1.3, s * 0.35, -s * 0.9, 0, 0);
      ctx.closePath();
      ctx.fillStyle = coral;
      ctx.fill();
      ctx.lineWidth = 2.2 * u;
      ctx.lineJoin = "round";
      ctx.strokeStyle = ink;
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(0, -s * 2, s * 0.38, 0, Math.PI * 2);
      ctx.fillStyle = paper;
      ctx.fill();
      ctx.stroke();
      if (toLabel) {
        // On the side that faces the middle of the globe, so the label never runs off the edge
        const left = q.X > S / 2;
        ctx.font = `650 ${14 * u}px Archivo, system-ui, sans-serif`;
        ctx.textAlign = left ? "right" : "left";
        ctx.textBaseline = "middle";
        ctx.lineJoin = "round";
        ctx.lineWidth = 5 * u;
        ctx.strokeStyle = paper;
        const x = (left ? -1 : 1) * s * 1.5;
        ctx.strokeText(toLabel, x, -s * 2);
        ctx.fillStyle = ink;
        ctx.fillText(toLabel, x, -s * 2);
      }
      ctx.restore();
    }

    // ---------- the paint's edge and the inked outline ----------
    // The wash stops at a slightly wobbly edge. The ink circle is drawn over it a touch off register, like a
    // second print pass, and only part way round: it swells on the lower right and runs out on the upper left.
    function paintEdge(path) {
      const c = S / 2;
      for (let i = 0; i <= 120; i++) {
        const a = (i / 120) * Math.PI * 2;
        const r = R * (0.99 + 0.006 * Math.sin(a * 5 + 1) + 0.004 * Math.sin(a * 11 + 2)); // never past the sphere
        const x = c + Math.cos(a) * r;
        const y = c + Math.sin(a) * r;
        if (i === 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.closePath();
    }

    function outline() {
      const cx = S / 2 + R * 0.006;
      const cy = S / 2 + R * 0.004;
      const steps = 240;
      ctx.save();
      ctx.strokeStyle = ink;
      ctx.lineCap = "round";
      let prev = null;
      for (let i = 0; i <= steps; i++) {
        const a = (i / steps) * Math.PI * 2; // 0 = right, π/2 = bottom (y points down)
        const r = R * (1 + 0.004 * Math.sin(a * 3 + 0.4) + 0.003 * Math.sin(a * 7 + 1.3));
        const p = [cx + Math.cos(a) * r, cy + Math.sin(a) * r];
        // Distance from the upper left (a = 225°), where the pen lifts
        let d = Math.abs(a - 1.25 * Math.PI);
        d = Math.min(d, 2 * Math.PI - d);
        const w = smooth(0.5, 1.15, d) * (0.75 + 0.25 * Math.max(0, Math.cos(a - Math.PI / 4)));
        if (prev && w > 0.02) {
          ctx.lineWidth = 4.2 * u * w;
          ctx.beginPath();
          ctx.moveTo(prev[0], prev[1]);
          ctx.lineTo(p[0], p[1]);
          ctx.stroke();
        }
        prev = p;
      }
      ctx.restore();
    }

    // ---------- one frame ----------
    function draw(now) {
      const c = S / 2;
      ctx.clearRect(0, 0, S, S);

      if (state.dirty || state.lon !== lastLon || state.lat !== lastLat) {
        paint();
        lastLon = state.lon;
        lastLat = state.lat;
        state.dirty = false;
      }
      // The sphere, flat like a print (no shading), cut to the paint's edge, with the print grain over it
      ctx.save();
      ctx.beginPath();
      paintEdge(ctx);
      ctx.clip();
      ctx.imageSmoothingEnabled = true;
      ctx.drawImage(raster, c - R, c - R, 2 * R, 2 * R);
      ctx.fillStyle = grain;
      ctx.fillRect(0, 0, S, S);
      ctx.restore();

      outline();
      drawRoute();
      origin(FROM);
      destination(TO);

      // The plane flies the route in about nine seconds, then waits a moment at Queenstown and starts again.
      const t = reduce ? 0.42 : Math.min(1, ((now / 1000) % 12) / 9);
      drawPlane(t);
    }

    // ---------- motion ----------
    // Measured in time, not frames, so it feels the same at 60 and 120 Hz. A fling coasts and slows like a scroll
    // view on a phone; the slow turn fades back in after a pause instead of jumping on.
    function step(now) {
      const dt = Math.min(now - (state.last || now), 50);
      state.last = now;
      if (state.drag) return;
      if (Math.abs(state.vel) > 1e-6) {
        state.lon += state.vel * dt;
        state.vel *= Math.exp(-dt / 380);
      } else state.vel = 0;
      const want = !reduce && now > state.resumeAt && Math.abs(state.vel) < SPIN ? SPIN : 0;
      state.spin += (want - state.spin) * (1 - Math.exp(-dt / 900));
      state.lon += state.spin * dt;
      // Arrow keys glide to where they point; another press adds on, so holding a key turns it smoothly
      const k = 1 - Math.exp(-dt / 120);
      state.lon += state.glide.lon * k;
      state.lat += state.glide.lat * k;
      state.glide.lon *= 1 - k;
      state.glide.lat *= 1 - k;
      // Past a pole the view springs back
      const over = state.lat - Math.max(-LAT, Math.min(LAT, state.lat));
      if (over) state.lat -= over * (1 - Math.exp(-dt / 90));
    }

    function frame(now) {
      if (running) {
        step(now);
        draw(now);
      }
      requestAnimationFrame(frame);
    }

    // ---------- pointer and keyboard ----------
    function nudge(dLon, dLat) {
      const lat = state.lat + state.glide.lat;
      state.glide.lon += dLon;
      state.glide.lat += Math.max(-LAT, Math.min(LAT, lat + dLat)) - lat;
      state.vel = 0;
      state.resumeAt = performance.now() + 4000;
    }

    // Past a pole the drag gives less and less, like pulling a list past its end
    const rubber = (lat) => {
      const over = Math.abs(lat) - LAT;
      if (over <= 0) return lat;
      return Math.sign(lat) * (LAT + (1 - 1 / ((over * 0.55) / 0.4 + 1)) * 0.4);
    };

    root.addEventListener("pointerdown", (e) => {
      // Grabbing catches it: the fling, the glide and the slow turn stop under the finger
      const now = performance.now();
      state.drag = { x: e.clientX, y: e.clientY, lat: state.lat, samples: [{ t: now, lon: state.lon }] };
      state.vel = 0;
      state.spin = 0;
      state.glide.lon = state.glide.lat = 0;
      root.setPointerCapture(e.pointerId);
      root.classList.add("is-dragging");
    });

    root.addEventListener("pointermove", (e) => {
      const d = state.drag;
      if (!d) return;
      const dpr = S / (root.clientWidth || 1);
      const now = performance.now();
      state.lon -= ((e.clientX - d.x) * dpr) / R;
      d.lat += ((e.clientY - d.y) * dpr) / R;
      state.lat = rubber(d.lat);
      d.x = e.clientX;
      d.y = e.clientY;
      // Keep the last 100 ms of movement, so the fling follows the flick and not one jittery event
      d.samples.push({ t: now, lon: state.lon });
      while (d.samples.length > 2 && now - d.samples[0].t > 100) d.samples.shift();
    });

    const endDrag = () => {
      const d = state.drag;
      if (!d) return;
      state.drag = null;
      const now = performance.now();
      const first = d.samples[0];
      const end = d.samples[d.samples.length - 1];
      // A finger that stopped before letting go leaves it standing; a flick sets it coasting
      const v = now - end.t < 60 && end.t > first.t ? (end.lon - first.lon) / (end.t - first.t) : 0;
      state.vel = Math.max(-0.012, Math.min(0.012, v));
      state.last = now;
      state.resumeAt = now + 2500;
      root.classList.remove("is-dragging");
    };
    root.addEventListener("pointerup", endDrag);
    root.addEventListener("pointercancel", endDrag);

    root.addEventListener("keydown", (e) => {
      const keys = {
        ArrowLeft: [-0.08, 0],
        ArrowRight: [0.08, 0],
        ArrowUp: [0, 0.06],
        ArrowDown: [0, -0.06],
      };
      const move = keys[e.key];
      if (!move) return;
      e.preventDefault();
      nudge(...move);
    });

    // Only spend time on the globe while it is on screen
    new IntersectionObserver((entries) => {
      running = entries.some((en) => en.isIntersecting);
    }).observe(root);

    new ResizeObserver(resize).observe(root);
    resize();
    document.fonts?.ready.then(() => (state.dirty = true));
    requestAnimationFrame(frame);
  }

  // ---------- small helpers ----------
  function rgb(hex) {
    const n = parseInt(hex.replace("#", ""), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  function mix(a, b, t) {
    return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
  }
  function clamp01(v) {
    return v < 0 ? 0 : v > 1 ? 1 : v;
  }
  function smooth(a, b, v) {
    const t = clamp01((v - a) / (b - a));
    return t * t * (3 - 2 * t);
  }
  // [r, g, b] → the little-endian word a Uint32Array wants for an opaque pixel (alpha 255).
  function onSphere(lat, lon) {
    const cl = Math.cos(lat);
    return [cl * Math.cos(lon), cl * Math.sin(lon), Math.sin(lat)];
  }
  function word(c) {
    return ((255 << 24) | ((c[2] | 0) << 16) | ((c[1] | 0) << 8) | (c[0] | 0)) >>> 0;
  }

  // A fast integer hash → 0…1
  function hash3(x, y, z) {
    let h = (x * 374761393 + y * 668265263 + z * 2147483647) | 0;
    h = Math.imul(h ^ (h >>> 13), 1274126177);
    return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
  }
  // Smooth 3D value noise and a three-octave sum of it, both 0…1
  function noise3(x, y, z) {
    const xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z);
    const xf = x - xi, yf = y - yi, zf = z - zi;
    const sx = xf * xf * (3 - 2 * xf), sy = yf * yf * (3 - 2 * yf), sz = zf * zf * (3 - 2 * zf);
    const l = (a, b, t) => a + (b - a) * t;
    const h = (i, j, k) => hash3(xi + i, yi + j, zi + k);
    return l(
      l(l(h(0, 0, 0), h(1, 0, 0), sx), l(h(0, 1, 0), h(1, 1, 0), sx), sy),
      l(l(h(0, 0, 1), h(1, 0, 1), sx), l(h(0, 1, 1), h(1, 1, 1), sx), sy),
      sz,
    );
  }
  function fbm(x, y, z) {
    return noise3(x, y, z) * 0.55 + noise3(x * 2.1, y * 2.1, z * 2.1) * 0.3 + noise3(x * 4.3, y * 4.3, z * 4.3) * 0.15;
  }

  // Box blur of a W × H float map (wrapping left–right, clamped top–bottom), r pixels each way.
  function blur(src, r) {
    const W = 1440;
    const H = src.length / W;
    const tmp = new Float32Array(src.length);
    const dst = new Float32Array(src.length);
    const n = 2 * r + 1;
    for (let j = 0; j < H; j++) {
      for (let i = 0; i < W; i++) {
        let s = 0;
        for (let d = -r; d <= r; d++) s += src[j * W + ((i + d + W) % W)];
        tmp[j * W + i] = s / n;
      }
    }
    for (let j = 0; j < H; j++) {
      for (let i = 0; i < W; i++) {
        let s = 0;
        for (let d = -r; d <= r; d++) s += tmp[Math.min(H - 1, Math.max(0, j + d)) * W + i];
        dst[j * W + i] = s / n;
      }
    }
    return dst;
  }
})();
