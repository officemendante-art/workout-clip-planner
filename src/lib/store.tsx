import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import type { AppState, Category, Settings, WardrobeItem, WardrobeMetadata } from "./types";
import { CATEGORY_PREFIX } from "./types";

const STORAGE_KEY = "aya.wardrobe.capture.lovable.v1";

const nowISO = () => new Date().toISOString();
export const uid = () => Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);

function seedState(): AppState {
  return {
    items: [],
    settings: { darkMode: false, fontSize: "comfort", mockScenario: "success" },
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
      items: parsed.items ?? [],
      settings: { ...seedState().settings, ...(parsed.settings ?? {}) },
    };
  } catch {
    return seedState();
  }
}

export type Screen =
  | { name: "home" }
  | { name: "capture" }
  | { name: "review" }
  | { name: "library" }
  | { name: "details"; id: string }
  | { name: "export" }
  | { name: "settings" };

interface StoreCtx {
  state: AppState;
  screen: Screen;
  draft: WardrobeItem | null;
  navigate: (s: Screen) => void;
  back: () => void;
  analyzeMock: (imageDataUrl: string, userContext: string) => WardrobeItem;
  patchDraft: (metadata: Partial<WardrobeItem>) => void;
  confirmDraft: () => void;
  updateItem: (item: WardrobeItem) => void;
  archiveItem: (id: string) => void;
  deleteItem: (id: string) => void;
  updateSettings: (patch: Partial<Settings>) => void;
  clearAll: () => void;
}

const Ctx = createContext<StoreCtx | null>(null);

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AppState>(() => loadState());
  const [stack, setStack] = useState<Screen[]>([{ name: "home" }]);
  const [draft, setDraft] = useState<WardrobeItem | null>(null);
  const firstRender = useRef(true);

  useEffect(() => {
    if (firstRender.current) {
      firstRender.current = false;
      return;
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }, [state]);

  useEffect(() => {
    const root = document.documentElement;
    if (state.settings.darkMode) root.classList.add("dark");
    else root.classList.remove("dark");
    root.setAttribute("data-fs", state.settings.fontSize);
  }, [state.settings]);

  const navigate = useCallback((s: Screen) => setStack((p) => [...p, s]), []);
  const back = useCallback(() => setStack((p) => (p.length > 1 ? p.slice(0, -1) : p)), []);

  const nextId = useCallback(
    (category: Category) => {
      const prefix = CATEGORY_PREFIX[category] || "ACC";
      const used = state.items
        .map((item) => item.id)
        .filter((id) => id.startsWith(`${prefix}-`))
        .map((id) => Number(id.split("-")[1]))
        .filter(Number.isFinite);
      return `${prefix}-${String(used.length ? Math.max(...used) + 1 : 1).padStart(3, "0")}`;
    },
    [state.items],
  );

  const analyzeMock = useCallback(
    (imageDataUrl: string, userContext: string) => {
      const scenario = state.settings.mockScenario;
      if (scenario === "timeout") throw new Error("Mock timeout: AI provider did not respond.");
      if (scenario === "quota") throw new Error("Mock quota exceeded.");
      if (scenario === "invalid_json") throw new Error("Mock invalid JSON response.");

      const low = scenario === "low_confidence";
      const context = userContext.toLowerCase();
      const brown = context.includes("brown") || context.includes("camel");
      const cream = context.includes("cream") || context.includes("off-white") || context.includes("off white");
      const navy = context.includes("navy");
      const metadata: WardrobeMetadata = {
        item_name: brown ? "Camel Textured T-Shirt" : cream ? "Cream Knit Shirt" : navy ? "Navy Polo Shirt" : "Mock Wardrobe Item",
        category: "tops",
        type: brown ? "t-shirt" : navy ? "polo shirt" : "shirt",
        primary_color: {
          name: brown ? "camel brown" : cream ? "warm cream" : navy ? "navy" : "charcoal gray",
          hex: brown ? "#9A5B32" : cream ? "#EFE7D2" : navy ? "#18233F" : "#3B3B3B",
          role: "primary",
          confidence: low ? 0.42 : 0.9,
        },
        secondary_colors: [{ name: "off white", hex: "#F1EAD7", role: "trim", confidence: low ? 0.35 : 0.78 }],
        material: { value: "cotton knit", confidence: low ? 0.36 : 0.72, status: "likely" },
        pattern: "textured",
        brand: { value: "unknown", confidence: 0, status: "unknown" },
        fit: { value: "regular", confidence: low ? 0.28 : 0.55, status: "likely" },
        formality: "casual",
        season: ["spring", "summer"],
        notes: userContext ? `Mock analysis used context: ${userContext}` : "Mock AI response.",
        ai_confidence_overall: low ? 0.45 : 0.88,
      };
      const item: WardrobeItem = {
        ...metadata,
        id: nextId(metadata.category),
        original_image_data_url: imageDataUrl,
        clean_image_data_url: imageDataUrl,
        user_context: userContext,
        provider: "mock",
        provider_version: "mock-local-v1",
        archived: false,
        deleted: false,
        createdDate: nowISO(),
        modifiedDate: nowISO(),
      };
      setDraft(item);
      navigate({ name: "review" });
      return item;
    },
    [navigate, nextId, state.settings.mockScenario],
  );

  const api = useMemo<StoreCtx>(
    () => ({
      state,
      screen: stack[stack.length - 1],
      draft,
      navigate,
      back,
      analyzeMock,
      patchDraft: (patch) => setDraft((cur) => (cur ? { ...cur, ...patch, modifiedDate: nowISO() } : cur)),
      confirmDraft: () => {
        if (!draft) return;
        setState((s) => ({ ...s, items: [draft, ...s.items.filter((item) => item.id !== draft.id)] }));
        setDraft(null);
        navigate({ name: "library" });
      },
      updateItem: (item) =>
        setState((s) => ({
          ...s,
          items: s.items.map((candidate) => (candidate.id === item.id ? { ...item, modifiedDate: nowISO() } : candidate)),
        })),
      archiveItem: (id) =>
        setState((s) => ({
          ...s,
          items: s.items.map((item) => (item.id === id ? { ...item, archived: true, modifiedDate: nowISO() } : item)),
        })),
      deleteItem: (id) =>
        setState((s) => ({
          ...s,
          items: s.items.map((item) => (item.id === id ? { ...item, deleted: true, modifiedDate: nowISO() } : item)),
        })),
      updateSettings: (patch) => setState((s) => ({ ...s, settings: { ...s.settings, ...patch } })),
      clearAll: () => {
        localStorage.removeItem(STORAGE_KEY);
        setState(seedState());
        setDraft(null);
        setStack([{ name: "home" }]);
      },
    }),
    [analyzeMock, back, draft, navigate, stack, state],
  );

  return <Ctx.Provider value={api}>{children}</Ctx.Provider>;
}

export function useStore() {
  const c = useContext(Ctx);
  if (!c) throw new Error("useStore outside provider");
  return c;
}

export { STORAGE_KEY };
