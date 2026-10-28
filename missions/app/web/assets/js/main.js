// Entry point: the phone shell, the tab bar, the page stack (each page floods out of what you tapped),
// routing (#/route), login and setup. The screens live in pages/; the look is design/tomato-flood.

import { api, session, config, setUnauthorizedHandler, ApiError, DEFAULT_API } from "./api.js";
import { store } from "./store.js";
import { I, playIcon, anim } from "./motion.js";
import { esc, toast, rise, draw, hold } from "./ui.js";
import * as today from "./pages/today.js";
import * as tasks from "./pages/tasks.js";
import * as people from "./pages/people.js";
import { countOverdue } from "./pages/tasks.js";
import { countWaiting } from "./pages/people.js";
import * as prayer from "./pages/prayer.js";
import * as move from "./pages/move.js";
import * as checklists from "./pages/checklists.js";
import * as vault from "./pages/vault.js";
import * as packing from "./pages/packing.js";
import * as budget from "./pages/budget.js";
import * as selling from "./pages/selling.js";
import * as newsletter from "./pages/newsletter.js";
import * as letter from "./pages/letter.js";
import * as arrange from "./pages/arrange.js";
import * as notes from "./pages/notes.js";
import * as guides from "./pages/guides.js";
import * as guide from "./pages/guide.js";
import * as settings from "./pages/settings.js";
import * as task from "./pages/task.js";
import * as partners from "./pages/partner.js";
import * as allpeople from "./pages/allpeople.js";
import * as search from "./pages/search.js";
import { initCapture, openCapture, closeCapture, isCaptureOpen } from "./capture.js";
import { initCheckin, openCheckin, closeCheckin, isCheckinOpen } from "./checkin.js";

// The five tabs, in the order of the tab bar (HANDOFF.md §4).
const TABS = { today, tasks, people, prayer, move };
const TAB_META = [["today", "Today", "sun"], ["tasks", "Tasks", "list"], ["people", "People", "users"], ["prayer", "Prayer", "flame"], ["move", "Move", "plane"]];
// Pages pushed above a tab. `parent` is the route they go back to, or `back(route)` gives the exact address.
const PAGES = { checklists, vault, packing, budget, selling, newsletter, letter, arrange, notes, guides, guide, settings, task, partners, allpeople, search };

let shell = null;          // the phone's elements once built
let screenTab = null;      // which tab's screen is in the DOM
let lastPoint = null;      // where the last tap was, so the page floods out of it
let lastSync = 0;

// ---------- boot ----------------------------------------------------------------------------

setUnauthorizedHandler(() => {
  session.token = null;
  store.reset();
  shell = null;
  showLogin("Your login has expired. Log in again.");
});

store.onStatus((s) => { if (s.kind === "bad" && shell) toast(s.detail || "Sync problem", { bad: true }); });
store.onData((event) => {
  if (event.type === "notice") return toast(event.message);
  if (event.type === "load") lastSync = Date.now();
  refresh();
});
document.addEventListener("app:refresh", refresh);
// Repaints only the top bar and the tab bar colour (used while a moment holds the screen).
document.addEventListener("app:chrome", () => {
  if (!shell) return;
  const r = route();
  const tab = currentTab();
  chrome(r, tab, PAGES[r.name] ?? null, makeCtx(r, tab));
});

/** Redraws quietly, unless a moment is playing (hold) or the user is typing (their text would be lost). */
function refresh() {
  if (!session.token || hold.on) return;
  const typing = /INPUT|TEXTAREA|SELECT/.test(document.activeElement?.tagName ?? "") && document.getElementById("app")?.contains(document.activeElement);
  if (!typing) render({ quiet: true });
}
window.addEventListener("hashchange", () => { if (session.token) render(); });
window.addEventListener("keydown", onShortcut);
window.addEventListener("resize", () => { if (shell) layoutTabs(); });
document.addEventListener("pointerdown", (e) => {
  const el = e.target.closest?.("button, .rw, .tile, .av, .set, .doc-card, .more");
  if (!el || !shell) return;
  const r = shell.phone.getBoundingClientRect(), b = el.getBoundingClientRect();
  lastPoint = [b.left + b.width / 2 - r.left, b.top + b.height / 2 - r.top];
}, true);
document.addEventListener("visibilitychange", () => {
  if (!document.hidden && session.token && Date.now() - lastSync > 60_000) syncNow();
});
setInterval(() => { if (session.token && !document.hidden) syncNow(); }, 5 * 60_000);

