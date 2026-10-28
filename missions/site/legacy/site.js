// hesent.me: live day count, prayer, sign-up and copy. The page works without this file.
(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const S = JSON.parse($("#strings").textContent);
  const API = (document.querySelector('meta[name="hesent-api"]')?.content || "").replace(/\/+$/, "");
  const LANG = document.documentElement.lang;
  const calm = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const fill = (t, v) => t.replace(/\{(\w+)\}/g, (_, k) => v[k] ?? "");

  // ---------- toast ----------
  const toastEl = $("[data-toast]");
  let toastTimer;
  function toast(text) {
    $("[data-toast-tx]").textContent = text;
    toastEl.classList.add("on");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove("on"), 2600);
  }

  // ---------- days until departure ----------
  function amsterdamToday() {
    const p = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Amsterdam", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
    return Date.parse(p + "T00:00:00Z");
  }
  function showDays(departure, days) {
    const box = $("[data-days]");
    if (!box) return;
    if (!Number.isFinite(days)) {
      if (!departure) return;
      days = Math.round((Date.parse(departure + "T00:00:00Z") - amsterdamToday()) / 864e5);
    }
    const cap = $("[data-days-cap]");
    cap.textContent = days >= 0 ? cap.dataset.capBefore : cap.dataset.capAfter;
    $("[data-days-n]").textContent = Math.abs(days);
    if (departure) {
      const [y, m] = departure.split("-").map(Number);
      $$("[data-departure-text]").forEach((el) => (el.textContent = `${S.months[m - 1]} ${y}`));
    }
  }

  // ---------- prayer ----------
  const prayerEl = $("[data-prayer-text]");
  const amen = $("[data-amen]");
  let prayers = S.pray.fallback;
  let pi = 0;
  $("[data-pray]").addEventListener("click", () => {
    amen.classList.add("on");
    // Each press moves on to the next prayer point, so people see the list.
    pi = (pi + 1) % prayers.length;
    setTimeout(() => {
      prayerEl.textContent = prayers[pi];
      amen.classList.remove("on");
    }, calm ? 0 : 1200);
  });

  // ---------- live data ----------
  async function load() {
    const departure = $("[data-days]")?.dataset.departure;
    let data = null;
    try {
      const ctl = new AbortController();
      const t = setTimeout(() => ctl.abort(), 6000);
      const res = await fetch(`${API}/v1/public/summary?tz=Europe/Amsterdam`, { signal: ctl.signal });
      clearTimeout(t);
      if (res.ok) data = await res.json();
    } catch { /* offline or not deployed yet: the built-in text stays */ }
    showDays(data?.departureDate || departure, data?.daysToDeparture);
    const open = (data?.prayers || []).filter((p) => !p.answeredAt && p.text);
    if (open.length) { prayers = open.map((p) => p.text); pi = 0; prayerEl.textContent = prayers[0]; }
  }

  // ---------- sign-up ----------
  const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
  $$("[data-api-form]").forEach((form) => {
    const msg = $(".msg", form), btn = $("button[type=submit]", form), label = $("[data-label]", btn);
    const nameIn = form.elements.name, mailIn = form.elements.email;
    const fail = (text, input) => {
      msg.textContent = text;
      if (input) { input.setAttribute("aria-invalid", "true"); input.focus(); }
    };
    [nameIn, mailIn].forEach((i) => i.addEventListener("input", () => { i.removeAttribute("aria-invalid"); msg.textContent = ""; }));
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      const name = nameIn.value.trim(), email = mailIn.value.trim();
      if (!name) return fail(S.form.errName, nameIn);
      if (!EMAIL.test(email)) return fail(S.form.errEmail, mailIn);
      msg.textContent = "";
      btn.disabled = true;
      label.textContent = S.form.sending;
      try {
        const res = await fetch(`${API}/v1/public/subscribe`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ name, email, lang: LANG, wantsContact: form.elements.wantsContact.checked, website: form.elements.website.value }),
        });
        if (res.status === 429) throw Object.assign(new Error("busy"), { busy: true });
        if (res.status === 400) { const j = await res.json().catch(() => ({})); if (j?.error?.code === "invalid_email") throw Object.assign(new Error("email"), { email: true }); }
        if (!res.ok) throw new Error("http " + res.status);
        $(".done-tx", form).textContent = fill(S.form.thanks, { name, email });
        $(".done", form).hidden = false;
        form.querySelectorAll(".field, button, .msg").forEach((el) => (el.hidden = true));
      } catch (err) {
        if (err.email) fail(S.form.errEmail, mailIn);
        else fail(err.busy ? S.form.errBusy : S.form.errNetwork);
        btn.disabled = false;
        label.textContent = S.form.submit;
      }
    });
  });

  // ---------- copy IBAN ----------
  $("[data-copy]")?.addEventListener("click", async () => {
    const iban = $("[data-iban]").textContent.replace(/\s+/g, "");
    try { await navigator.clipboard.writeText(iban); toast(S.give.copied); }
    catch { const r = document.createRange(); r.selectNodeContents($("[data-iban]")); getSelection().removeAllRanges(); getSelection().addRange(r); }
  });

  // ---------- language choice sticks for the root redirect ----------
  $$("[data-lang]").forEach((a) => a.addEventListener("click", () => {
    document.cookie = `lang=${a.dataset.lang}; path=/; max-age=31536000; samesite=lax`;
  }));
  document.cookie = `lang=${LANG}; path=/; max-age=31536000; samesite=lax`;

  // ---------- the bar marks the section you're on ----------
  const links = $$("[data-nav]");
  const spy = new IntersectionObserver((entries) => {
    entries.forEach((en) => {
      if (!en.isIntersecting) return;
      links.forEach((l) => l.classList.toggle("on", l.dataset.nav === en.target.id));
    });
  }, { rootMargin: "-45% 0px -50% 0px" });
  $$("main section").forEach((s) => spy.observe(s));

  load();
})();
