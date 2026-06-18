import { useEffect, useMemo, useState } from "react";
import {
  Btn, Chip, Field, ScreenHeader, Stepper, TextArea, TextInput, VideoThumb,
} from "@/components/ui-bits";
import { useStore, uid } from "@/lib/store";
import {
  DEFAULT_CATEGORIES, DEFAULT_EQUIPMENT, DIFFICULTY, REST_OPTIONS,
  type ExerciseCard, type Experience,
} from "@/lib/types";

const empty = (): Partial<ExerciseCard> => ({
  id: uid(),
  title: "",
  category: "Chest",
  equipment: "Bodyweight",
  difficulty: "beginner",
  notes: "",
  tags: [],
  sets: 3,
  reps: 10,
  weight: 0,
  restTimer: 60,
});

export function ExerciseEditor({ id }: { id?: string }) {
  const { state, navigate, back, upsertExercise, draft, setDraft, patchDraft } = useStore();
  const editingExisting = !!id;

  // Initialise draft once
  useEffect(() => {
    if (draft) return;
    if (id) {
      const found = state.exercises.find((x) => x.id === id);
      if (found) setDraft({ ...found });
      else setDraft(empty());
    } else {
      setDraft(empty());
    }
  }, [id]); // eslint-disable-line

  const d = draft ?? empty();
  const [tagInput, setTagInput] = useState("");

  const valid = (d.title ?? "").trim().length > 0;

  const save = () => {
    if (!valid) return;
    const now = new Date().toISOString();
    const card: ExerciseCard = {
      id: d.id!, title: d.title!.trim(), category: d.category || "Custom",
      equipment: d.equipment || "Custom", difficulty: (d.difficulty as Experience) || "beginner",
      notes: d.notes || "", tags: d.tags || [],
      sets: d.sets ?? 3, reps: d.reps ?? 10, weight: d.weight ?? 0, restTimer: d.restTimer ?? 60,
      videoName: d.videoName, videoPreviewUrl: d.videoPreviewUrl,
      clipStart: d.clipStart, clipEnd: d.clipEnd,
      createdDate: d.createdDate || now, modifiedDate: now,
    };
    upsertExercise(card);
    setDraft(null);
    back();
  };

  const addTag = () => {
    const t = tagInput.trim().toLowerCase();
    if (!t) return;
    const set = new Set([...(d.tags ?? []), t]);
    patchDraft({ tags: Array.from(set) });
    setTagInput("");
  };

  return (
    <div className="screen-pad space-y-5">
      <ScreenHeader
        title={editingExisting ? "Edit Exercise" : "New Exercise"}
        onBack={() => { setDraft(null); back(); }}
      />

      <Field label="Exercise Name">
        <TextInput
          placeholder="e.g. Incline Push Up"
          value={d.title ?? ""}
          onChange={(e) => patchDraft({ title: e.target.value })}
        />
      </Field>

      <Field label="Video Clip">
        <div className="surface flex items-center gap-3 p-3">
          <VideoThumb url={d.videoPreviewUrl} name={d.videoName} size="md" />
          <div className="min-w-0 flex-1">
            <div className="truncate text-xs font-medium">{d.videoName || "No video selected"}</div>
            {d.clipStart != null && d.clipEnd != null && (
              <div className="mt-1 font-data text-[11px] text-muted-foreground" data-numeric="true">
                Clip {d.clipStart.toFixed(1)}s → {d.clipEnd.toFixed(1)}s
              </div>
            )}
          </div>
          <button
            type="button"
            onClick={() => navigate({ name: "video-flow", returnTo: "exercise-editor", draftId: d.id! })}
            className="tap rounded-lg bg-secondary px-3 text-[11px] uppercase tracking-wider"
          >
            Import / Trim
          </button>
        </div>
      </Field>

      <Field label="Category">
        <div className="flex flex-wrap gap-2">
          {DEFAULT_CATEGORIES.map((c) => (
            <Chip key={c} active={d.category === c} onClick={() => patchDraft({ category: c })}>{c}</Chip>
          ))}
        </div>
      </Field>

      <Field label="Equipment">
        <div className="flex flex-wrap gap-2">
          {DEFAULT_EQUIPMENT.map((c) => (
            <Chip key={c} active={d.equipment === c} onClick={() => patchDraft({ equipment: c })}>{c}</Chip>
          ))}
        </div>
      </Field>

      <Field label="Difficulty">
        <div className="flex flex-wrap gap-2">
          {DIFFICULTY.map((c) => (
            <Chip key={c} active={d.difficulty === c} onClick={() => patchDraft({ difficulty: c })}>
              {c}
            </Chip>
          ))}
        </div>
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <Field label="Sets">
          <Stepper value={d.sets ?? 3} onChange={(n) => patchDraft({ sets: n })} min={1} max={20} />
        </Field>
        <Field label="Reps">
          <Stepper value={d.reps ?? 10} onChange={(n) => patchDraft({ reps: n })} min={1} max={100} />
        </Field>
        <Field label="Weight (kg)">
          <Stepper value={d.weight ?? 0} onChange={(n) => patchDraft({ weight: n })} min={0} max={500} step={2.5 as any} />
        </Field>
        <Field label="Rest (s)">
          <div className="flex flex-wrap gap-2">
            {REST_OPTIONS.map((r) => (
              <Chip key={r} active={d.restTimer === r} onClick={() => patchDraft({ restTimer: r })}>{r}s</Chip>
            ))}
          </div>
        </Field>
      </div>

      <Field label="Notes">
        <TextArea rows={3} placeholder="Form cues, tempo, setup…"
          value={d.notes ?? ""} onChange={(e) => patchDraft({ notes: e.target.value })} />
      </Field>

      <Field label="Tags">
        <div className="flex gap-2">
          <TextInput
            placeholder="add tag…"
            value={tagInput}
            onChange={(e) => setTagInput(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); addTag(); } }}
          />
          <button onClick={addTag} className="tap w-12 rounded-xl bg-secondary text-base">+</button>
        </div>
        {(d.tags ?? []).length > 0 && (
          <div className="mt-2 flex flex-wrap gap-2">
            {(d.tags ?? []).map((t) => (
              <Chip key={t} active onClick={() => patchDraft({ tags: (d.tags ?? []).filter((x) => x !== t) })}>
                {t} ✕
              </Chip>
            ))}
          </div>
        )}
      </Field>

      <Btn onClick={save} disabled={!valid}>Save Exercise Card</Btn>
    </div>
  );
}