boot();

async function boot() {
  if (!session.token) return showLogin();
  try {
    await store.load();
  } catch (err) {
    if (err instanceof ApiError && err.status === 401) return;
    toast(err.message, { bad: true });
  }
  if (!location.hash) location.hash = "#/today";
  render();
}

async function syncNow() {
  try { await store.load(); } catch { /* the Settings page shows what's wrong */ }
}

// ---------- login and setup -----------------------------------------------------------------

function showLogin(message) {
  shell = null;
  const app = document.getElementById("app");
  let mode = "login";
  app.innerHTML = `<div class="app-wrap"><div class="phone">
    <form class="login" id="loginForm" novalidate>
      <div class="hand" style="font-size:34px">Hello again</div>
      <h1>Log in</h1>
      <p style="font-size:15px;line-height:1.5;opacity:.85">Your tasks, people, budget and documents, the same as on the iPhone.</p>
      <label>Email <input name="email" type="email" autocomplete="username" placeholder="you@example.nl" required></label>
      <label>Password <input name="password" type="password" autocomplete="current-password" placeholder="Password" required></label>
      <div id="setupRows" hidden>
        <label>Your name <input name="name" type="text" autocomplete="name" placeholder="Your name"></label>
        <label>Setup secret (first time only) <input name="secret" type="password" autocomplete="off" placeholder="From the server's .env"></label>
      </div>
      <details><summary>Server address</summary>
        <label style="margin-top:10px">Server <input name="server" type="url" value="${esc(config.apiUrl)}" placeholder="${esc(DEFAULT_API)}"></label>
      </details>
      <div class="err" id="loginErr" role="alert">${esc(message || "")}</div>
      <button class="btn f" type="submit" id="loginSubmit">Log in</button>
      <button class="link" type="button" id="loginMode">First time? Create account</button>
    </form></div></div>`;
  const form = document.getElementById("loginForm");
  const err = document.getElementById("loginErr");
  const submit = document.getElementById("loginSubmit");
  document.getElementById("loginMode").addEventListener("click", () => {
    mode = mode === "login" ? "setup" : "login";
    form.querySelector("#setupRows").hidden = mode === "login";
    submit.textContent = mode === "login" ? "Log in" : "Create account";
    document.getElementById("loginMode").textContent = mode === "login" ? "First time? Create account" : "Back to log in";
    err.textContent = "";
  });
  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const f = Object.fromEntries(new FormData(form));
    err.textContent = "";
    if (f.server.trim() && f.server.trim() !== config.apiUrl) config.apiUrl = f.server;
    submit.disabled = true;
    submit.textContent = "Working…";
    try {
      const res = mode === "login"
        ? await api.login(f.email.trim(), f.password)
        : await api.setup(f.secret, f.email.trim(), f.password, f.name.trim());
      session.token = res.token;
      location.hash = "#/today";
      await store.load();
      render();
    } catch (error) {
      err.textContent = error.message;
      submit.disabled = false;
      submit.textContent = mode === "login" ? "Log in" : "Create account";
    }
  });
  form.querySelector("input").focus();
}

// ---------- the phone -------------------------------------------------------------------------

