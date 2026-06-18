import { useState } from "react";
import { Btn, Field, ScreenHeader, TextArea } from "@/components/ui-bits";
import { useStore } from "@/lib/store";
import type { WardrobeItem } from "@/lib/types";

export function CaptureScreen() {
  const { analyzeMock, back } = useStore();
  const [image, setImage] = useState("");
  const [context, setContext] = useState("");
  const [error, setError] = useState("");

  const onFile = async (file?: File) => {
    setError("");
    if (!file) return;
    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
      setError("Use JPG, PNG, or WEBP.");
      return;
    }
    const reader = new FileReader();
    reader.onload = () => setImage(String(reader.result || ""));
    reader.readAsDataURL(file);
  };

  const analyze = () => {
    try {
      analyzeMock(image, context);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Analysis failed.");
    }
  };

  return (
    <div className="screen-pad space-y-4">
      <ScreenHeader title="Upload Image" subtitle="Analyze one primary garment" onBack={back} />
      <label className="surface flex min-h-[320px] items-center justify-center overflow-hidden text-center">
        <input hidden type="file" accept="image/jpeg,image/png,image/webp" capture="environment" onChange={(e) => onFile(e.target.files?.[0])} />
        {image ? <img src={image} alt="Uploaded item" className="h-full max-h-[420px] w-full object-contain" /> : <div><div className="mono-label">Upload Image</div><p className="mt-2 text-xs text-muted-foreground">Tap to choose a photo.</p></div>}
      </label>
      <Field label="Optional Context">
        <TextArea rows={3} value={context} onChange={(e) => setContext(e.target.value)} placeholder="Actual color is cream, not pure white. Focus on the shirt." />
      </Field>
      {error && <div className="surface border-foreground p-3 text-xs">{error}</div>}
      <Btn onClick={analyze} disabled={!image}>Analyze Item</Btn>
    </div>
  );
}

export function ReviewScreen() {
  const { draft, patchDraft, confirmDraft, back } = useStore();
  if (!draft) {
    return <div className="screen-pad"><ScreenHeader title="Review" onBack={back} /><div className="surface p-4 text-xs">No item is waiting for review.</div></div>;
  }
  return (
    <div className="screen-pad space-y-4">
      <ScreenHeader title="Review Result" subtitle={draft.provider} onBack={back} />
      <div className="grid grid-cols-2 gap-3">
        <img src={draft.original_image_data_url} alt="Original" className="surface aspect-square object-contain" />
        <img src={draft.clean_image_data_url} alt="Clean" className="surface aspect-square object-contain" />
      </div>
      <MetadataForm item={draft} onPatch={patchDraft} />
      <Btn onClick={confirmDraft}>Confirm & Save</Btn>
    </div>
  );
}

export function MetadataForm({ item, onPatch }: { item: WardrobeItem; onPatch: (patch: Partial<WardrobeItem>) => void }) {
  const setPrimary = (patch: Partial<WardrobeItem["primary_color"]>) =>
    onPatch({ primary_color: { ...item.primary_color, ...patch } });
  return (
    <div className="space-y-4">
      <Field label="Item Name"><input value={item.item_name} onChange={(e) => onPatch({ item_name: e.target.value })} /></Field>
      <Field label="Category"><input value={item.category} onChange={(e) => onPatch({ category: e.target.value as WardrobeItem["category"] })} /></Field>
      <Field label="Type"><input value={item.type} onChange={(e) => onPatch({ type: e.target.value })} /></Field>
      <Field label="Primary Color">
        <div className="grid grid-cols-[44px_1fr] gap-2">
          <span className="rounded-lg border border-border" style={{ background: item.primary_color.hex }} />
          <input value={item.primary_color.name} onChange={(e) => setPrimary({ name: e.target.value })} />
          <span />
          <input value={item.primary_color.hex} onChange={(e) => setPrimary({ hex: e.target.value })} />
        </div>
      </Field>
      <Field label="Material"><input value={item.material.value} onChange={(e) => onPatch({ material: { ...item.material, value: e.target.value } })} /></Field>
      <Field label="Notes"><TextArea rows={3} value={item.notes} onChange={(e) => onPatch({ notes: e.target.value })} /></Field>
    </div>
  );
}
