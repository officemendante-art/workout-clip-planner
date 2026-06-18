import { useEffect, useMemo, useState } from "react";
import {
  Btn, Chip, Field, Modal, ScreenHeader, TextArea, TextInput, useConfirm,
} from "@/components/ui-bits";
import { useStore, uid } from "@/lib/store";
import type { Workout } from "@/lib/types";

export function WorkoutLibrary() {
  const { state, navigate } = useStore();
  return (
    <div className="screen-pad">
      <ScreenHeader
        title="Workout Library"
        subtitle={`${state.workouts.length} user workouts`}
        right={
          <button onClick={() => navigate({ name: "workout-editor" })} className="tap w-10 rounded-lg bg-foreground text-base text-background">+</button>
        }
      />

      <div className="space-y-2">
        {state.workouts.length === 0 && (
          <div className="surface p-6 text-center text-xs text-muted-foreground">
            No workouts yet. Tap + to create one.
          </div>
        )}
        {state.workouts.map((w) => (
          <button
            key={w.id}
            onClick={() => navigate({ name: "workout-builder", id: w.id })}
            className="surface flex w-full items-center gap-3 p-3 text-left hover:bg-secondary"
          >
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-secondary font-data text-sm font-semibold" data-numeric="true">
              {w.exerciseIds.length}
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-medium">{w.name}</div>
              <div className="truncate text-[11px] text-muted-foreground">{w.description || "—"}</div>
              <div className="mt-1 font-data text-[10px] uppercase tracking-wider text-muted-foreground" data-numeric="true">
                Modified {new Date(w.modifiedDate).toLocaleDateString()}
              </div>
            </div>
            <div className="text-base text-muted-foreground">→</div>
          </button>
        ))}
      </div>
    </div>
  );
}

export function WorkoutEditor({ id }: { id?: string }) {
  const { state, navigate, back, upsertWorkout } = useStore();
  const existing = id ? state.workouts.find((w) => w.id === id) : null;

  const [name, setName] = useState(existing?.name ?? "");
  const [desc, setDesc] = useState(existing?.description ?? "");

  const save = () => {
    if (!name.trim()) return;
    const now = new Date().toISOString();
    const w: Workout = {
      id: existing?.id ?? uid(),
      name: name.trim(), description: desc.trim(),
      exerciseIds: existing?.exerciseIds ?? [],
      createdDate: existing?.createdDate ?? now,
      modifiedDate: now,
    };
    upsertWorkout(w);
    back();
    if (!existing) navigate({ name: "workout-builder", id: w.id });
  };

  return (
    <div className="screen-pad space-y-5">
      <ScreenHeader title={existing ? "Edit Workout" : "New Workout"} onBack={back} />
      <Field label="Workout Name">
        <TextInput placeholder="e.g. Monday Workout" value={name} onChange={(e) => setName(e.target.value)} />
      </Field>
      <Field label="Description">
        <TextArea rows={3} placeholder="Optional context…" value={desc} onChange={(e) => setDesc(e.target.value)} />
      </Field>
      <Btn onClick={save} disabled={!name.trim()}>Save Workout</Btn>
    </div>
  );
}

