import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import type {
  AppState,
  ExerciseCard,
  ExerciseLog,
  Settings,
  UserProfile,
  Workout,
} from "./types";

const STORAGE_KEY = "wcp.state.v1";

const nowISO = () => new Date().toISOString();
export const uid = () => Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);

function seedState(): AppState {
  const c1: ExerciseCard = {
    id: uid(), title: "Incline Push Up", category: "Chest", equipment: "Bodyweight",
    difficulty: "beginner", notes: "Hands elevated on a bench. Lower with control.",
    tags: ["push", "warmup"], sets: 3, reps: 10, weight: 0, restTimer: 60,
    createdDate: nowISO(), modifiedDate: nowISO(),
  };
  const c2: ExerciseCard = {
    id: uid(), title: "Band Row", category: "Back", equipment: "Band",
    difficulty: "beginner", notes: "Squeeze shoulder blades. Keep elbows tight.",
    tags: ["pull"], sets: 4, reps: 12, weight: 0, restTimer: 60,
    createdDate: nowISO(), modifiedDate: nowISO(),
  };
  const c3: ExerciseCard = {
    id: uid(), title: "Goblet Squat", category: "Legs", equipment: "Dumbbell",
    difficulty: "intermediate", notes: "Chest tall. Knees track over toes.",
    tags: ["legs", "compound"], sets: 3, reps: 8, weight: 16, restTimer: 90,
    createdDate: nowISO(), modifiedDate: nowISO(),
  };
  const c4: ExerciseCard = {
    id: uid(), title: "Wall Slide", category: "Rehab", equipment: "Bodyweight",
    difficulty: "beginner", notes: "Slow tempo. Shoulders against the wall.",
    tags: ["mobility", "shoulder"], sets: 2, reps: 12, weight: 0, restTimer: 45,
    createdDate: nowISO(), modifiedDate: nowISO(),
  };
  const exercises = [c1, c2, c3, c4];
  const workouts: Workout[] = [
    { id: uid(), name: "Push Day", description: "Chest + light shoulders.", exerciseIds: [c1.id], createdDate: nowISO(), modifiedDate: nowISO() },
    { id: uid(), name: "Upper Body", description: "Push + pull pairing.", exerciseIds: [c1.id, c2.id], createdDate: nowISO(), modifiedDate: nowISO() },
    { id: uid(), name: "Leg Day", description: "Quad-dominant session.", exerciseIds: [c3.id], createdDate: nowISO(), modifiedDate: nowISO() },
    { id: uid(), name: "Home Workout", description: "No equipment, anywhere.", exerciseIds: [c1.id, c4.id, c2.id], createdDate: nowISO(), modifiedDate: nowISO() },
  ];
  return {
    profile: null,
    exercises,
    workouts,
    logs: [],
    settings: { darkMode: false, fontSize: "comfort" },
  };
}

function loadState(): AppState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return seedState();
    const parsed = JSON.parse(raw) as AppState;
    return {
      ...seedState(),
      ...parsed,
      settings: { darkMode: false, fontSize: "comfort", ...(parsed.settings ?? {}) },
    };
  } catch {
    return seedState();
  }
}

export type Screen =
  | { name: "onboarding" }
  | { name: "home" }
  | { name: "cards" }
  | { name: "build" }
  | { name: "log" }
  | { name: "export" }
  | { name: "settings" }
  | { name: "exercise-editor"; id?: string }
  | { name: "exercise-details"; id: string }
  | { name: "video-flow"; returnTo: "exercise-editor"; draftId: string }
  | { name: "workout-editor"; id?: string }
  | { name: "workout-builder"; id: string }
  | { name: "logging"; exerciseId: string; workoutId?: string }
  | { name: "history"; exerciseId?: string };

interface StoreCtx {
  state: AppState;
  setProfile: (p: UserProfile) => void;
  upsertExercise: (e: ExerciseCard) => void;
  deleteExercise: (id: string) => void;
  duplicateExercise: (id: string) => ExerciseCard;
  upsertWorkout: (w: Workout) => void;
  deleteWorkout: (id: string) => void;
  addLog: (l: ExerciseLog) => void;
  updateSettings: (s: Partial<Settings>) => void;
  resetDemo: () => void;
  clearAll: () => void;
  importBackup: (s: AppState) => void;

  screen: Screen;
  navigate: (s: Screen) => void;
  back: () => void;

