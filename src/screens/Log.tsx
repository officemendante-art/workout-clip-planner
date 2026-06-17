import { useEffect, useMemo, useRef, useState } from "react";
import { Btn, Chip, Field, ScreenHeader, Stepper, TextArea, VideoThumb } from "@/components/ui-bits";
import { useStore, uid } from "@/lib/store";
import type { ExerciseLogSet } from "@/lib/types";

export function LogHub() {
  const { state, navigate } = useStore();
  return (
    <div className="screen-pad">
      <ScreenHeader title="Log" subtitle="Pick an exercise to log a session" />

      <div className="grid grid-cols-2 gap-2">
        <Btn variant="secondary" onClick={() => navigate({ name: "history" })}>View History</Btn>
        <Btn variant="secondary" onClick={() => navigate({ name: "cards" })}>Browse Cards</Btn>
      </div>

      <div className="mt-4 space-y-2">
        <div className="mono-label">Quick Start</div>
        {state.exercises.slice(0, 8).map((e) => (
          <button
            key={e.id}
            onClick={() => navigate({ name: "logging", exerciseId: e.id })}
            className="surface flex w-full items-center gap-3 p-3 text-left hover:bg-secondary"
          >
            <VideoThumb url={e.videoPreviewUrl} name={e.videoName} size="sm" />
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-medium">{e.title}</div>
              <div className="font-data text-[11px] text-muted-foreground" data-numeric="true">
                Last target: {e.sets} × {e.reps} · {e.weight}kg
              </div>
            </div>
            <div className="text-base">▶</div>
          </button>
        ))}
      </div>

      <div className="mt-6 space-y-2">
        <div className="mono-label">Recent Logs</div>
        {state.logs.slice(0, 5).map((l) => {
          const e = state.exercises.find((x) => x.id === l.exerciseId);
          return (
            <button
              key={l.id}
              onClick={() => navigate({ name: "history", exerciseId: l.exerciseId })}
              className="surface flex w-full items-center justify-between p-3 text-left hover:bg-secondary"
            >
              <div className="min-w-0">
                <div className="truncate text-sm font-medium">{e?.title ?? "Deleted exercise"}</div>
                <div className="font-data text-[11px] text-muted-foreground" data-numeric="true">
                  {new Date(l.date).toLocaleString()}
                </div>
              </div>
              <div className="font-data text-xs text-muted-foreground" data-numeric="true">
                {l.sets.length} sets
              </div>
            </button>
          );
        })}
        {state.logs.length === 0 && (
          <div className="surface p-6 text-center text-xs text-muted-foreground">No logs yet.</div>
        )}
      </div>
    </div>
  );
}

export function Logging({ exerciseId, workoutId }: { exerciseId: string; workoutId?: string }) {
  const { state, back, addLog, navigate } = useStore();
  const ex = state.exercises.find((x) => x.id === exerciseId);
  const workout = workoutId ? state.workouts.find((w) => w.id === workoutId) : null;
  const workoutOrder = workout?.exerciseIds ?? [];
  const indexInWorkout = workout ? workoutOrder.indexOf(exerciseId) : -1;
  const nextExerciseId = workout && indexInWorkout >= 0 ? workoutOrder[indexInWorkout + 1] : undefined;

  const initial = useMemo<ExerciseLogSet[]>(() => {
    if (!ex) return [];
    return Array.from({ length: ex.sets }, (_, i) => ({
      setNumber: i + 1, weight: ex.weight, reps: ex.reps, completed: false,
    }));
  }, [ex?.id]); // eslint-disable-line

  const [sets, setSets] = useState<ExerciseLogSet[]>(initial);
  const [notes, setNotes] = useState("");
  const [rest, setRest] = useState<number | null>(null);
  const restRef = useRef<number | null>(null);

  useEffect(() => { setSets(initial); }, [initial]);

  useEffect(() => {
    if (rest == null) return;
    if (rest <= 0) { setRest(null); return; }
    const t = window.setTimeout(() => setRest((r) => (r != null ? r - 1 : null)), 1000);
    restRef.current = t;
    return () => clearTimeout(t);
  }, [rest]);

  if (!ex) return (
    <div className="screen-pad">
      <ScreenHeader title="Logging" onBack={back} />
      <div className="text-sm text-muted-foreground">Exercise not found.</div>
    </div>
  );

  const update = (i: number, patch: Partial<ExerciseLogSet>) =>
    setSets((arr) => arr.map((s, k) => (k === i ? { ...s, ...patch } : s)));

  const completeSet = (i: number) => {
    update(i, { completed: true });
    setRest(ex.restTimer);
  };
  const addSet = () =>
    setSets((arr) => [
      ...arr,
      { setNumber: arr.length + 1, weight: arr[arr.length - 1]?.weight ?? ex.weight, reps: arr[arr.length - 1]?.reps ?? ex.reps, completed: false },
    ]);

  const done = () => {
    addLog({
      id: uid(), exerciseId: ex.id, workoutId,
      date: new Date().toISOString(),
      sets: sets.filter((s) => s.completed || s.reps > 0),
      notes: notes || undefined,
    });
    if (nextExerciseId) {
      navigate({ name: "logging", exerciseId: nextExerciseId, workoutId });
    } else {
      back();
    }
  };

  return (
    <div className="screen-pad space-y-5">
      <ScreenHeader
        title={ex.title}
        subtitle={workout ? `${workout.name} · ${indexInWorkout + 1}/${workoutOrder.length}` : "Logging session"}
        onBack={back}
      />

      <VideoThumb url={ex.videoPreviewUrl} name={ex.videoName} size="lg" />

      {rest != null && (
        <div className="surface flex items-center justify-between border-foreground p-3">
          <div className="mono-label">Rest</div>
          <div className="font-data text-xl font-semibold" data-numeric="true">{rest}s</div>
          <button onClick={() => setRest(null)} className="tap rounded-lg bg-secondary px-3 text-[11px] uppercase tracking-wider">Skip</button>
        </div>
      )}

      <div className="space-y-2">
        {sets.map((s, i) => (
          <div key={i} className="surface p-3" data-active={!s.completed}>
            <div className="mb-3 flex items-center justify-between">
              <div className="mono-label">Set <span className="font-data text-foreground" data-numeric="true">{s.setNumber}</span></div>
              {s.completed && <Chip active>Done</Chip>}
            </div>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Weight (kg)">
                <Stepper value={s.weight} onChange={(n) => update(i, { weight: n })} min={0} max={500} />
              </Field>
              <Field label="Reps">
                <Stepper value={s.reps} onChange={(n) => update(i, { reps: n })} min={0} max={100} />
              </Field>
            </div>
            <div className="mt-3">
              <Btn
                variant={s.completed ? "secondary" : "primary"}
                onClick={() => completeSet(i)}
              >
                {s.completed ? "Logged" : "Complete Set"}
              </Btn>
            </div>
          </div>
        ))}
      </div>

      <Btn variant="secondary" onClick={addSet}>+ Add Set</Btn>

      <Field label="Notes (optional)">
        <TextArea rows={2} value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Felt strong / form notes…" />
      </Field>

      <Btn onClick={done}>{nextExerciseId ? "Done — Next Exercise →" : "Done — Save Session"}</Btn>
    </div>
  );
}