// =====================
// Video Import / Clip Flow
// =====================
export function VideoFlow() {
  const { draft, patchDraft, back } = useStore();
  const d = draft ?? {};
  const [step, setStep] = useState<"select" | "preview" | "trim">(
    d.videoPreviewUrl ? "preview" : "select",
  );
  const [duration, setDuration] = useState<number>(d.clipEnd ?? 10);
  const [start, setStart] = useState<number>(d.clipStart ?? 0);
  const [end, setEnd] = useState<number>(d.clipEnd ?? Math.min(10, d.clipEnd ?? 10));

  const onSelectFile = (file: File) => {
    const url = URL.createObjectURL(file);
    patchDraft({ videoName: file.name, videoPreviewUrl: url, clipStart: undefined, clipEnd: undefined });
    setStep("preview");
  };

  return (
    <div className="screen-pad space-y-5">
      <ScreenHeader title="Video Clip" onBack={back} subtitle={`Step: ${step}`} />

      {step === "select" && (
        <div className="space-y-4">
          <label className="surface flex h-44 cursor-pointer flex-col items-center justify-center gap-2 border-dashed text-center">
            <div className="text-2xl">⬆</div>
            <div className="text-sm font-medium">Select Video</div>
            <div className="text-[11px] text-muted-foreground">MP4 / MOV — stays on this device</div>
            <input
              type="file" accept="video/*" className="hidden"
              onChange={(e) => { const f = e.target.files?.[0]; if (f) onSelectFile(f); }}
            />
          </label>
          <Btn variant="secondary" onClick={() => {
            patchDraft({ videoName: "demo-clip.mp4", videoPreviewUrl: undefined, clipStart: 0, clipEnd: 8 });
            setStep("preview");
          }}>
            Use Placeholder Clip
          </Btn>
        </div>
      )}

      {step === "preview" && (
        <div className="space-y-4">
          {d.videoPreviewUrl ? (
            <video
              src={d.videoPreviewUrl} controls playsInline
              onLoadedMetadata={(e) => {
                const v = e.currentTarget.duration;
                if (isFinite(v) && v > 0) { setDuration(v); if (end > v) setEnd(v); }
              }}
              className="aspect-video w-full rounded-xl border border-border bg-black"
            />
          ) : (
            <VideoThumb name={d.videoName} size="lg" />
          )}
          <div className="text-xs text-muted-foreground">
            File: <span className="font-data text-foreground" data-numeric="true">{d.videoName}</span>
          </div>
          <div className="grid grid-cols-2 gap-2">
            <Btn variant="secondary" onClick={() => setStep("select")}>Pick Different</Btn>
            <Btn onClick={() => setStep("trim")}>Trim Video</Btn>
          </div>
        </div>
      )}

      {step === "trim" && (
        <div className="space-y-4">
          {d.videoPreviewUrl ? (
            <video src={d.videoPreviewUrl} controls playsInline className="aspect-video w-full rounded-xl border border-border bg-black" />
          ) : (
            <VideoThumb name={d.videoName} size="lg" />
          )}
          <div className="space-y-3">
            <div className="flex items-center justify-between text-[11px] uppercase tracking-wider text-muted-foreground">
              <span>Start</span>
              <span className="font-data text-foreground" data-numeric="true">{start.toFixed(1)}s</span>
            </div>
            <input
              type="range" min={0} max={duration} step={0.1} value={start}
              onChange={(e) => { const v = +e.target.value; setStart(Math.min(v, end - 0.1)); }}
              className="w-full accent-foreground"
            />
            <div className="flex items-center justify-between text-[11px] uppercase tracking-wider text-muted-foreground">
              <span>End</span>
              <span className="font-data text-foreground" data-numeric="true">{end.toFixed(1)}s</span>
            </div>
            <input
              type="range" min={0} max={duration} step={0.1} value={end}
              onChange={(e) => { const v = +e.target.value; setEnd(Math.max(v, start + 0.1)); }}
              className="w-full accent-foreground"
            />
            <div className="surface p-3 text-center">
              <div className="mono-label">Clip Length</div>
              <div className="mt-1 font-data text-lg font-semibold" data-numeric="true">
                {(end - start).toFixed(1)}s
              </div>
            </div>
          </div>
          <Btn onClick={() => { patchDraft({ clipStart: start, clipEnd: end }); back(); }}>Save Clip</Btn>
        </div>
      )}
    </div>
  );
}
