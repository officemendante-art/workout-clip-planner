import { ReactNode, useState } from "react";
import { useStore } from "@/lib/store";
import { cn } from "@/lib/utils";

export function Chip({
  active, onClick, children, className,
}: {
  active?: boolean;
  onClick?: () => void;
  children: ReactNode;
  className?: string;
}) {
  return (
    <button
      type="button"
      data-active={active ? "true" : "false"}
      onClick={onClick}
      className={cn("chip", className)}
    >
      {children}
    </button>
  );
}

export function ChipGroup<T extends string>({
  options, value, onChange, multi = false,
}: {
  options: readonly T[] | T[];
  value: T | T[] | null | undefined;
  onChange: (v: any) => void;
  multi?: boolean;
}) {
  const arr = multi ? (value as T[]) ?? [] : value ? [value as T] : [];
  return (
    <div className="flex flex-wrap gap-2">
      {options.map((o) => {
        const active = arr.includes(o);
        return (
          <Chip
            key={o}
            active={active}
            onClick={() => {
              if (multi) {
                const set = new Set(arr);
                if (set.has(o)) set.delete(o); else set.add(o);
                onChange(Array.from(set));
              } else {
                onChange(o);
              }
            }}
          >
            {o}
          </Chip>
        );
      })}
    </div>
  );
}

export function Field({ label, children, hint }: { label: string; children: ReactNode; hint?: string }) {
  return (
    <div className="space-y-2">
      <div className="mono-label">{label}</div>
      {children}
      {hint && <div className="text-[11px] text-muted-foreground">{hint}</div>}
    </div>
  );
}

export function Stepper({
  value, onChange, min = 0, max = 999, step = 1, suffix,
}: {
  value: number; onChange: (n: number) => void;
  min?: number; max?: number; step?: number; suffix?: string;
}) {
  const clamp = (n: number) => Math.max(min, Math.min(max, n));
  return (
    <div className="flex items-stretch overflow-hidden rounded-xl border border-border">
      <button
        type="button"
        onClick={() => onChange(clamp(value - step))}
        className="tap w-12 bg-secondary text-lg active:bg-accent"
      >
        −
      </button>
      <div className="flex flex-1 items-center justify-center bg-card px-3">
        <span className="font-data text-base font-semibold" data-numeric="true">
          {value}{suffix ? ` ${suffix}` : ""}
        </span>
      </div>
      <button
        type="button"
        onClick={() => onChange(clamp(value + step))}
        className="tap w-12 bg-secondary text-lg active:bg-accent"
      >
        +
      </button>
    </div>
  );
}

export function TextInput(props: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      {...props}
      className={cn(
        "w-full rounded-xl border border-border bg-card px-3 py-3 text-sm outline-none focus:border-foreground",
        props.className,
      )}
    />
  );
}

export function TextArea(props: React.TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <textarea
      {...props}
      className={cn(
        "w-full resize-none rounded-xl border border-border bg-card px-3 py-3 text-sm outline-none focus:border-foreground",
        props.className,
      )}
    />
  );
}

export function Btn({
  variant = "primary", className, children, ...rest
}: React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "secondary" | "ghost" | "danger" }) {
  const styles: Record<string, string> = {
    primary: "bg-foreground text-background hover:opacity-90",
    secondary: "bg-secondary text-foreground hover:bg-accent",
    ghost: "bg-transparent text-foreground hover:bg-secondary",
    danger: "bg-foreground text-background hover:opacity-90 border border-foreground",
  };
  return (
    <button
      {...rest}
      className={cn(
        "tap w-full rounded-xl px-4 text-sm font-medium uppercase tracking-wider transition-colors disabled:opacity-50",
        styles[variant], className,
      )}
    >
      {children}
    </button>
  );
}

