// The design-system parts as React components (design-system.md §3–6). No app logic in here,
// so the newsletter website can import this folder as is.
import { useEffect, useState, type ReactNode, type CSSProperties, type ButtonHTMLAttributes } from "react";
import { Calendar, ChevronDown, Minus, Plus, Search, X, Check } from "lucide-react";
import { accentVar, onAccent, type Accent } from "../design/brand";
import "./ui.css";

const cx = (...c: (string | false | undefined | null)[]) => c.filter(Boolean).join(" ");

type BtnProps = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "secondary" | "danger"; compact?: boolean; block?: boolean; busy?: boolean };
export function Button({ variant = "primary", compact, block, busy, className, children, ...rest }: BtnProps) {
  return (
    <button {...rest} className={cx("btn press", compact && "compact small", variant !== "primary" && variant, block && "block", className)}>
      {busy ? <Spinner /> : children}
    </button>
  );
}

export function IconButton({ icon, accent, size = 40, className, style, ...rest }: ButtonHTMLAttributes<HTMLButtonElement> & { icon: ReactNode; accent?: Accent; size?: number }) {
  return (
    <button {...rest} className={cx("iconbtn press small", className)}
      style={{ width: size, height: size, background: accent ? accentVar(accent) : undefined, color: accent ? onAccent(accent) : undefined, ...style }}>
      {icon}
    </button>
  );
}

/** Floating yellow + (bottom right). Ctrl+N presses it too. */
export function AddButton({ onClick, title = "Add" }: { onClick: () => void; title?: string }) {
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.ctrlKey && e.key === "n") { e.preventDefault(); onClick(); } };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, [onClick]);
  return <button className="addbtn press" onClick={onClick} title={`${title} (Ctrl+N)`} aria-label={title}><Plus size={30} strokeWidth={3.5} /></button>;
}

export function AccentSquare({ accent, icon, size = 38 }: { accent: Accent; icon?: ReactNode; size?: number }) {
  return <span className="sq" style={{ width: size, height: size, background: accentVar(accent), color: onAccent(accent) }}>{icon}</span>;
}

export function Chip({ selected, accent = "yellow", onClick, children, title }: { selected?: boolean; accent?: Accent; onClick?: () => void; children: ReactNode; title?: string }) {
  const style: CSSProperties = selected ? { background: accentVar(accent), color: onAccent(accent) } : {};
  return onClick
    ? <button type="button" className="chip" style={style} onClick={onClick} aria-pressed={selected} title={title}>{children}</button>
    : <span className="chip static" style={style} title={title}>{children}</span>;
}

/** Row of chips for short choice lists (≤ ~8). `all` adds an "All" chip that maps to null. */
export function ChipFilter<T extends string>({ value, options, onChange, accent, all, label = (o: T) => o }:
  { value: T | null; options: readonly T[]; onChange: (v: T | null) => void; accent?: Accent; all?: string; label?: (o: T) => string }) {
  return (
    <div className="row wrap">
      {all && <Chip selected={value === null} accent={accent} onClick={() => onChange(null)}>{all}</Chip>}
      {options.map((o) => <Chip key={o} selected={value === o} accent={accent} onClick={() => onChange(all && value === o ? null : o)}>{label(o)}</Chip>)}
    </div>
  );
}

export const Badge = ({ children }: { children: ReactNode }) => <span className="badge">{children}</span>;

export function Progress({ value, accent = "yellow", thin }: { value: number; accent?: Accent; thin?: boolean }) {
  const pct = Math.max(0, Math.min(1, value || 0)) * 100;
  return <div className={cx("progress", thin && "thin")}><div style={{ width: `${pct}%`, background: accentVar(accent), borderRightWidth: pct ? undefined : 0 }} /></div>;
}

export const Spinner = () => <span className="spinner" role="status" aria-label="Working" />;

export function SectionHeader({ title, count, accent }: { title: string; count?: ReactNode; accent?: Accent }) {
  return (
    <div className="sechead">
      {accent && <span className="sq" style={{ background: accentVar(accent) }} />}
      <h3 className="grow">{title}</h3>
      {count !== undefined && <span className="muted">{count}</span>}
    </div>
  );
}

export function EmptyState({ accent, icon, title, message }: { accent: Accent; icon: ReactNode; title: string; message?: string }) {
  return (
    <div className="empty">
      <AccentSquare accent={accent} icon={icon} size={64} />
      <h3 style={{ fontSize: 20 }}>{title}</h3>
      {message && <p className="muted" style={{ margin: 0 }}>{message}</p>}
    </div>
  );
}

// ---- Inputs ----