function buildShell() {
  const app = document.getElementById("app");
  app.innerHTML = `<div class="app-wrap"><div class="phone" id="ph" data-bar="cream">
    <div class="top" id="topbar"><button class="round hide" id="back" aria-label="Back">${I.back}</button><span class="kicker" id="kick"></span><a class="dsearch" href="#/search">${I.search}<span>Search</span><kbd>Ctrl K</kbd></a><button class="round hide" id="gear" aria-label="Settings">${I.gear}</button><span class="tsp"></span></div>
    <button class="round" id="plus" aria-label="Add">${I.plus}<span class="lb">New</span><kbd>Ctrl N</kbd></button>
    <div id="screens"></div>
    <div id="pages"></div>
    <div id="ansFlood" aria-hidden="true"></div>
    <nav class="tabbar" id="tabbar" aria-label="Tabs"></nav>
    <div id="toast" role="status"><span class="tic">${I.check}</span><span id="toastTx"></span></div>
    <div id="cap" aria-hidden="true"></div>
    <div id="chk" aria-hidden="true"></div>
  </div></div>`;
  const phone = document.getElementById("ph");
  const bar = document.getElementById("tabbar");
  bar.innerHTML = `<i class="tabpill" id="tabpill"></i><div class="brand">Missie</div>` + TAB_META.map(([id, label, ic]) =>
    `<button class="tab" data-tab="${id}" aria-label="${label}"><span class="ic">${I[ic]}<i class="dot"></i></span><span class="lb">${label}</span></button>`).join("")
    + `<div class="side-foot"><a href="#/search">${I.search}Search</a><a href="#/settings">${I.gear}Settings</a></div>`;
  bar.addEventListener("click", (e) => {
    const b = e.target.closest(".tab");
    if (!b) return;
    if (b.dataset.tab === currentTab()) return render();
    location.hash = `#/${b.dataset.tab}`;
  });
  document.getElementById("back").addEventListener("click", () => {
    const r = route();
    const P = PAGES[r.name];
    location.hash = P?.back ? P.back(r) : `#/${P?.parent ?? "today"}`;
  });
  document.getElementById("gear").addEventListener("click", () => { location.hash = "#/settings"; });
  document.getElementById("plus").addEventListener("click", () => (isCaptureOpen() ? closeCapture() : openCapture()));
  initCapture();
  initCheckin();
  initSheetLift(phone);
  shell = {
    phone, bar, screens: document.getElementById("screens"), pages: document.getElementById("pages"),
    kick: document.getElementById("kick"), back: document.getElementById("back"), gear: document.getElementById("gear"),
    plus: document.getElementById("plus"), flood: document.getElementById("ansFlood"),
  };
  layoutTabs();
}

const sideQuery = matchMedia("(min-width: 900px)");
const NAV_WIDTH = 240; // keep in step with --nav in app.css
const BAR_HEIGHT = 84; // keep in step with --bar in app.css
// Crossing the breakpoint swaps the phone screens for the desktop ones, so draw them again.
sideQuery.addEventListener("change", () => { if (shell) { layoutTabs(); render({ quiet: true }); } });

/** The width the sidebar takes up and the height of the header bar, so pushed pages start beside and below them. */
function navWidth() {
  return sideQuery.matches ? NAV_WIDTH : 0;
}
function barHeight() {
  return sideQuery.matches ? BAR_HEIGHT : 0;
}

/**
 * Positions the tab pill and the tabs. On a phone the active tab grows into the pill and the others
 * share the rest of the bar. On a desktop the tabs stack down the sidebar and the pill sits behind the
 * active one.
 */
function layoutTabs() {
  if (!shell) return;
  const active = screenTab ?? "today";
  const pill = shell.bar.querySelector("#tabpill");
  const width = shell.bar.clientWidth - 24;
  const act = 126, rest = (width - act) / (TAB_META.length - 1);
  let x = 12, y = 172;
  shell.bar.querySelectorAll(".tab").forEach((b) => {
    const on = b.dataset.tab === active;
    b.classList.toggle("on", on);
    if (sideQuery.matches) {
      b.style.left = "12px";
      b.style.width = "calc(100% - 24px)";
      b.style.top = `${y}px`;
      if (on) {
        pill.style.left = "12px";
        pill.style.width = "calc(100% - 24px)";
        pill.style.top = `${y}px`;
      }
      y += 52;
      return;
    }
    const w = on ? act : rest;
    b.style.top = "";
    b.style.left = `${x}px`;
    b.style.width = `${w}px`;
    if (on) {
      pill.style.top = "";
      pill.style.left = `${x + 4}px`;
      pill.style.width = `${w - 8}px`;
    }
    x += w;
  });
}

function paintBadges() {
  const counts = { tasks: countOverdue(), people: countWaiting() };
  shell.bar.querySelectorAll(".tab").forEach((b) => {
    const n = counts[b.dataset.tab] ?? 0;
    const dot = b.querySelector(".dot");
    dot.style.display = n > 0 && b.dataset.tab !== screenTab ? "" : "none";
  });
}

// ---------- routing and rendering ------------------------------------------------------------