  // ephemeral draft (for new exercise + video flow)
  draft: Partial<ExerciseCard> | null;
  setDraft: (d: Partial<ExerciseCard> | null) => void;
  patchDraft: (d: Partial<ExerciseCard>) => void;
}

const Ctx = createContext<StoreCtx | null>(null);

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AppState>(() => loadState());
  const [stack, setStack] = useState<Screen[]>([
    state.profile ? { name: "home" } : { name: "onboarding" },
  ]);
  const [draft, setDraft] = useState<Partial<ExerciseCard> | null>(null);

  // Persist state
  const firstRender = useRef(true);
  useEffect(() => {
    if (firstRender.current) { firstRender.current = false; return; }
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); } catch { /* quota */ }
  }, [state]);

  // Apply dark mode + font size at root
  useEffect(() => {
    const root = document.documentElement;
    if (state.settings.darkMode) root.classList.add("dark");
    else root.classList.remove("dark");
    root.setAttribute("data-fs", state.settings.fontSize);
  }, [state.settings.darkMode, state.settings.fontSize]);

  const navigate = useCallback((s: Screen) => setStack((p) => [...p, s]), []);
  const back = useCallback(() =>
    setStack((p) => (p.length > 1 ? p.slice(0, -1) : p)), []);

  const api = useMemo<StoreCtx>(() => ({
    state,
    setProfile: (p) => setState((s) => ({ ...s, profile: p })),
    upsertExercise: (e) => setState((s) => {
      const idx = s.exercises.findIndex((x) => x.id === e.id);
      const next = [...s.exercises];
      if (idx >= 0) next[idx] = { ...e, modifiedDate: nowISO() };
      else next.unshift({ ...e, createdDate: e.createdDate || nowISO(), modifiedDate: nowISO() });
      return { ...s, exercises: next };
    }),
    deleteExercise: (id) => setState((s) => ({
      ...s,
      exercises: s.exercises.filter((e) => e.id !== id),
      workouts: s.workouts.map((w) => ({ ...w, exerciseIds: w.exerciseIds.filter((x) => x !== id) })),
      logs: s.logs.filter((l) => l.exerciseId !== id),
    })),
    duplicateExercise: (id) => {
      const src = state.exercises.find((e) => e.id === id);
      if (!src) throw new Error("missing");
      const copy: ExerciseCard = {
        ...src, id: uid(), title: `${src.title} (Copy)`,
        createdDate: nowISO(), modifiedDate: nowISO(),
      };
      setState((s) => ({ ...s, exercises: [copy, ...s.exercises] }));
      return copy;
    },
    upsertWorkout: (w) => setState((s) => {
      const idx = s.workouts.findIndex((x) => x.id === w.id);
      const next = [...s.workouts];
      if (idx >= 0) next[idx] = { ...w, modifiedDate: nowISO() };
      else next.unshift({ ...w, createdDate: w.createdDate || nowISO(), modifiedDate: nowISO() });
      return { ...s, workouts: next };
    }),
    deleteWorkout: (id) => setState((s) => ({
      ...s,
      workouts: s.workouts.filter((w) => w.id !== id),
      logs: s.logs.map((l) => (l.workoutId === id ? { ...l, workoutId: undefined } : l)),
    })),
    addLog: (l) => setState((s) => ({ ...s, logs: [l, ...s.logs] })),
    updateSettings: (patch) => setState((s) => ({ ...s, settings: { ...s.settings, ...patch } })),
    resetDemo: () => { const seed = seedState(); seed.profile = state.profile; setState(seed); },
    clearAll: () => { localStorage.removeItem(STORAGE_KEY); const seed = seedState(); seed.profile = null; setState(seed); setStack([{ name: "onboarding" }]); },
    importBackup: (s) => setState({
      profile: s.profile ?? null,
      exercises: s.exercises ?? [],
      workouts: s.workouts ?? [],
      logs: s.logs ?? [],
      settings: { darkMode: false, fontSize: "comfort", ...(s.settings ?? {}) },
    }),
    screen: stack[stack.length - 1],
    navigate, back,
    draft, setDraft,
    patchDraft: (d) => setDraft((cur) => ({ ...(cur ?? {}), ...d })),
  }), [state, stack, navigate, back, draft]);

  return <Ctx.Provider value={api}>{children}</Ctx.Provider>;
}

export function useStore() {
  const c = useContext(Ctx);
  if (!c) throw new Error("useStore outside provider");
  return c;
}

export { STORAGE_KEY };
