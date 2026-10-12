// Small differences between the browser preview and the Windows app (Tauri).
import { openUrl } from "@tauri-apps/plugin-opener";

export const isTauri = "__TAURI_INTERNALS__" in window;

/** External links open in the normal browser, not inside the app window. */
export function installLinkHandler() {
  if (!isTauri) return;
  document.addEventListener("click", (e) => {
    const a = (e.target as HTMLElement).closest("a");
    if (a && /^(https?|mailto|tel):/.test(a.href) && !a.download) { e.preventDefault(); void openUrl(a.href); }
  });
}

/** Shows a stored file: a new tab in the browser, a download (to Downloads) in the Windows app. */
export function showBlobUrl(url: string, fileName = "file") {
  if (!isTauri) { window.open(url, "_blank"); return; }
  const a = document.createElement("a");
  a.href = url; a.download = fileName; a.click();
}
