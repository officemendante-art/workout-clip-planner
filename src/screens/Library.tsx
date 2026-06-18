import { useMemo, useState } from "react";
import { Btn, Chip, ScreenHeader, TextInput } from "@/components/ui-bits";
import { useStore } from "@/lib/store";
import { CATEGORIES } from "@/lib/types";
import type { Category } from "@/lib/types";
import { MetadataForm } from "./Capture";

export function LibraryScreen() {
  const { state, navigate, archiveItem, deleteItem } = useStore();
  const [q, setQ] = useState("");
  const [cat, setCat] = useState<Category | null>(null);
  const items = useMemo(
    () =>
      state.items.filter((item) => {
        if (item.deleted || item.archived) return false;
        if (cat && item.category !== cat) return false;
        const haystack = `${item.item_name} ${item.category} ${item.type} ${item.primary_color.name} ${item.notes}`.toLowerCase();
        return !q || haystack.includes(q.toLowerCase());
      }),
    [cat, q, state.items],
  );

  return (
    <div className="screen-pad">
      <ScreenHeader title="Wardrobe Library" subtitle={`${items.length} visible items`} />
      <TextInput placeholder="Search name, category, color, notes..." value={q} onChange={(e) => setQ(e.target.value)} />
      <div className="mt-3 flex gap-2 overflow-x-auto pb-1">
        <Chip active={!cat} onClick={() => setCat(null)}>All</Chip>
        {CATEGORIES.map((category) => (
          <Chip key={category} active={cat === category} onClick={() => setCat(category)}>{category}</Chip>
        ))}
      </div>
      <div className="mt-4 space-y-2">
        {items.length === 0 && <div className="surface p-6 text-center text-xs text-muted-foreground">No wardrobe items yet.</div>}
        {items.map((item) => (
          <div key={item.id} className="surface flex gap-3 p-3">
            <button onClick={() => navigate({ name: "details", id: item.id })} className="h-24 w-24 shrink-0 overflow-hidden rounded-lg bg-secondary">
              <img src={item.clean_image_data_url} alt="" className="h-full w-full object-cover" />
            </button>
            <div className="min-w-0 flex-1">
              <button onClick={() => navigate({ name: "details", id: item.id })} className="block w-full text-left">
                <div className="mono-label">{item.id} · {item.category}</div>
                <div className="mt-1 truncate text-sm font-semibold">{item.item_name}</div>
                <div className="mt-1 text-[11px] text-muted-foreground">{item.type} · {item.primary_color.name}</div>
              </button>
              <div className="mt-3 grid grid-cols-2 gap-2">
                <button onClick={() => archiveItem(item.id)} className="tap rounded-lg bg-secondary text-[10px]">Archive</button>
                <button onClick={() => deleteItem(item.id)} className="tap rounded-lg bg-secondary text-[10px]">Delete</button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

export function ItemDetails({ id }: { id: string }) {
  const { state, updateItem, back } = useStore();
  const [item, setItem] = useState(() => state.items.find((candidate) => candidate.id === id) ?? null);
  if (!item) {
    return <div className="screen-pad"><ScreenHeader title="Not Found" onBack={back} /></div>;
  }
  return (
    <div className="screen-pad space-y-4">
      <ScreenHeader title={item.item_name} subtitle={item.id} onBack={back} />
      <img src={item.clean_image_data_url} alt="" className="surface aspect-square w-full object-contain" />
      <MetadataForm item={item} onPatch={(patch) => setItem({ ...item, ...patch })} />
      <Btn onClick={() => { updateItem(item); back(); }}>Save Changes</Btn>
    </div>
  );
}
