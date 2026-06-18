import { Btn, Field, ScreenHeader } from "@/components/ui-bits";
import { useStore } from "@/lib/store";

export function SettingsScreen() {
  const { state, updateSettings, clearAll } = useStore();
  return (
    <div className="screen-pad space-y-4">
      <ScreenHeader title="Settings" subtitle="Mock AI and local app controls" />
      <Field label="Mock Scenario">
        <select
          value={state.settings.mockScenario}
          onChange={(e) => updateSettings({ mockScenario: e.target.value as typeof state.settings.mockScenario })}
          className="w-full rounded-xl border border-border bg-card px-3 py-3 text-sm"
        >
          <option value="success">success</option>
          <option value="low_confidence">low confidence</option>
          <option value="timeout">timeout</option>
          <option value="quota">quota</option>
          <option value="invalid_json">invalid json</option>
        </select>
      </Field>
      <Field label="Font Size">
        <select
          value={state.settings.fontSize}
          onChange={(e) => updateSettings({ fontSize: e.target.value as typeof state.settings.fontSize })}
          className="w-full rounded-xl border border-border bg-card px-3 py-3 text-sm"
        >
          <option value="compact">compact</option>
          <option value="comfort">comfort</option>
          <option value="large">large</option>
        </select>
      </Field>
      <Btn variant="secondary" onClick={() => updateSettings({ darkMode: !state.settings.darkMode })}>
        {state.settings.darkMode ? "Light Mode" : "Dark Mode"}
      </Btn>
      <Btn variant="secondary" onClick={clearAll}>Clear Local Wardrobe</Btn>
    </div>
  );
}
