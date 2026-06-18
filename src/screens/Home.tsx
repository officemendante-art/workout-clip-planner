import { ScreenHeader } from "@/components/ui-bits";
import { useStore } from "@/lib/store";

export function Home() {
  const { state, navigate, draft } = useStore();
  const items = state.items.filter((item) => !item.deleted && !item.archived);
  const last = items[0]?.item_name ?? "None";
  const tiles = [
    { label: "Upload Image", sub: "New item", onClick: () => navigate({ name: "capture" }) },
    { label: "Wardrobe Library", sub: `${items.length} saved`, onClick: () => navigate({ name: "library" }) },
    { label: "Export Wardrobe", sub: "Backup", onClick: () => navigate({ name: "export" }) },
    { label: "API Settings", sub: "Mock mode", onClick: () => navigate({ name: "settings" }) },
  ];

  return (
    <div className="screen-pad">
      <ScreenHeader title="AYA Wardrobe" subtitle="Capture OS" />

      <div className="grid grid-cols-3 gap-2">
        <div className="surface p-3">
          <div className="mono-label">Saved</div>
          <div className="font-data mt-1 text-lg font-semibold" data-numeric="true">{items.length}</div>
        </div>
        <div className="surface p-3">
          <div className="mono-label">Review</div>
          <div className="font-data mt-1 text-lg font-semibold" data-numeric="true">{draft ? 1 : 0}</div>
        </div>
        <div className="surface p-3">
          <div className="mono-label">Last</div>
          <div className="mt-1 truncate text-xs font-medium">{last}</div>
        </div>
      </div>

      <div className="mt-5 grid grid-cols-2 gap-3">
        {tiles.map((tile) => (
          <button
            key={tile.label}
            onClick={tile.onClick}
            className="surface flex aspect-square flex-col justify-between p-4 text-left transition-colors hover:bg-secondary"
          >
            <span className="mono-label">{tile.sub}</span>
            <span className="text-sm font-semibold uppercase leading-tight tracking-wider">{tile.label}</span>
          </button>
        ))}
      </div>

      <section className="mt-8">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="mono-label">Recent Items</h2>
          <button onClick={() => navigate({ name: "library" })} className="text-[11px] uppercase tracking-wider text-muted-foreground">All →</button>
        </div>
        <div className="surface divide-hair overflow-hidden">
          {items.slice(0, 3).length === 0 && <div className="p-4 text-xs text-muted-foreground">No wardrobe items yet.</div>}
          {items.slice(0, 3).map((item) => (
            <button
              key={item.id}
              onClick={() => navigate({ name: "details", id: item.id })}
              className="flex w-full items-center gap-3 p-3 text-left hover:bg-secondary"
            >
              <img src={item.clean_image_data_url} alt="" className="h-12 w-12 rounded-lg bg-secondary object-cover" />
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-medium">{item.item_name}</div>
                <div className="truncate text-[11px] uppercase tracking-wider text-muted-foreground">
                  {item.id} · {item.category} · {item.primary_color.name}
                </div>
              </div>
            </button>
          ))}
        </div>
      </section>
    </div>
  );
}
