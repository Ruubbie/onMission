import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { FolderLock, HeartHandshake, Home as HomeIcon, ListChecks, Luggage, Mail, NotebookPen, RefreshCw, Settings as SettingsIcon, Tag, Users, Wallet, CloudOff, AlertTriangle } from "lucide-react";
import { accentVar, brand, onAccent, type Accent } from "./design/brand";
import { Spinner, Toast } from "./ui";
import { sync, useStore } from "./data/store";
import { NavContext, type Page } from "./pages/common";
import SearchDialog from "./pages/SearchDialog";
import Home from "./pages/Home";
import Checklists from "./pages/Checklists";
import Partners from "./pages/Partners";
import Budget from "./pages/Budget";
import Selling from "./pages/Selling";
import Packing from "./pages/Packing";
import Documents from "./pages/Documents";
import Notes from "./pages/Notes";
import Newsletter from "./pages/Newsletter";
import Contacts from "./pages/Contacts";
import Settings from "./pages/Settings";

const i = (C: typeof HomeIcon) => <C size={20} strokeWidth={2.5} />;
export const NAV: { page: Page; title: string; icon: ReactNode; accent: Accent; Comp: () => ReactNode; tab?: boolean }[] = [
  { page: "home", title: "Home", icon: i(HomeIcon), accent: "yellow", Comp: Home, tab: true },
  { page: "checklists", title: "Checklists", icon: i(ListChecks), accent: "lime", Comp: Checklists, tab: true },
  { page: "partners", title: "Partners", icon: i(HeartHandshake), accent: "pink", Comp: Partners, tab: true },
  { page: "budget", title: "Budget", icon: i(Wallet), accent: "green", Comp: Budget },
  { page: "selling", title: "Selling", icon: i(Tag), accent: "sand", Comp: Selling },
  { page: "packing", title: "Packing", icon: i(Luggage), accent: "lime", Comp: Packing },
  { page: "documents", title: "Documents", icon: i(FolderLock), accent: "purple", Comp: Documents, tab: true },
  { page: "notes", title: "Notes", icon: i(NotebookPen), accent: "sand", Comp: Notes },
  { page: "newsletter", title: "Newsletter", icon: i(Mail), accent: "pink", Comp: Newsletter, tab: true },
  { page: "contacts", title: "Contacts", icon: i(Users), accent: "grey", Comp: Contacts },
  { page: "settings", title: "Settings", icon: i(SettingsIcon), accent: "grey", Comp: Settings },
];

function NavItem({ n, current, go, k }: { n: (typeof NAV)[number]; current: boolean; go: (p: Page) => void; k?: number }) {
  return (
    <button className="navitem" aria-current={current ? "page" : undefined} onClick={() => go(n.page)}
      style={current ? { background: accentVar(n.accent), color: onAccent(n.accent) } : undefined}>
      {n.icon}<span>{n.title}</span>{k !== undefined && <span className="k" style={current ? { color: "inherit" } : undefined}>^{k}</span>}
    </button>
  );
}

function SyncPill() {
  const { auth, status } = useStore();
  const icon = status.state === "syncing" ? <Spinner /> : status.state === "error" ? <AlertTriangle size={14} strokeWidth={3} /> : auth.token ? <RefreshCw size={14} strokeWidth={3} /> : <CloudOff size={14} strokeWidth={3} />;
  const text = status.state === "syncing" ? "Syncing" : status.state === "error" ? "Sync failed" : auth.token
    ? (status.lastSync ? `Synced ${new Date(status.lastSync).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}` : "Sync now") : "Only on this device";
  return <button className="syncpill" title={status.message ?? "Sync now (F5)"} onClick={() => void sync()}>{icon}{text}</button>;
}

export default function App() {
  const [nav, setNav] = useState<{ page: Page; openId?: string; key: number }>(() => ({ page: (location.hash.slice(1) as Page) || "home", key: 0 }));
  const [toast, setToast] = useState<{ text: string; undo?: () => void; key: number } | null>(null);
  const [search, setSearch] = useState(false);

  const go = useCallback((page: Page, openId?: string) => { setNav((n) => ({ page, openId, key: n.key + 1 })); history.replaceState(null, "", `#${page}`); window.scrollTo(0, 0); }, []);
  const showToast = useCallback((text: string, undo?: () => void) => setToast({ text, undo, key: Date.now() }), []);
  const ctx = useMemo(() => ({ page: nav.page, openId: nav.openId, go, toast: showToast }), [nav, go, showToast]);

  useEffect(() => {
    const h = () => setNav((n) => ({ page: (location.hash.slice(1) as Page) || "home", key: n.key + 1 }));
    window.addEventListener("hashchange", h);
    return () => window.removeEventListener("hashchange", h);
  }, []);

  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if (e.ctrlKey && e.key === "k") { e.preventDefault(); setSearch(true); }
      else if (e.ctrlKey && /^[1-9]$/.test(e.key)) { e.preventDefault(); const n = NAV[+e.key - 1]; if (n) go(n.page); }
      else if (e.key === "F5") { e.preventDefault(); void sync(); }
    };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, [go]);

  const current = NAV.find((n) => n.page === nav.page) ?? NAV[0];
  const closeToast = useCallback(() => setToast(null), []);
  return (
    <NavContext.Provider value={ctx}>
      <nav className="rail box">
        <div className="brand"><img src={brand.logo} alt="" />{brand.appName}</div>
        {NAV.map((n, idx) => <NavItem key={n.page} n={n} current={n.page === nav.page} go={go} k={idx < 9 ? idx + 1 : undefined} />)}
        <SyncPill />
      </nav>
      <nav className="tabbar box">
        {NAV.filter((n) => n.tab).map((n) => <NavItem key={n.page} n={n} current={n.page === nav.page} go={go} />)}
      </nav>
      <main className="main" key={nav.key}><current.Comp /></main>
      {search && <SearchDialog onClose={() => setSearch(false)} />}
      {toast && <Toast key={toast.key} text={toast.text} action={toast.undo ? "Undo" : undefined} onAction={toast.undo} onDone={closeToast} />}
    </NavContext.Provider>
  );
}
