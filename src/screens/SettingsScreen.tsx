import { Btn, Chip, Field, ScreenHeader, useConfirm } from "@/components/ui-bits";
import { cn } from "@/lib/utils";
import { useStore, STORAGE_KEY } from "@/lib/store";

export function SettingsScreen() {
  const { state, updateSettings, resetDemo, clearAll, back } = useStore();
  const { confirm, node } = useConfirm();

  const bytes = (() => {
    try { return new Blob([localStorage.getItem(STORAGE_KEY) ?? ""]).size; }
    catch { return 0; }
  })();
  const kb = (bytes / 1024).toFixed(1);

  return (
    <div className="screen-pad space-y-5">
      {node}
      <ScreenHeader title="Settings" onBack={back} />

      <Field label="Appearance">
        <div className="surface flex items-center justify-between p-3">
          <div>
            <div className="text-sm font-medium">Dark Mode</div>
            <div className="text-[11px] text-muted-foreground">Monochrome dark theme</div>
          </div>
          <button
            onClick={() => updateSettings({ darkMode: !state.settings.darkMode })}
            className={`tap relative w-14 rounded-full border border-border transition-colors ${state.settings.darkMode ? "bg-foreground" : "bg-secondary"}`}
            aria-pressed={state.settings.darkMode}
          >
            <span className={`absolute top-1 h-5 w-5 rounded-full bg-background transition-all ${state.settings.darkMode ? "left-8" : "left-1"}`} />
          </button>
        </div>
      </Field>

      <Field label="Font Size">
        <div className="flex flex-wrap gap-2">
          {(["compact", "comfort", "large"] as const).map((s) => (
            <Chip key={s} active={state.settings.fontSize === s} onClick={() => updateSettings({ fontSize: s })}>
              {s}
            </Chip>
          ))}
        </div>
      </Field>

      <Field label="Storage Usage">
        <div className="surface space-y-2 p-3">
          <div className="flex items-center justify-between text-xs">
            <span className="mono-label">Local storage</span>
            <span className="font-data" data-numeric="true">{kb} KB</span>
          </div>
          <div className="h-2 overflow-hidden rounded-full bg-secondary">
            <div className="h-full bg-foreground" style={{ width: `${Math.min(100, (bytes / (5 * 1024 * 1024)) * 100)}%` }} />
          </div>
          <div className="grid grid-cols-3 gap-2 pt-2 text-center">
            <div><div className="font-data text-sm font-semibold" data-numeric="true">{state.exercises.length}</div><div className="text-[10px] uppercase tracking-wider text-muted-foreground">Cards</div></div>
            <div><div className="font-data text-sm font-semibold" data-numeric="true">{state.workouts.length}</div><div className="text-[10px] uppercase tracking-wider text-muted-foreground">Workouts</div></div>
            <div><div className="font-data text-sm font-semibold" data-numeric="true">{state.logs.length}</div><div className="text-[10px] uppercase tracking-wider text-muted-foreground">Logs</div></div>
          </div>
        </div>
      </Field>

      <Field label="Backup Settings">
        <div className="surface p-3 text-xs text-muted-foreground">
          Backups are manual via the Export screen. Video files themselves are not included — only metadata, clip points and filenames.
        </div>
      </Field>

      {state.profile && (
        <Field label="Profile">
          <div className="surface grid grid-cols-2 gap-2 p-3 text-xs">
            <div><span className="mono-label block">Age</span><span className="font-data" data-numeric="true">{state.profile.age}</span></div>
            <div><span className="mono-label block">Experience</span>{state.profile.experience}</div>
            <div><span className="mono-label block">Height</span><span className="font-data" data-numeric="true">{state.profile.heightCm} cm</span></div>
            <div><span className="mono-label block">Weight</span><span className="font-data" data-numeric="true">{state.profile.weightKg} kg</span></div>
          </div>
        </Field>
      )}

      <div className="space-y-2 pt-2">
        <Btn variant="secondary" onClick={async () => {
          if (await confirm("Reset to demo data? Your current exercises, workouts and logs will be replaced.")) resetDemo();
        }}>Reset Demo Data</Btn>
        <Btn variant="secondary" onClick={async () => {
          if (await confirm("Clear ALL local data including profile? This cannot be undone.")) clearAll();
        }}>Clear All Local Data</Btn>
      </div>
    </div>
  );
}