export function WorkoutBuilder({ id }: { id: string }) {
  const { state, navigate, back, upsertWorkout, deleteWorkout } = useStore();
  const w = state.workouts.find((x) => x.id === id);
  const { confirm, node } = useConfirm();
  const [pickerOpen, setPickerOpen] = useState(false);
  const [q, setQ] = useState("");

  // Local ordered list
  const [order, setOrder] = useState<string[]>(w?.exerciseIds ?? []);
  useEffect(() => { if (w) setOrder(w.exerciseIds); }, [w?.id]); // eslint-disable-line

  if (!w) return (
    <div className="screen-pad">
      <ScreenHeader title="Not Found" onBack={back} />
    </div>
  );

  const exById = (xid: string) => state.exercises.find((e) => e.id === xid);

  const persist = (next: string[]) => {
    setOrder(next);
    upsertWorkout({ ...w, exerciseIds: next });
  };
  const move = (i: number, dir: -1 | 1) => {
    const j = i + dir;
    if (j < 0 || j >= order.length) return;
    const next = [...order];
    [next[i], next[j]] = [next[j], next[i]];
    persist(next);
  };
  const remove = (i: number) => persist(order.filter((_, k) => k !== i));
  const dup = (i: number) => {
    const next = [...order];
    next.splice(i + 1, 0, next[i]);
    persist(next);
  };

  const available = state.exercises.filter((e) =>
    !q || e.title.toLowerCase().includes(q.toLowerCase()),
  );

  return (
    <div className="screen-pad space-y-4">
      {node}
      <ScreenHeader
        title={w.name}
        subtitle={w.description || "Workout builder"}
        onBack={back}
        right={
          <button onClick={() => navigate({ name: "workout-editor", id: w.id })} className="tap w-10 rounded-lg text-base">✎</button>
        }
      />

      <div className="grid grid-cols-2 gap-2">
        <Btn variant="secondary" onClick={() => setPickerOpen(true)}>+ Add Exercise</Btn>
        <Btn
          onClick={() => {
            if (order.length === 0) return;
            navigate({ name: "logging", exerciseId: order[0], workoutId: w.id });
          }}
          disabled={order.length === 0}
        >
          Start Workout
        </Btn>
      </div>

      <div className="space-y-2">
        {order.length === 0 && (
          <div className="surface p-6 text-center text-xs text-muted-foreground">
            Empty workout. Add exercises from your library.
          </div>
        )}
        {order.map((xid, i) => {
          const ex = exById(xid);
          if (!ex) return null;
          return (
            <div key={`${xid}-${i}`} className="surface flex items-center gap-2 p-3">
              <div className="flex flex-col">
                <button onClick={() => move(i, -1)} disabled={i === 0} className="tap w-8 text-xs disabled:opacity-30">▲</button>
                <button onClick={() => move(i, 1)} disabled={i === order.length - 1} className="tap w-8 text-xs disabled:opacity-30">▼</button>
              </div>
              <div className="font-data w-6 text-center text-xs text-muted-foreground" data-numeric="true">{i + 1}</div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-medium">{ex.title}</div>
                <div className="font-data text-[11px] text-muted-foreground" data-numeric="true">
                  {ex.sets} × {ex.reps} · {ex.weight}kg
                </div>
              </div>
              <button onClick={() => dup(i)} className="tap w-9 rounded-lg bg-secondary text-xs" title="Duplicate">⎘</button>
              <button onClick={() => remove(i)} className="tap w-9 rounded-lg bg-secondary text-xs" title="Remove">✕</button>
            </div>
          );
        })}
      </div>

      <Btn variant="secondary" onClick={async () => {
        if (await confirm(`Delete workout "${w.name}"?`)) { deleteWorkout(w.id); back(); }
      }}>
        Delete Workout
      </Btn>

      {pickerOpen && (
        <Modal title="Add Exercise" onClose={() => setPickerOpen(false)}>
          <TextInput placeholder="Search…" value={q} onChange={(e) => setQ(e.target.value)} />
          <div className="mt-3 max-h-[50vh] space-y-1 overflow-y-auto">
            {available.map((e) => (
              <button
                key={e.id}
                onClick={() => { persist([...order, e.id]); setPickerOpen(false); }}
                className="flex w-full items-center justify-between rounded-lg border border-border p-3 text-left hover:bg-secondary"
              >
                <div className="min-w-0">
                  <div className="truncate text-sm font-medium">{e.title}</div>
                  <div className="truncate text-[11px] uppercase tracking-wider text-muted-foreground">
                    {e.category} · {e.equipment}
                  </div>
                </div>
                <div className="text-base">+</div>
              </button>
            ))}
            {available.length === 0 && (
              <div className="p-4 text-center text-xs text-muted-foreground">No exercises in your library.</div>
            )}
          </div>
        </Modal>
      )}
    </div>
  );
}