export function TextField({ value, onChange, bare, multiline, ...rest }:
  { value: string; onChange: (v: string) => void; bare?: boolean; multiline?: boolean; placeholder?: string; type?: string; autoFocus?: boolean; onKeyDown?: (e: React.KeyboardEvent) => void; style?: CSSProperties; rows?: number }) {
  const cls = bare && !multiline ? "bare" : "field";
  return multiline
    ? <textarea {...rest} className={cls} value={value} onChange={(e) => onChange(e.target.value)} />
    : <input {...rest} className={cls} value={value} onChange={(e) => onChange(e.target.value)} />;
}

export function SearchField({ value, onChange, placeholder = "Search", autoFocus }: { value: string; onChange: (v: string) => void; placeholder?: string; autoFocus?: boolean }) {
  return (
    <div className="fieldwrap grow">
      <Search size={18} strokeWidth={3} />
      <input className="field" value={value} placeholder={placeholder} autoFocus={autoFocus} onChange={(e) => onChange(e.target.value)} />
      {value && <button className="clear" onClick={() => onChange("")} aria-label="Clear"><X size={14} strokeWidth={3} /></button>}
    </div>
  );
}

export function QuickAdd({ placeholder, onAdd }: { placeholder: string; onAdd: (text: string) => void }) {
  const [v, setV] = useState("");
  return (
    <div className="quickadd grow">
      <span className="plus"><Plus size={16} strokeWidth={3.5} /></span>
      <input className="field" value={v} placeholder={placeholder} onChange={(e) => setV(e.target.value)}
        onKeyDown={(e) => { if (e.key === "Enter" && v.trim()) { onAdd(v.trim()); setV(""); } }} />
    </div>
  );
}

export function Select<T extends string>({ value, options, onChange, label = (o) => o, empty }:
  { value: T | "" | undefined; options: readonly T[]; onChange: (v: T | "") => void; label?: (o: T) => string; empty?: string }) {
  return (
    <span className="selectwrap">
      <select className="field select" value={value ?? ""} onChange={(e) => onChange(e.target.value as T | "")}>
        {empty !== undefined && <option value="">{empty}</option>}
        {options.map((o) => <option key={o} value={o}>{label(o)}</option>)}
      </select>
      <ChevronDown size={18} strokeWidth={3} />
    </span>
  );
}

/** Date field: shows "Fri 9 Oct", opens the system calendar, × clears. Value is YYYY-MM-DD or undefined. */
export function DateField({ value, onChange }: { value?: string; onChange: (v: string | undefined) => void }) {
  return (
    <span className="fieldwrap">
      <Calendar size={18} strokeWidth={3} />
      <input type="date" className="field" value={value ?? ""} onChange={(e) => onChange(e.target.value || undefined)} style={{ paddingRight: value ? 40 : 12 }} />
      {value && <button className="clear" onClick={() => onChange(undefined)} aria-label="Clear date"><X size={14} strokeWidth={3} /></button>}
    </span>
  );
}

export function Toggle({ checked, onChange, label }: { checked: boolean; onChange: (v: boolean) => void; label?: string }) {
  return <button type="button" role="switch" aria-checked={checked} aria-label={label} className="toggle" onClick={() => onChange(!checked)}><span /></button>;
}

export function CheckBox({ checked, onChange, label }: { checked: boolean; onChange: (v: boolean) => void; label?: string }) {
  return (
    <button type="button" role="checkbox" aria-checked={checked} aria-label={label} className="check" onClick={(e) => { e.stopPropagation(); onChange(!checked); }}>
      {checked && <Check size={16} strokeWidth={4} />}
    </button>
  );
}

export function Segmented<T extends string>({ value, options, onChange, accent = "yellow", label = (o) => o }:
  { value: T; options: readonly T[]; onChange: (v: T) => void; accent?: Accent; label?: (o: T) => string }) {
  return (
    <div className="seg">
      {options.map((o) => (
        <button key={o} aria-pressed={o === value} onClick={() => onChange(o)} style={o === value ? { background: accentVar(accent), color: onAccent(accent) } : undefined}>{label(o)}</button>
      ))}
    </div>
  );
}

export function Stepper({ value, onChange, min = 0 }: { value: number; onChange: (v: number) => void; min?: number }) {
  return (
    <span className="stepper">
      <IconButton icon={<Minus size={16} strokeWidth={3} />} disabled={value <= min} onClick={() => onChange(value - 1)} aria-label="Less" />
      <b>{value}</b>
      <IconButton icon={<Plus size={16} strokeWidth={3} />} onClick={() => onChange(value + 1)} aria-label="More" />
    </span>
  );
}

