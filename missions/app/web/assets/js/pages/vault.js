// Vault: the papers for the move. A paper with no file is dashed and says Scan; scanning uploads it
// to the same vault the iPhone reads. When nothing is missing an ALL IN stamp lands on the folder.
// Port of prototype.html PAGES.vault. Documents are the records; the file lives on the server.

import { store } from "../store.js";
import { I, anim, draw } from "../motion.js";
import { api } from "../api.js";
import { esc, toast, pop, fold, swapText } from "../ui.js";
import { newId, sha256Hex, formatBytes, guessDocKind, todayStr, fmtDay } from "../util.js";
import { patch } from "./common.js";

export const title = "Vault";
export const parent = "move";
export const kick = "Vault";

const MAX_BYTES = 50 * 1024 * 1024;
const KIND_ICON = { passport: "pass", id: "pass", visa: "note", insurance: "shield", ticket: "ticket", medical: "shield" };

const missing = () => store.list("documents").filter((d) => !d.fileId).length;

export function build() {
  const docs = sorted();
  const n = missing();
  return `
    <div class="abs hand hi in" data-hi>${n ? "Your papers" : "Nice work!"}</div>
    <div class="abs disp bign in" data-n>${n}</div>
    <div class="abs cap cp in" data-cp>${n ? "Papers still<br>missing" : "Nothing missing.<br>You're set."}</div>
    <img class="abs art pic in" src="assets/art/vault.webp" alt="" style="left:208px;top:118px;width:170px">
    <div class="sheet">
      <div class="sec">Needed to fly <b>${docs.length - n} of ${docs.length}</b></div>
      <div class="scroll" data-list>${docs.map(row).join("")}<button class="more" data-add>Add a paper ${I.plus}</button></div>
      <input type="file" hidden data-file>
    </div>`;
}

function sorted() {
  return store.list("documents").sort((a, b) => (a.title ?? "").localeCompare(b.title ?? ""));
}

function row(d) {
  const miss = !d.fileId;
  const sub = miss ? "Add a scan or photo" : [d.fileName, d.expiresAt ? `expires ${fmtDay(d.expiresAt)}` : null].filter(Boolean).join(" · ");
  return `<div class="rw" data-doc="${esc(d.id)}">
    <span class="dbox ${miss ? "miss" : "got"}">${I[KIND_ICON[d.kind] ?? "note"]}<i class="scan"></i></span>
    <div class="tx"><div class="t1">${esc(d.title)}</div><div class="t2">${esc(sub)}</div></div>
    ${miss ? `<button class="btn sm o" data-scan>${I.camera}Scan</button>` : `<button class="btn sm o" data-open>Open</button>`}
  </div>`;
}

export function init(el) {
  const list = el.querySelector("[data-list]");
  const file = el.querySelector("[data-file]");
  let target = null;

  list.addEventListener("click", async (e) => {
    if (e.target.closest("[data-add]")) return addPaper();
    const scan = e.target.closest("[data-scan]");
    const open = e.target.closest("[data-open]");
    const r = e.target.closest("[data-doc]");
    if (!r) return;
    const d = store.get("documents", r.dataset.doc);
    if (!d) return;
    if (open) return openFile(d);
    if (scan) {
      target = d;
      file.value = "";
      file.click();
    }
  });

  file.addEventListener("change", async () => {
    const f = file.files[0];
    if (!f || !target) return;
    await scanInto(target, f, el);
    target = null;
  });
}

async function scanInto(d, f, el) {
  if (f.size > MAX_BYTES) return toast(`${f.name} is larger than 50 MB.`, { bad: true });
  const row = el.querySelector(`[data-doc="${d.id}"]`);
  const btn = row?.querySelector("[data-scan]");
  const scan = row?.querySelector(".scan");
  if (btn) { btn.disabled = true; btn.textContent = "Scanning…"; }
  try {
    const fileId = d.fileId ?? newId();
    const sha = await sha256Hex(await f.arrayBuffer());
    if (scan) await anim(scan, [{ top: "3px", opacity: 1 }, { top: "38px", opacity: 1 }], { duration: 480, iterations: 2, direction: "alternate", easing: "ease-in-out" });
    await api.upload(`/v1/files/${fileId}`, f, f.name);
    await patch("documents", d.id, { fileId, fileName: f.name, mimeType: f.type || "application/octet-stream", sizeBytes: f.size, sha256: sha, scannedAt: new Date().toISOString() });
    const box = row?.querySelector(".dbox");
    if (box) { box.classList.remove("miss"); box.classList.add("got"); box.innerHTML = `<svg viewBox="0 0 24 24" class="ln" style="stroke-width:2.6"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>`; draw(box); pop(box); }
    const left = missing();
    const big = el.querySelector("[data-n]");
    if (big) big.textContent = left;
    if (!left) {
      swapText(el.querySelector("[data-hi]"), "Nice work!");
      swapText(el.querySelector("[data-cp]"), "Nothing missing.<br>You're set.");
      anim(el.querySelector(".vstamp"), [{ opacity: 0, transform: "scale(2.2) rotate(12deg)" }, { opacity: 1, transform: "scale(1)", offset: 0.7 }, { opacity: 1, transform: "scale(1.06)", offset: 0.85 }, { opacity: 1, transform: "scale(1)" }], { duration: 520, delay: 300, easing: "cubic-bezier(.6,0,.9,.6)", fill: "forwards" });
    }
    toast(`Stored ${f.name}`);
    document.dispatchEvent(new Event("app:refresh"));
  } catch (err) {
    toast(`Could not store ${f.name}: ${err.message}`, { bad: true });
    if (btn) { btn.disabled = false; btn.textContent = "Scan"; }
  }
}

async function addPaper() {
  const d = await store.create("documents", { title: "New paper", kind: "other", fileId: null, notes: null, links: [], createdAt: new Date().toISOString() });
  document.dispatchEvent(new Event("app:refresh"));
  toast("Added a paper. Tap Scan to store it.");
}

async function openFile(d) {
  try {
    const blob = await api.blob(`/v1/files/${d.fileId}`);
    window.open(URL.createObjectURL(blob), "_blank", "noopener");
  } catch (err) {
    toast(`Could not open the file: ${err.message}`, { bad: true });
  }
}

