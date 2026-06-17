import { useStore } from "@/lib/store";
import { ScreenHeader } from "@/components/ui-bits";

interface Tile { label: string; sub: string; onClick: () => void; }

export function Home() {
  const { state, navigate } = useStore();
  const recentExercises = state.exercises.slice(0, 3);
  const recentWorkouts = state.workouts.slice(0, 3);

  const tiles: Tile[] = [
    { label: "Create Exercise", sub: "New card",  onClick: () => navigate({ name: "exercise-editor" }) },
    { label: "Create Workout",  sub: "New plan",  onClick: () => navigate({ name: "workout-editor" }) },
    { label: "Exercise Library", sub: `${state.exercises.length} cards`, onClick: () => navigate({ name: "cards" }) },
    { label: "Workout Library",  sub: `${state.workouts.length} plans`,  onClick: () => navigate({ name: "build" }) },
    { label: "Log Session",      sub: `${state.logs.length} entries`,    onClick: () => navigate({ name: "log" }) },
    { label: "Export Data",      sub: "Backup",   onClick: () => navigate({ name: "export" }) },
  ];

  return (
    <div className="screen-pad">
      <ScreenHeader
        title="Workout Clip Planner"
        subtitle="Personal card library"
        right={
          <button onClick={() => navigate({ name: "settings" })} className="tap w-10 rounded-lg text-base" aria-label="Settings">
            ⚙
          </button>
        }
      />

      <div className="grid grid-cols-2 gap-3">
        {tiles.map((t) => (
          <button
            key={t.label}
            onClick={t.onClick}
            className="surface flex aspect-square flex-col justify-between p-4 text-left transition-colors hover:bg-secondary"
          >
            <span className="mono-label">{t.sub}</span>
            <span className="text-sm font-semibold uppercase leading-tight tracking-wider">{t.label}</span>
          </button>
        ))}
      </div>

      <section className="mt-8">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="mono-label">Recent Exercises</h2>
          <button onClick={() => navigate({ name: "cards" })} className="text-[11px] uppercase tracking-wider text-muted-foreground">All →</button>
        </div>
        <div className="space-y-2 divide-hair surface overflow-hidden">
          {recentExercises.length === 0 && (
            <div className="p-4 text-xs text-muted-foreground">No exercises yet.</div>
          )}
          {recentExercises.map((e) => (
            <button
              key={e.id}
              onClick={() => navigate({ name: "exercise-details", id: e.id })}
              className="flex w-full items-center gap-3 p-3 text-left hover:bg-secondary"
            >
              <div className="flex h-10 w-10 items-center justify-center rounded-md bg-secondary text-xs">▷</div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-medium">{e.title}</div>
                <div className="truncate text-[11px] uppercase tracking-wider text-muted-foreground">
                  {e.category} · {e.equipment}
                </div>
              </div>
              <div className="font-data text-xs text-muted-foreground" data-numeric="true">
                {e.sets}×{e.reps}
              </div>
            </button>
          ))}
        </div>
      </section>

      <section className="mt-6">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="mono-label">Recent Workouts</h2>
          <button onClick={() => navigate({ name: "build" })} className="text-[11px] uppercase tracking-wider text-muted-foreground">All →</button>
        </div>
        <div className="space-y-2 divide-hair surface overflow-hidden">
          {recentWorkouts.length === 0 && (
            <div className="p-4 text-xs text-muted-foreground">No workouts yet.</div>
          )}
          {recentWorkouts.map((w) => (
            <button
              key={w.id}
              onClick={() => navigate({ name: "workout-builder", id: w.id })}
              className="flex w-full items-center gap-3 p-3 text-left hover:bg-secondary"
            >
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-medium">{w.name}</div>
                <div className="truncate text-[11px] uppercase tracking-wider text-muted-foreground">
                  {w.description || "—"}
                </div>
              </div>
              <div className="font-data text-xs text-muted-foreground" data-numeric="true">
                {w.exerciseIds.length}
              </div>
            </button>
          ))}
        </div>
      </section>
    </div>
  );
}