// ---- Forms ----

export function FormSection({ title, footer, children }: { title?: string; footer?: string; children: ReactNode }) {
  return (
    <section className="formsec">
      {title && <h4>{title}</h4>}
      <div className="box">{children}</div>
      {footer && <div className="foot">{footer}</div>}
    </section>
  );
}

export function FormRow({ label, tall, children }: { label: string; tall?: boolean; children: ReactNode }) {
  return <div className={cx("frow", tall && "tall")}><label>{label}</label><div className="ctl">{children}</div></div>;
}

// ---- Folder card (§4) ----

const TAB_PATH = "M0,1 L0,0.25 Q0,0 0.06,0 L0.84,0 Q0.88,0 0.9,0.12 L1,1 Z";
function Tab({ title, fill, shadow, color }: { title: string; fill: string; shadow?: boolean; color?: string }) {
  return (
    <span className={cx("tabwrap", shadow && "shadow")} aria-hidden={shadow}>
      <svg viewBox="0 0 1 1" preserveAspectRatio="none"><path d={TAB_PATH} fill={fill} /></svg>
      <span style={{ color }}>{title}</span>
    </span>
  );
}

export function FolderCard({ title, accent, icon, count, subtitle, badge, progress, selected, onClick }:
  { title: string; accent: Accent; icon: ReactNode; count?: ReactNode; subtitle?: ReactNode; badge?: string; progress?: number; selected?: boolean; onClick?: () => void }) {
  return (
    <button className={cx("folder", selected && "selected")} onClick={onClick}>
      <Tab title={title} fill="var(--ink)" shadow />
      <Tab title={title} fill={accentVar(accent)} color={onAccent(accent)} />
      <div className="body stack" style={{ gap: 10 }}>
        <div className="row" style={{ alignItems: "flex-start" }}>
          <AccentSquare accent={accent} icon={icon} />
          <span className="grow" />
          {count !== undefined && <span className="count num">{count}</span>}
        </div>
        <div className="row caption muted">{subtitle}{badge && <Badge>{badge}</Badge>}</div>
        {progress !== undefined && <Progress value={progress} accent={accent} thin />}
      </div>
    </button>
  );
}

// ---- Overlays ----

export function Dialog({ title, message, confirm, danger, onConfirm, onCancel }:
  { title: string; message?: string; confirm: string; danger?: boolean; onConfirm: () => void; onCancel: () => void }) {
  useEscape(onCancel);
  return (
    <div className="scrim" onClick={onCancel}>
      <div className="box dialog" role="alertdialog" onClick={(e) => e.stopPropagation()}>
        <h3>{title}</h3>
        {message && <p style={{ fontSize: 15, marginTop: 0 }}>{message}</p>}
        <div className="stack" style={{ marginTop: 20 }}>
          <Button variant={danger ? "danger" : "primary"} block onClick={onConfirm} autoFocus>{confirm}</Button>
          <Button variant="secondary" block onClick={onCancel}>Cancel</Button>
        </div>
      </div>
    </div>
  );
}

/** Side sheet on desktop (cream, ink edge). Cancel left, title centre, Save right. */
export function Sheet({ title, onCancel, onSave, saveLabel = "Save", children }:
  { title: string; onCancel: () => void; onSave?: () => void; saveLabel?: string; children: ReactNode }) {
  useEscape(onCancel);
  return (
    <div className="scrim" onClick={onCancel}>
      <div className="sheet" role="dialog" aria-label={title} onClick={(e) => e.stopPropagation()}
        onKeyDown={(e) => { if (onSave && e.key === "s" && (e.ctrlKey || e.metaKey)) { e.preventDefault(); onSave(); } }}>
        <header>
          <Button variant="secondary" compact onClick={onCancel}>{onSave ? "Cancel" : "Close"}</Button>
          <h3>{title}</h3>
          {onSave ? <Button compact onClick={onSave}>{saveLabel}</Button> : <span style={{ width: 60 }} />}
        </header>
        <div className="content">{children}</div>
      </div>
    </div>
  );
}

export function Toast({ text, action, onAction, onDone }: { text: string; action?: string; onAction?: () => void; onDone: () => void }) {
  useEffect(() => { const t = setTimeout(onDone, 3000); return () => clearTimeout(t); }, [text, onDone]);
  return (
    <div className="box small toast" role="status">
      {text}
      {action && <Button compact variant="secondary" onClick={() => { onAction?.(); onDone(); }}>{action}</Button>}
    </div>
  );
}

export function useEscape(fn: () => void) {
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === "Escape") fn(); };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, [fn]);
}
