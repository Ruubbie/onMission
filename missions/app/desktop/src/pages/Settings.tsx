import { useRef, useState } from "react";
import { Button, DateField, FormRow, FormSection, Segmented, TextField } from "../ui";
import { DEFAULT_API, exportBackup, importBackup, login, logout, patch, put, setApiUrl, settings, sync, useStore } from "../data/store";
import { MAIN_SETTINGS_ID, type Setting } from "../data/types";
import { download, money, parseMoney, today } from "../data/format";
import { brand } from "../design/brand";
import { PageHead, useNav } from "./common";

export default function Settings() {
  const { auth, status } = useStore();
  const { toast } = useNav();
  const s = settings();
  const save = (p: Partial<Setting>) => (s.updatedAt ? patch(s, p) : put("settings", { ...s.data, ...p }, MAIN_SETTINGS_ID));

  const [url, setUrl] = useState(auth.url);
  const [mode, setMode] = useState<"Log in" | "Create account">("Log in");
  const [email, setEmail] = useState(auth.email ?? "");
  const [password, setPassword] = useState("");
  const [secret, setSecret] = useState("");
  const [name, setName] = useState("Ruben");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const file = useRef<HTMLInputElement>(null);

  const doLogin = async () => {
    setBusy(true); setErr("");
    try { await login(url.trim(), email.trim(), password, mode === "Create account" ? { secret, name } : undefined); setPassword(""); toast("Logged in and synced"); }
    catch (e) { setErr(e instanceof Error ? e.message : String(e)); }
    setBusy(false);
  };

  return (
    <>
      <PageHead title="Settings" />
      <div className="stack" style={{ gap: 24, maxWidth: 640 }}>
        <FormSection title="Your mission" footer="Shared with the iPhone app.">
          <FormRow label="Departure"><DateField value={s.data.departureDate} onChange={(departureDate) => save({ departureDate })} /></FormRow>
          <FormRow label="Monthly target (€)"><MoneyField cents={s.data.supportTargetMonthlyCents} onChange={(v) => save({ supportTargetMonthlyCents: v })} /></FormRow>
          <FormRow label="Monthly minimum (€)"><MoneyField cents={s.data.supportMinimumMonthlyCents} onChange={(v) => save({ supportMinimumMonthlyCents: v })} /></FormRow>
          <FormRow label="NZD per €"><TextField bare value={String(s.data.nzdPerEur ?? "")} onChange={(v) => save({ nzdPerEur: parseFloat(v.replace(",", ".")) || undefined })} /></FormRow>
        </FormSection>

        <FormSection title="Sync" footer={auth.token ? undefined : "Use the same email and password as on the iPhone. Create account only works once, with the server's setup secret."}>
          <FormRow label="Server"><TextField bare value={url} onChange={(v) => { setUrl(v); setApiUrl(v.trim() || DEFAULT_API); }} /></FormRow>
          {auth.token ? (
            <>
              <FormRow label="Logged in as"><span className="bold">{auth.email}</span></FormRow>
              <FormRow label="Status"><span>{status.state === "error" ? status.message : status.lastSync ? `Last synced ${new Date(status.lastSync).toLocaleString()}` : "Not synced yet"}</span></FormRow>
              <div className="frow row" style={{ justifyContent: "flex-end" }}>
                <Button compact variant="secondary" onClick={() => void logout()}>Log out</Button>
                <Button compact busy={status.state === "syncing"} onClick={() => void sync()}>Sync now</Button>
              </div>
            </>
          ) : (
            <>
              <div className="frow"><Segmented value={mode} options={["Log in", "Create account"] as const} onChange={setMode} /></div>
              {mode === "Create account" && <FormRow label="Setup secret"><TextField bare type="password" value={secret} onChange={setSecret} /></FormRow>}
              {mode === "Create account" && <FormRow label="Name"><TextField bare value={name} onChange={setName} /></FormRow>}
              <FormRow label="Email"><TextField bare value={email} onChange={setEmail} /></FormRow>
              <FormRow label="Password"><TextField bare type="password" value={password} onChange={setPassword} onKeyDown={(e) => e.key === "Enter" && void doLogin()} /></FormRow>
              {err && <div className="frow" style={{ color: "var(--danger)", fontWeight: 700 }}>{err}</div>}
              <div className="frow row" style={{ justifyContent: "flex-end" }}><Button compact busy={busy} onClick={() => void doLogin()}>{mode}</Button></div>
            </>
          )}
        </FormSection>

        <FormSection title="Backup" footer="One JSON file with everything (not the document files themselves).">
          <div className="frow row" style={{ justifyContent: "flex-end" }}>
            <Button compact variant="secondary" onClick={() => file.current?.click()}>Import backup</Button>
            <Button compact onClick={() => download(`${brand.appName.toLowerCase()}-backup-${today()}.json`, exportBackup(), "application/json")}>Export backup</Button>
            <input ref={file} type="file" accept=".json" hidden onChange={async (e) => { const f = e.target.files?.[0]; if (f) toast(`Imported ${importBackup(await f.text())} records`); }} />
          </div>
        </FormSection>
        <p className="caption muted">{brand.appName} desktop 0.1.0 · Ctrl+K search · Ctrl+N add · Ctrl+1…9 pages · F5 sync</p>
      </div>
    </>
  );
}

function MoneyField({ cents, onChange }: { cents?: number; onChange: (v?: number) => void }) {
  const [t, setT] = useState(cents !== undefined ? String(cents / 100) : "");
  return <input className="bare num" value={t} placeholder={money(0)} onChange={(e) => { setT(e.target.value); onChange(parseMoney(e.target.value)); }} />;
}
