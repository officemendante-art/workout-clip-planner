import { useRef, useState } from "react";
import { Btn, ScreenHeader } from "@/components/ui-bits";
import { useStore } from "@/lib/store";
import type { AppState } from "@/lib/types";

function download(filename: string, content: string, mime = "application/json") {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url; a.download = filename;
  document.body.appendChild(a); a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function toMarkdown(s: AppState) {
  const lines: string[] = ["# Workout Clip Planner — Export", ""];
  if (s.profile) {
    lines.push("## Profile", "");
    lines.push(`- Gender: ${s.profile.gender}`);
    lines.push(`- Age: ${s.profile.age}`);
    lines.push(`- Height: ${s.profile.heightCm} cm`);
    lines.push(`- Weight: ${s.profile.weightKg} kg`);
    lines.push(`- Experience: ${s.profile.experience}`, "");
  }
  lines.push("## Exercises", "");
  s.exercises.forEach((e) => {
    lines.push(`### ${e.title}`);
    lines.push(`- ${e.category} · ${e.equipment} · ${e.difficulty}`);
    lines.push(`- Sets: ${e.sets}, Reps: ${e.reps}, Weight: ${e.weight} kg, Rest: ${e.restTimer}s`);
    if (e.tags.length) lines.push(`- Tags: ${e.tags.join(", ")}`);
    if (e.notes) lines.push(`- Notes: ${e.notes}`);
    if (e.videoName) lines.push(`- Video: ${e.videoName} (${e.clipStart ?? "?"}s → ${e.clipEnd ?? "?"}s)`);
    lines.push("");
  });
  lines.push("## Workouts", "");
  s.workouts.forEach((w) => {
    lines.push(`### ${w.name}`);
    if (w.description) lines.push(w.description);
    w.exerciseIds.forEach((id, i) => {
      const ex = s.exercises.find((x) => x.id === id);
      lines.push(`${i + 1}. ${ex?.title ?? id}`);
    });
    lines.push("");
  });
  lines.push("## Logs", "");
  s.logs.forEach((l) => {
    const ex = s.exercises.find((x) => x.id === l.exerciseId);
    lines.push(`- ${new Date(l.date).toLocaleString()} — ${ex?.title ?? l.exerciseId}`);
    l.sets.forEach((set) => {
      lines.push(`  - Set ${set.setNumber}: ${set.weight}kg × ${set.reps}`);
    });
  });
  return lines.join("\n");
}

export function ExportScreen() {
  const { state, importBackup } = useStore();
  const fileRef = useRef<HTMLInputElement>(null);
  const [msg, setMsg] = useState<string | null>(null);

  const exportJSON = () => {
    // Strip object URLs (won't be valid after reload anyway)
    const clean: AppState = {
      ...state,
      exercises: state.exercises.map((e) => ({ ...e, videoPreviewUrl: undefined })),
    };
    download(`wcp-export-${Date.now()}.json`, JSON.stringify(clean, null, 2));
  };
  const exportMD = () => download(`wcp-export-${Date.now()}.md`, toMarkdown(state), "text/markdown");
  const exportBackup = () => {
    const clean: AppState = {
      ...state,
      exercises: state.exercises.map((e) => ({ ...e, videoPreviewUrl: undefined })),
    };
    download(`wcp-backup-${Date.now()}.json`, JSON.stringify(clean, null, 2));
  };

  const onImport = async (file: File) => {
    try {
      const text = await file.text();
      const parsed = JSON.parse(text) as AppState;
      importBackup(parsed);
      setMsg("Backup imported successfully.");
    } catch {
      setMsg("Could not read that file. Please pick a valid JSON backup.");
    }
  };

  return (
    <div className="screen-pad space-y-4">
      <ScreenHeader title="Export / Import" subtitle="All data stays on this device" />

      <div className="surface space-y-3 p-4">
        <div>
          <div className="mono-label">Library</div>
          <div className="mt-1 grid grid-cols-3 gap-2 text-center">
            <div><div className="font-data text-lg font-semibold" data-numeric="true">{state.exercises.length}</div><div className="text-[10px] uppercase tracking-wider text-muted-foreground">Exercises</div></div>
            <div><div className="font-data text-lg font-semibold" data-numeric="true">{state.workouts.length}</div><div className="text-[10px] uppercase tracking-wider text-muted-foreground">Workouts</div></div>
            <div><div className="font-data text-lg font-semibold" data-numeric="true">{state.logs.length}</div><div className="text-[10px] uppercase tracking-wider text-muted-foreground">Sessions</div></div>
          </div>
        </div>
      </div>

      <Btn onClick={exportJSON}>Export JSON</Btn>
      <Btn variant="secondary" onClick={exportMD}>Export Markdown</Btn>
      <Btn variant="secondary" onClick={exportBackup}>Export Backup</Btn>

      <input
        ref={fileRef} type="file" accept="application/json" className="hidden"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) onImport(f); }}
      />
      <Btn variant="secondary" onClick={() => fileRef.current?.click()}>Import Backup</Btn>

      {msg && <div className="surface p-3 text-xs">{msg}</div>}

      <p className="text-[11px] text-muted-foreground">
        Video files themselves are not embedded in exports — only filenames and clip points. Re-attach your videos after import.
      </p>
    </div>
  );
}