export function ScreenHeader({
  title, onBack, right, subtitle,
}: { title: string; onBack?: () => void; right?: ReactNode; subtitle?: string }) {
  return (
    <header className="sticky top-0 z-20 -mx-4 mb-4 border-b border-border bg-background/95 px-4 pb-3 pt-3 backdrop-blur">
      <div className="flex items-center gap-3">
        {onBack && (
          <button onClick={onBack} className="tap -ml-2 w-10 rounded-lg text-base" aria-label="Back">
            ←
          </button>
        )}
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-sm font-semibold uppercase tracking-[0.18em]">{title}</h1>
          {subtitle && <div className="mt-0.5 truncate text-[11px] text-muted-foreground">{subtitle}</div>}
        </div>
        {right}
      </div>
    </header>
  );
}

const NAV_ITEMS: Array<{ key: "home" | "cards" | "build" | "log" | "export"; label: string; icon: string }> = [
  { key: "home", label: "Home", icon: "◐" },
  { key: "cards", label: "Cards", icon: "▤" },
  { key: "build", label: "Build", icon: "▦" },
  { key: "log", label: "Log", icon: "◉" },
  { key: "export", label: "Export", icon: "↗" },
];

export function BottomNav() {
  const { screen, navigate } = useStore();
  const HIDDEN_ON: string[] = [
    "onboarding", "exercise-editor", "exercise-details", "video-flow",
    "workout-editor", "workout-builder", "logging", "history", "settings",
  ];
  if (HIDDEN_ON.includes(screen.name)) return null;
  return (
    <nav className="fixed bottom-0 left-1/2 z-30 w-full max-w-[440px] -translate-x-1/2 border-t border-border bg-background">
      <ul className="grid grid-cols-5">
        {NAV_ITEMS.map((it) => {
          const active = screen.name === it.key;
          return (
            <li key={it.key}>
              <button
                onClick={() => navigate({ name: it.key } as any)}
                className={cn(
                  "tap w-full flex-col gap-0.5 py-2 text-[10px] uppercase tracking-wider",
                  active ? "text-foreground" : "text-muted-foreground",
                )}
              >
                <span className="text-base leading-none">{it.icon}</span>
                <span>{it.label}</span>
              </button>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}

export function Modal({ onClose, children, title }: { onClose: () => void; title?: string; children: ReactNode }) {
  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-foreground/40 sm:items-center">
      <div className="w-full max-w-[440px] rounded-t-2xl border border-border bg-card p-4 sm:rounded-2xl">
        {title && (
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-sm font-semibold uppercase tracking-wider">{title}</h2>
            <button onClick={onClose} className="tap -mr-2 w-10 text-base">✕</button>
          </div>
        )}
        {children}
      </div>
    </div>
  );
}

export function useConfirm() {
  const [opts, setOpts] = useState<{ msg: string; resolve: (v: boolean) => void } | null>(null);
  const confirm = (msg: string) =>
    new Promise<boolean>((resolve) => setOpts({ msg, resolve }));
  const node = opts ? (
    <Modal title="Confirm" onClose={() => { opts.resolve(false); setOpts(null); }}>
      <p className="mb-4 text-sm text-foreground">{opts.msg}</p>
      <div className="grid grid-cols-2 gap-2">
        <Btn variant="secondary" onClick={() => { opts.resolve(false); setOpts(null); }}>Cancel</Btn>
        <Btn variant="primary" onClick={() => { opts.resolve(true); setOpts(null); }}>Confirm</Btn>
      </div>
    </Modal>
  ) : null;
  return { confirm, node };
}

export function VideoThumb({ url, name, size = "md" }: { url?: string; name?: string; size?: "sm" | "md" | "lg" }) {
  const aspect = size === "sm" ? "h-12 w-16" : size === "lg" ? "aspect-video w-full" : "h-20 w-28";
  return (
    <div className={cn(
      "relative flex items-center justify-center overflow-hidden rounded-lg border border-border bg-secondary",
      aspect,
    )}>
      {url ? (
        <video src={url} className="h-full w-full object-cover" muted playsInline />
      ) : (
        <div className="text-center text-muted-foreground">
          <div className="text-lg leading-none">▷</div>
          {size !== "sm" && <div className="mt-1 text-[9px] uppercase tracking-wider">{name ?? "No clip"}</div>}
        </div>
      )}
    </div>
  );
}