function route() {
  const [name, id] = location.hash.replace(/^#\/?/, "").split("/");
  return { name: name || "today", id: id ? decodeURIComponent(id) : null };
}

/** The tab a route sits on: its own name for a tab, or the tab it was pushed from. */
function currentTab() {
  let name = route().name;
  while (PAGES[name]) name = PAGES[name].parent;
  return TABS[name] ? name : "today";
}

function makeCtx(r, tab, quiet = false) {
  return {
    id: r.id,
    name: r.name,
    tab,
    quiet,
    go: (to) => { location.hash = `#/${to}`; },
    refresh: () => render({ quiet: true }),
    root: null,
  };
}

/**
 * Draws the current tab and any page above it. quiet = a data change or a redraw of the same
 * screen, so nothing re-animates and scroll positions are kept.
 */
function render({ quiet = false } = {}) {
  if (!session.token) return showLogin();
  if (!shell) buildShell();
  const r = route();
  const isPage = !!PAGES[r.name];
  if (!isPage && !TABS[r.name]) { location.hash = "#/today"; return; }
  const tab = currentTab();
  const ctx = makeCtx(r, tab, quiet);

  // The tab underneath. A quiet redraw rebuilds it too, but nothing animates and scroll is kept.
  const scroll = keepScroll(shell.screens);
  const tabUp = screenTab === tab && raised(shell.screens);
  shell.screens.innerHTML = `<section class="scr on" id="s-${tab}">${TABS[tab].build(ctx)}</section>`;
  ctx.root = shell.screens.firstElementChild;
  TABS[tab].init?.(ctx.root, ctx);
  if (tabUp) raise(ctx.root, true);
  restoreScroll(shell.screens, scroll);
  if (screenTab !== tab) {
    screenTab = tab;
    layoutTabs();
    playIcon(shell.bar.querySelector(`.tab[data-tab="${tab}"] svg`), 140);
  }
  if (!quiet) { rise(ctx.root, 0); draw(ctx.root, 120); }

  // The page above, if any. Only a page whose route is new floods out of the tap.
  const pageScroll = keepScroll(shell.pages);
  const previous = shell.pages.querySelector(".pg");
  if (isPage) {
    const P = PAGES[r.name];
    const isNew = !previous || previous.dataset.route !== location.hash;
    const pageUp = !isNew && raised(shell.pages);
    shell.pages.innerHTML = `<section class="pg ${P.cream ? "cream" : ""}" data-route="${esc(location.hash)}">${P.build(ctx)}</section>`;
    const el = shell.pages.firstElementChild;
    ctx.root = el;
    P.init?.(el, ctx);
    if (pageUp) raise(el, true);
    if (!isNew) restoreScroll(shell.pages, pageScroll);
    if (isNew && !quiet) {
      const [x, y] = lastPoint ?? [shell.phone.clientWidth / 2, 430];
      el.style.setProperty("--ox", `${x - navWidth()}px`);
      el.style.setProperty("--oy", `${y - barHeight()}px`);
      el.getBoundingClientRect();
      el.classList.add("open");
      rise(el, 140);
      draw(el, 220);
    } else {
      el.classList.add("open");
    }
  } else {
    shell.pages.replaceChildren();
  }

  chrome(r, tab, isPage ? PAGES[r.name] : null, ctx);
  paintBadges();
  document.title = `${(isPage ? PAGES[r.name].title : TABS[tab].title) ?? "Missie"} · Missie`;
}

function keepScroll(root) {
  return [...root.querySelectorAll(".scroll, .sheet, .scr, .pg")].map((el) => el.scrollTop);
}
// On a desktop the screen itself scrolls, so its own position is kept as well as its lists'.
function restoreScroll(root, values) {
  root.querySelectorAll(".scroll, .sheet, .scr, .pg").forEach((el, i) => { if (values[i]) el.scrollTop = values[i]; });
}

// ---------- the sheet rises ------------------------------------------------------------------
// On a phone the sheet starts under the poster. Scroll it (wheel, finger or keys) and it rises to the top bar;
// pull down at its top, or tap its handle, and it drops back. See "The sheet rises" in app.css.

function raised(root) {
  return !!root.querySelector(".sheet.up");
}

/** Raises the sheet in a screen or page; `still` puts it up without the slide (a quiet redraw). */
function raise(root, still = false) {
  const sheet = root.querySelector(".sheet");
  if (!sheet) return;
  if (still) {
    sheet.classList.add("still");
    requestAnimationFrame(() => requestAnimationFrame(() => sheet.classList.remove("still")));
  }
  sheet.classList.add("up");
}

/** What scrolls inside a sheet: its list (.scroll) when it has one, otherwise the sheet itself. */
function scrollerIn(sheet, target) {
  return target.closest?.(".scroll") ?? sheet;
}

function initSheetLift(phone) {
  const sheetAt = (target) => (sideQuery.matches ? null : target.closest?.(".scr .sheet, .pg .sheet"));
  const up = (sheet, on) => sheet.classList.toggle("up", on);
  phone.addEventListener("scroll", (e) => {
    const sheet = e.target instanceof Element && sheetAt(e.target);
    if (sheet && e.target.scrollTop > 6) up(sheet, true);
  }, true);
  phone.addEventListener("wheel", (e) => {
    const sheet = sheetAt(e.target);
    if (!sheet) return;
    if (e.deltaY > 0) up(sheet, true);
    else if (e.deltaY < 0 && scrollerIn(sheet, e.target).scrollTop <= 0) up(sheet, false);
  }, { passive: true });
  let start = null;
  phone.addEventListener("touchstart", (e) => {
    const sheet = sheetAt(e.target);
    start = sheet ? { sheet, y: e.touches[0].clientY, top: scrollerIn(sheet, e.target).scrollTop } : null;
  }, { passive: true });
  phone.addEventListener("touchmove", (e) => {
    if (!start) return;
    const dy = e.touches[0].clientY - start.y;
    if (dy < -12) up(start.sheet, true);
    else if (dy > 48 && start.top <= 0) up(start.sheet, false);
  }, { passive: true });
  phone.addEventListener("touchend", () => { start = null; });
  // The handle: the strip along the sheet's top edge.
  phone.addEventListener("click", (e) => {
    const sheet = sheetAt(e.target);
    if (!sheet || e.target !== sheet) return;
    if (e.clientY - sheet.getBoundingClientRect().top < 26) up(sheet, !sheet.classList.contains("up"));
  });
}

/** The top bar, the + and the tab bar's colour, all from what's on screen. */
function chrome(r, tab, P, ctx) {
  const { phone, kick, back, gear, plus } = shell;
  const kickText = P ? (typeof P.kick === "function" ? P.kick(ctx) : P.kick ?? P.title) : (TABS[tab].kick ? TABS[tab].kick(ctx) : dateKick());
  if (kick.textContent !== kickText) {
    kick.textContent = kickText;
    anim(kick, [{ opacity: 0, transform: "translateY(4px)" }, { opacity: 1, transform: "none" }], { duration: 300 });
  }
  back.classList.toggle("hide", !P);
  gear.classList.toggle("hide", !!P || tab !== "move");
  const capOpen = isCaptureOpen();
  const checkOpen = isCheckinOpen();
  plus.classList.toggle("gone", !!P || checkOpen);
  plus.classList.toggle("x", capOpen);
  plus.setAttribute("aria-label", capOpen ? "Close" : "Add");
  // Cream pages and the capture take dark text; everything on tomato takes cream.
  const ink = (P && P.cream) || capOpen;
  phone.classList.toggle("creampg", !!ink && !checkOpen);
  phone.classList.toggle("ink", !!ink);
  phone.classList.toggle("pgcream", !!(P && P.cream));
  // The tab bar takes the colour of what sits at the bottom of the screen (HANDOFF.md §4).
  phone.dataset.bar = barMode(P, tab);
}

function barMode(P, tab) {
  if (shell.flood.classList.contains("on")) return "gold";
  if (P) return "cream";
  if (TABS[tab].bar?.() === "flood") return "flood";
  return tab === "prayer" ? "flood" : "cream";
}

function dateKick() {
  const s = new Date().toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" });
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// ---------- keyboard -------------------------------------------------------------------------

function onShortcut(e) {
  if (!session.token) return;
  const mod = e.ctrlKey || e.metaKey;
  if (mod && e.key.toLowerCase() === "k") { e.preventDefault(); location.hash = "#/search"; return; }
  if (mod && e.key.toLowerCase() === "n") { e.preventDefault(); openCapture(); return; }
  if (mod && e.key === ",") { e.preventDefault(); location.hash = "#/settings"; return; }
  if (mod && /^[1-5]$/.test(e.key)) { e.preventDefault(); location.hash = `#/${TAB_META[+e.key - 1][0]}`; return; }
  if (e.key === "Escape") {
    if (isCaptureOpen()) closeCapture();
    else if (isCheckinOpen()) closeCheckin();
  }
}

