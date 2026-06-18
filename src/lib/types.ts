export type Category =
  | "tops"
  | "bottoms"
  | "outerwear"
  | "shoes"
  | "watches"
  | "eyewear"
  | "jewelry"
  | "bags"
  | "belts"
  | "accessories"
  | "unknown";

export type ColorRole = "primary" | "secondary" | "accent" | "stripe" | "trim" | "logo" | "pattern";

export interface WardrobeColor {
  name: string;
  hex: string;
  role: ColorRole;
  confidence: number;
}

export interface QualifiedValue {
  value: string;
  confidence: number;
  status: "known" | "likely" | "unknown";
}

export interface WardrobeMetadata {
  item_name: string;
  category: Category;
  type: string;
  primary_color: WardrobeColor;
  secondary_colors: WardrobeColor[];
  material: QualifiedValue;
  pattern: string;
  brand: QualifiedValue;
  fit: QualifiedValue;
  formality: string;
  season: string[];
  notes: string;
  ai_confidence_overall: number;
}

export interface WardrobeItem extends WardrobeMetadata {
  id: string;
  original_image_data_url: string;
  clean_image_data_url: string;
  user_context: string;
  provider: string;
  provider_version: string;
  archived: boolean;
  deleted: boolean;
  createdDate: string;
  modifiedDate: string;
}

export interface Settings {
  darkMode: boolean;
  fontSize: "compact" | "comfort" | "large";
  mockScenario: "success" | "low_confidence" | "timeout" | "quota" | "invalid_json";
}

export interface AppState {
  items: WardrobeItem[];
  settings: Settings;
}

export const CATEGORIES: Category[] = [
  "tops",
  "bottoms",
  "outerwear",
  "shoes",
  "watches",
  "eyewear",
  "jewelry",
  "bags",
  "belts",
  "accessories",
  "unknown",
];

export const CATEGORY_PREFIX: Record<Category, string> = {
  tops: "TOP",
  bottoms: "BOTTOM",
  outerwear: "OUTER",
  shoes: "FOOT",
  watches: "WATCH",
  eyewear: "EYE",
  jewelry: "JEWEL",
  bags: "BAG",
  belts: "BELT",
  accessories: "ACC",
  unknown: "ACC",
};
