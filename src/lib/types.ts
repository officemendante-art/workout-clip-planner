export type Gender = "male" | "female" | "other" | "prefer_not";
export type Experience = "beginner" | "intermediate" | "advanced";

export interface UserProfile {
  gender: Gender;
  age: number;
  heightCm: number;
  weightKg: number;
  experience: Experience;
}

export interface ExerciseCard {
  id: string;
  title: string;
  category: string;
  equipment: string;
  difficulty: Experience;
  notes: string;
  tags: string[];
  sets: number;
  reps: number;
  weight: number; // kg
  restTimer: number; // seconds
  videoName?: string;
  videoPreviewUrl?: string;
  clipStart?: number;
  clipEnd?: number;
  createdDate: string;
  modifiedDate: string;
}

export interface Workout {
  id: string;
  name: string;
  description: string;
  exerciseIds: string[];
  createdDate: string;
  modifiedDate: string;
}

export interface ExerciseLogSet {
  setNumber: number;
  weight: number;
  reps: number;
  completed: boolean;
}

export interface ExerciseLog {
  id: string;
  exerciseId: string;
  workoutId?: string;
  date: string;
  sets: ExerciseLogSet[];
  notes?: string;
}

export interface Settings {
  darkMode: boolean;
  fontSize: "compact" | "comfort" | "large";
}

export interface AppState {
  profile: UserProfile | null;
  exercises: ExerciseCard[];
  workouts: Workout[];
  logs: ExerciseLog[];
  settings: Settings;
}

export const DEFAULT_CATEGORIES = [
  "Chest",
  "Back",
  "Legs",
  "Shoulders",
  "Arms",
  "Core",
  "Mobility",
  "Rehab",
  "Powerlifting",
  "Custom",
];

export const DEFAULT_EQUIPMENT = [
  "Bodyweight",
  "Dumbbell",
  "Barbell",
  "Band",
  "Bench",
  "Mat",
  "Machine",
  "Kettlebell",
  "Custom",
];

export const DIFFICULTY: Experience[] = ["beginner", "intermediate", "advanced"];

export const REST_OPTIONS = [30, 45, 60, 90, 120, 180, 240];
