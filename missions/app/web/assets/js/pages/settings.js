// Settings: your mission (the departure date, the support target, the NZD rate), the giving details that
// hesent.me shows under Get involved (via /v1/public/summary), this browser (the
// server, sync, a backup) and your account. Port of prototype.html PAGES.settings.

import { api, config, session, DEFAULT_API } from "../api.js";
import { store } from "../store.js";
import { I, anim, spring } from "../motion.js";
import { esc, toast, pop } from "../ui.js";
import { download, parseCents, plainMoney } from "../util.js";

export const title = "Settings";
export const parent = "move";
export const kick = "Settings";

export function build() {
  const s = store.settings();
  const dep = s.departureDate ? new Date(`${s.departureDate}T12:00:00`).toLocaleDateString("en-GB", { day: "2-digit", month: "2-digit" }).replace("/", ".") : "—";
  const st = store.status();
  return `
    <div class="abs hand hi in">Your mission</div>
    <div class="abs disp in" style="left:18px;top:134px;font-size:150px;line-height:.8">${esc(dep)}</div>
    <div class="abs cap in" style="left:24px;top:272px">Leaving for<br>Queenstown, NZ</div>
    <svg class="abs art" style="left:236px;top:266px" width="140" height="110" viewBox="0 0 140 110"><g class="ln">
      <path class="dots" stroke-dasharray="1 7" d="M6 100 C 30 96, 40 70, 28 62 C 16 54, 10 76, 34 80 C 60 84, 80 60, 92 50"/>
      <path class="crf" d="M96 46 L136 12 L122 62 L110 52 Z"/><path d="M110 52 L136 12 L102 56"/>
    </g></svg>
    <div class="sheet"><div class="scroll">
      <div class="sec">Mission</div>
      <label class="set"><span class="lbl">Departure date</span><input type="date" data-dep value="${esc(s.departureDate ?? "")}"></label>
      <label class="set"><span class="lbl">Support target / month</span><input type="text" inputmode="decimal" data-target value="${esc(plainMoney(s.supportTargetMonthlyCents))}" placeholder="2.000,00"></label>
      <label class="set"><span class="lbl">NZD per EUR</span><input type="text" inputmode="decimal" data-rate value="${esc(String(s.nzdPerEur ?? "").replace(".", ","))}" placeholder="1,85"></label>
      <div class="sgap"></div><div class="sec">Giving on hesent.me <b>Empty IBAN: “details follow soon”</b></div>
      <label class="set"><span class="lbl">IBAN</span><input type="text" data-g-iban value="${esc(s.givingIban ?? "")}" placeholder="NL00 BANK 0123 4567 89" autocomplete="off" spellcheck="false" maxlength="42"></label>
      <label class="set"><span class="lbl">In the name of</span><input type="text" data-g-holder value="${esc(s.givingHolder ?? "")}" placeholder="Account holder" maxlength="80"></label>
      <label class="set"><span class="lbl">Reference</span><input type="text" data-g-ref value="${esc(s.givingReference ?? "")}" placeholder="e.g. Ruben Queenstown" maxlength="80"></label>
      <label class="set"><span class="lbl">Give online link</span><input type="url" data-g-url value="${esc(s.givingUrl ?? "")}" placeholder="https://…" maxlength="300"></label>
      <div class="sgap"></div><div class="sec">This browser</div>
      <label class="set"><span class="lbl">Server</span><input type="url" data-server value="${esc(config.apiUrl)}" placeholder="${esc(DEFAULT_API)}"></label>
      <button class="set" data-sync><span class="si">${I.sync}</span><span class="lbl">Sync</span><b data-st>${esc(syncText(st))}</b></button>
      <button class="set" data-backup><span class="si">${I.note}</span><span class="lbl">Export a backup</span><span class="chev">${I.chev}</span></button>
      <div class="sgap"></div><div class="sec">Account</div>
      <div class="set"><span class="lbl" data-who>Signed in</span></div>
      <button class="set" data-logout><span class="lbl">Sign out</span><b class="t">Sign out</b></button>
      <div class="sgap"></div>
      <button class="btn o wide" data-save>Save mission</button>
    </div></div>`;
}

function syncText(st) {
  return { idle: "Not synced yet", busy: "Syncing…", ok: st.detail ? `Synced at ${st.detail}` : "Synced", bad: "Sync problem", offline: "Offline" }[st.kind] ?? "";
}

export function init(el) {
  api.me().then((me) => {
    const who = el.querySelector("[data-who]");
    if (who) who.textContent = `${me.user.name} · ${me.user.email} · ${me.space.name}`;
  }).catch(() => {});

  el.querySelector("[data-save]").addEventListener("click", saveMission);
  el.querySelector("[data-server]").addEventListener("change", (e) => {
    const v = e.target.value.trim();
    config.apiUrl = v || DEFAULT_API;
    toast("Server saved. Syncing…");
    store.load().then(() => document.dispatchEvent(new Event("app:refresh"))).catch(() => {});
  });

  el.querySelector("[data-sync]").addEventListener("click", async () => {
    const st = el.querySelector("[data-st]");
    st.textContent = "Syncing…";
    anim(el.querySelector("[data-sync] .si"), [{ transform: "rotate(0)" }, { transform: "rotate(360deg)" }], { duration: 900, easing: "cubic-bezier(.5,0,.3,1)" });
    try {
      await store.load();
      st.textContent = "Synced just now";
      pop(st);
    } catch {
      st.textContent = "Sync problem";
    }
  });

  el.querySelector("[data-backup]").addEventListener("click", async () => {
    try {
      const blob = await api.exportAll();
      download(`missie-backup-${new Date().toISOString().slice(0, 10)}.json`, blob, "application/json");
    } catch (err) {
      toast(err.message, { bad: true });
    }
  });

  el.querySelector("[data-logout]").addEventListener("click", async () => {
    if (!window.confirm("Log out on this browser? Your data stays on the server.")) return;
    await api.logout().catch(() => {});
    session.token = null;
    store.reset();
    location.reload();
  });
}

async function saveMission(e) {
  const el = e.target.closest(".sheet");
  const rate = el.querySelector("[data-rate]").value.replace(",", ".");
  const text = (sel) => el.querySelector(sel).value.trim() || null;
  const iban = text("[data-g-iban]")?.toUpperCase().replace(/\s+/g, "").replace(/(.{4})(?!$)/g, "$1 ") ?? null;
  const url = text("[data-g-url]");
  if (url && !/^https:\/\/\S+$/.test(url)) return toast("The give online link must start with https://", { bad: true });
  await store.saveSettings({
    givingIban: iban,
    givingHolder: text("[data-g-holder]"),
    givingReference: text("[data-g-ref]"),
    givingUrl: url,
    departureDate: el.querySelector("[data-dep]").value || null,
    supportTargetMonthlyCents: parseCents(el.querySelector("[data-target]").value),
    nzdPerEur: Number(rate) || 1.85,
  });
  toast("Mission settings saved.");
  document.dispatchEvent(new Event("app:refresh"));
}