export function History({ exerciseId }: { exerciseId?: string }) {
  const { state, back, navigate } = useStore();
  const [filter, setFilter] = useState<string | null>(exerciseId ?? null);

  const logs = state.logs.filter((l) => !filter || l.exerciseId === filter);
  const pbByEx = useMemo(() => {
    const map = new Map<string, number>();
    state.logs.forEach((l) => {
      l.sets.forEach((s) => {
        const cur = map.get(l.exerciseId) ?? 0;
        if (s.weight > cur) map.set(l.exerciseId, s.weight);
      });
    });
    return map;
  }, [state.logs]);

  return (
    <div className="screen-pad space-y-4">
      <ScreenHeader title="History" subtitle={`${logs.length} sessions`} onBack={back} />

      <div className="flex gap-2 overflow-x-auto pb-1 [&::-webkit-scrollbar]:hidden">
        <Chip active={!filter} onClick={() => setFilter(null)}>All</Chip>
        {state.exercises.map((e) => (
          <Chip key={e.id} active={filter === e.id} onClick={() => setFilter(e.id)}>{e.title}</Chip>
        ))}
      </div>

      <div className="space-y-2">
        {logs.length === 0 && (
          <div className="surface p-6 text-center text-xs text-muted-foreground">No sessions yet.</div>
        )}
        {logs.map((l) => {
          const ex = state.exercises.find((x) => x.id === l.exerciseId);
          const topWeight = l.sets.reduce((m, s) => Math.max(m, s.weight), 0);
          const isPB = ex && pbByEx.get(ex.id) === topWeight && topWeight > 0;
          return (
            <div key={l.id} className="surface p-3">
              <div className="mb-2 flex items-center justify-between">
                <button
                  onClick={() => ex && navigate({ name: "exercise-details", id: ex.id })}
                  className="truncate text-sm font-medium"
                >
                  {ex?.title ?? "Deleted exercise"}
                </button>
                <div className="font-data text-[11px] text-muted-foreground" data-numeric="true">
                  {new Date(l.date).toLocaleString()}
                </div>
              </div>
              <div className="grid grid-cols-4 gap-2 text-center">
                {l.sets.map((s, i) => (
                  <div key={i} className="rounded-md border border-border p-2">
                    <div className="mono-label">Set <span className="font-data text-foreground" data-numeric="true">{s.setNumber}</span></div>
                    <div className="mt-1 font-data text-sm" data-numeric="true">{s.weight}kg × {s.reps}</div>
                  </div>
                ))}
              </div>
              {isPB && (
                <div className="mt-2 inline-flex items-center gap-2 rounded-full border border-foreground px-2 py-1 text-[10px] uppercase tracking-wider">
                  ★ Personal Best · <span className="font-data" data-numeric="true">{topWeight}kg</span>
                </div>
              )}
              {l.notes && <p className="mt-2 text-xs text-muted-foreground">{l.notes}</p>}
            </div>
          );
        })}
      </div>
    </div>
  );
}
