import { Btn, ScreenHeader } from "@/components/ui-bits";
import { useStore } from "@/lib/store";

function download(filename: string, content: BlobPart, mime: string) {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function catalogMarkdown(items: ReturnType<typeof useStore>["state"]["items"]) {
  const rows = items
    .map((item) => `| ${item.id} | ${item.item_name} | ${item.category} | ${item.type} | ${item.primary_color.name} | ${item.primary_color.hex} |`)
    .join("\n");
  return [
    "# AYA Wardrobe Catalog",
    "",
    "| ID | Name | Category | Type | Color | HEX |",
    "| --- | --- | --- | --- | --- | --- |",
    rows || "| none | No items | - | - | - | - |",
  ].join("\n");
}

export function ExportScreen() {
  const { state } = useStore();
  const items = state.items.filter((item) => !item.deleted && !item.archived);
  const exportJSON = () =>
    download(`AYA_WARDROBE_EXPORT_${new Date().toISOString().slice(0, 10)}.json`, JSON.stringify({ exported_at: new Date().toISOString(), items }, null, 2), "application/json");
  const exportMD = () =>
    download(`AYA_WARDROBE_CATALOG_${new Date().toISOString().slice(0, 10)}.md`, catalogMarkdown(items), "text/markdown");

  return (
    <div className="screen-pad space-y-4">
      <ScreenHeader title="Export Wardrobe" subtitle="AI-readable local backup" />
      <div className="surface p-4">
        <div className="mono-label">Wardrobe</div>
        <div className="font-data mt-2 text-2xl font-semibold" data-numeric="true">{items.length}</div>
        <div className="mt-1 text-xs text-muted-foreground">confirmed local items</div>
      </div>
      <Btn onClick={exportJSON}>Export JSON</Btn>
      <Btn variant="secondary" onClick={exportMD}>Export Markdown Catalog</Btn>
      <p className="text-[11px] leading-relaxed text-muted-foreground">
        This clean Lovable-base build preserves local data and exports AI-readable wardrobe metadata. ZIP export can be restored after the UI foundation is approved.
      </p>
    </div>
  );
}
