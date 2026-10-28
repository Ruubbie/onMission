// hesent.me: the header on every page. It stays at the top while you scroll, folds smaller once the page has moved,
// and on the home page underlines the section you are reading. The page works without this file.
(() => {
  const header = document.querySelector(".site-header");
  if (!header) return;

  // Anchors land below the header, not under it (scroll-padding-top in components.css reads --header-now). A jump
  // always ends with the header folded, so this is the folded height, measured on a hidden copy: reading the header
  // itself would give the unfolded height at the top of the page, or a height halfway through its spring.
  const measure = () => {
    const copy = header.cloneNode(true);
    copy.classList.add("is-scrolled");
    copy.setAttribute("aria-hidden", "true");
    copy.style.cssText = "position:absolute;left:0;right:0;top:0;visibility:hidden;transition:none";
    copy.querySelectorAll("*").forEach((el) => (el.style.transition = "none"));
    document.body.append(copy);
    document.documentElement.style.setProperty("--header-now", `${copy.offsetHeight}px`);
    copy.remove();
  };
  const fold = () => header.classList.toggle("is-scrolled", scrollY > 8);
  measure();
  fold();
  addEventListener("scroll", fold, { passive: true });

  // On a phone the header tucks away while you read down the page and slides back the moment you scroll up, so the
  // two rows don't sit over the text the whole way (components.css). A jump to an anchor keeps it in place, so it
  // lands just below the header as measured above.
  const phone = matchMedia("(max-width: 859px)");
  let lastY = scrollY;
  let held = 0;
  const tuck = () => {
    const y = scrollY;
    const down = y > lastY;
    if (Math.abs(y - lastY) < 6 && y > 8) return;
    lastY = y;
    const hide = phone.matches && down && y > header.offsetHeight * 2 && Date.now() > held;
    header.classList.toggle("is-tucked", hide);
  };
  addEventListener("scroll", tuck, { passive: true });
  phone.addEventListener?.("change", tuck);
  document.addEventListener("click", (e) => {
    const a = e.target.closest?.('a[href*="#"]');
    if (!a) return;
    held = Date.now() + 1500;
    header.classList.remove("is-tucked");
  });
  addEventListener("scrollend", () => { if (Date.now() < held) held = Date.now() + 100; });
  addEventListener("resize", measure);
  document.fonts?.ready.then(measure);

  // The section you are reading: the last one whose top has passed a line a third of the way down the screen.
  const links = [...header.querySelectorAll('.nav a[href^="#"]')];
  const sections = links.map((a) => document.getElementById(a.hash.slice(1))).filter(Boolean);
  if (!sections.length) return;
  let ticking = false;
  const spy = () => {
    ticking = false;
    const line = innerHeight / 3;
    let current = null;
    for (const s of sections) if (s.getBoundingClientRect().top <= line) current = s;
    if (current && current.getBoundingClientRect().bottom < line) current = null;
    for (const a of links) {
      if (current && a.hash === `#${current.id}`) a.setAttribute("aria-current", "true");
      else a.removeAttribute("aria-current");
    }
  };
  spy();
  addEventListener("scroll", () => {
    if (!ticking) requestAnimationFrame(spy);
    ticking = true;
  }, { passive: true });
})();
