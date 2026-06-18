import { useMemo, useState } from "react";
import { Btn, Chip, ScreenHeader, TextInput, VideoThumb, useConfirm } from "@/components/ui-bits";
import { useStore } from "@/lib/store";
import { DEFAULT_CATEGORIES } from "@/lib/types";
import { cn } from "@/lib/utils";

export function CardsLibrary() {
  const { state, navigate } = useStore();
  const [q, setQ] = useState("");
  const [cat, setCat] = useState<string | null>(null);
  const [view, setView] = useState<"grid" | "list">("list");

  const userCats = useMemo(() => {
    const set = new Set<string>(DEFAULT_CATEGORIES);
    state.exercises.forEach((e) => set.add(e.category));
    return Array.from(set);
  }, [state.exercises]);

  const filtered = state.exercises.filter((e) => {
    if (cat && e.category !== cat) return false;
    if (q && !`${e.title} ${e.tags.join(" ")} ${e.equipment}`.toLowerCase().includes(q.toLowerCase())) return false;
    return true;
  });

  return (
    <div className="screen-pad">
      <ScreenHeader
        title="Exercise Library"
        subtitle={`${state.exercises.length} cards`}
        right={
          <button onClick={() => navigate({ name: "exercise-editor" })} className="tap w-10 rounded-lg bg-foreground text-base text-background">+</button>
        }
      />

      <TextInput placeholder="Search title, tag, equipment…" value={q} onChange={(e) => setQ(e.target.value)} />

      <div className="mt-3 flex items-center gap-2">
        <div className="flex flex-1 gap-2 overflow-x-auto pb-1 [&::-webkit-scrollbar]:hidden">
          <Chip active={!cat} onClick={() => setCat(null)}>All</Chip>
          {userCats.map((c) => (
            <Chip key={c} active={cat === c} onClick={() => setCat(c)}>{c}</Chip>
          ))}
        </div>
        <button
          onClick={() => setView(view === "grid" ? "list" : "grid")}
          className="tap w-10 rounded-lg border border-border text-base"
          aria-label="Toggle view"
        >
          {view === "grid" ? "☰" : "▦"}
        </button>
      </div>

      <div className={cn(
        "mt-4",
        view === "grid" ? "grid grid-cols-2 gap-3" : "space-y-2",
      )}>
        {filtered.length === 0 && (
          <div className="surface col-span-2 p-6 text-center text-xs text-muted-foreground">
            No exercises match your filters.
          </div>
        )}
        {filtered.map((e) => (
          <button
            key={e.id}
            onClick={() => navigate({ name: "exercise-details", id: e.id })}
            className="surface text-left transition-colors hover:bg-secondary"
          >
            {view === "grid" ? (
              <div className="p-3">
                <VideoThumb url={e.videoPreviewUrl} name={e.videoName} size="lg" />
                <div className="mt-2 truncate text-sm font-medium">{e.title}</div>
                <div className="mt-1 truncate text-[10px] uppercase tracking-wider text-muted-foreground">
                  {e.category} · {e.equipment}
                </div>
                <div className="mt-2 font-data text-[11px] text-muted-foreground" data-numeric="true">
                  {e.sets} × {e.reps} · {e.weight}kg · {e.restTimer}s
                </div>
              </div>
            ) : (
              <div className="flex items-center gap-3 p-3">
                <VideoThumb url={e.videoPreviewUrl} name={e.videoName} size="md" />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-sm font-medium">{e.title}</div>
                  <div className="truncate text-[10px] uppercase tracking-wider text-muted-foreground">
                    {e.category} · {e.equipment} · {e.difficulty}
                  </div>
                  <div className="mt-1 font-data text-[11px] text-muted-foreground" data-numeric="true">
                    {e.sets} × {e.reps} · {e.weight}kg · rest {e.restTimer}s
                  </div>
                </div>
              </div>
            )}
          </button>
        ))}
      </div>
    </div>
  );
}

export function ExerciseDetails({ id }: { id: string }) {
  const { state, navigate, back, deleteExercise, duplicateExercise } = useStore();
  const { confirm, node } = useConfirm();
  const e = state.exercises.find((x) => x.id === id);
  if (!e) return (
    <div className="screen-pad">
      <ScreenHeader title="Not Found" onBack={back} />
      <p className="text-sm text-muted-foreground">This card no longer exists.</p>
    </div>
  );

  const fmt = (d: string) => new Date(d).toLocaleDateString();
  const meta: [string, string][] = [
    ["Category", e.category],
    ["Equipment", e.equipment],
    ["Difficulty", e.difficulty],
  ];
  const nums: [string, string][] = [
    ["Sets", String(e.sets)],
    ["Reps", String(e.reps)],
    ["Weight", `${e.weight} kg`],
    ["Rest", `${e.restTimer}s`],
  ];

  return (
    <div className="screen-pad space-y-5">
      {node}
      <ScreenHeader title={e.title} onBack={back} />

      <VideoThumb url={e.videoPreviewUrl} name={e.videoName} size="lg" />

      <div className="grid grid-cols-3 gap-2">
        {meta.map(([k, v]) => (
          <div key={k} className="surface p-3">
            <div className="mono-label">{k}</div>
            <div className="mt-1 truncate text-sm font-medium">{v}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-4 gap-2">
        {nums.map(([k, v]) => (
          <div key={k} className="surface p-3 text-center">
            <div className="mono-label">{k}</div>
            <div className="mt-1 font-data text-sm font-semibold" data-numeric="true">{v}</div>
          </div>
        ))}
      </div>

      {e.notes && (
        <div className="surface p-3">
          <div className="mono-label mb-1">Notes</div>
          <p className="whitespace-pre-wrap text-sm">{e.notes}</p>
        </div>
      )}

      {e.tags.length > 0 && (
        <div>
          <div className="mono-label mb-2">Tags</div>
          <div className="flex flex-wrap gap-2">
            {e.tags.map((t) => <Chip key={t}>{t}</Chip>)}
          </div>
        </div>
      )}

      <div className="grid grid-cols-2 gap-2 text-[10px] uppercase tracking-wider text-muted-foreground">
        <div>Created <span className="font-data text-foreground" data-numeric="true">{fmt(e.createdDate)}</span></div>
        <div>Modified <span className="font-data text-foreground" data-numeric="true">{fmt(e.modifiedDate)}</span></div>
      </div>

      <div className="grid grid-cols-2 gap-2 pt-2">
        <Btn variant="secondary" onClick={() => navigate({ name: "exercise-editor", id: e.id })}>Edit</Btn>
        <Btn variant="secondary" onClick={() => { const c = duplicateExercise(e.id); navigate({ name: "exercise-details", id: c.id }); }}>Duplicate</Btn>
        <Btn variant="secondary" onClick={() => navigate({ name: "history", exerciseId: e.id })}>History</Btn>
        <Btn variant="secondary" onClick={async () => {
          if (await confirm(`Delete "${e.title}"? Logs & workout references will be cleaned up.`)) {
            deleteExercise(e.id); back();
          }
        }}>Delete</Btn>
      </div>

      <Btn onClick={() => navigate({ name: "logging", exerciseId: e.id })}>Start Logging</Btn>
    </div>
  );
}
