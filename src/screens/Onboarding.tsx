import { useState } from "react";
import { Btn, ChipGroup, Field, TextInput } from "@/components/ui-bits";
import { useStore } from "@/lib/store";
import type { Experience, Gender, UserProfile } from "@/lib/types";

const GENDERS: { id: Gender; label: string }[] = [
  { id: "male", label: "Male" },
  { id: "female", label: "Female" },
  { id: "other", label: "Other" },
  { id: "prefer_not", label: "Prefer Not To Say" },
];
const LEVELS: { id: Experience; label: string }[] = [
  { id: "beginner", label: "Beginner" },
  { id: "intermediate", label: "Intermediate" },
  { id: "advanced", label: "Advanced" },
];

export function Onboarding() {
  const { setProfile, navigate } = useStore();
  const [gender, setGender] = useState<Gender>("prefer_not");
  const [age, setAge] = useState(30);
  const [height, setHeight] = useState(175);
  const [weight, setWeight] = useState(75);
  const [exp, setExp] = useState<Experience>("intermediate");

  const save = () => {
    const profile: UserProfile = {
      gender, age, heightCm: height, weightKg: weight, experience: exp,
    };
    setProfile(profile);
    navigate({ name: "home" });
  };

  return (
    <div className="screen-pad space-y-6">
      <div className="space-y-1 pt-6">
        <div className="mono-label">Setup</div>
        <h1 className="text-2xl font-semibold leading-tight">Workout Clip Planner</h1>
        <p className="text-sm text-muted-foreground">
          A personal workout card library. Stored on this device only.
        </p>
      </div>

      <Field label="Gender">
        <div className="flex flex-wrap gap-2">
          {GENDERS.map((g) => (
            <button key={g.id} onClick={() => setGender(g.id)} data-active={gender === g.id} className="chip">
              {g.label}
            </button>
          ))}
        </div>
      </Field>

      <div className="grid grid-cols-3 gap-3">
        <Field label="Age">
          <TextInput type="number" value={age} onChange={(e) => setAge(+e.target.value)} />
        </Field>
        <Field label="Height (cm)">
          <TextInput type="number" value={height} onChange={(e) => setHeight(+e.target.value)} />
        </Field>
        <Field label="Weight (kg)">
          <TextInput type="number" value={weight} onChange={(e) => setWeight(+e.target.value)} />
        </Field>
      </div>

      <Field label="Experience">
        <div className="flex flex-wrap gap-2">
          {LEVELS.map((l) => (
            <button key={l.id} onClick={() => setExp(l.id)} data-active={exp === l.id} className="chip">
              {l.label}
            </button>
          ))}
        </div>
      </Field>

      <Btn onClick={save}>Save Profile</Btn>
    </div>
  );
}
