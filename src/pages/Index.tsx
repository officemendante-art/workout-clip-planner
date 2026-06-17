import { BottomNav } from "@/components/ui-bits";
import { StoreProvider, useStore } from "@/lib/store";
import { Onboarding } from "@/screens/Onboarding";
import { Home } from "@/screens/Home";
import { CardsLibrary, ExerciseDetails } from "@/screens/Cards";
import { ExerciseEditor, VideoFlow } from "@/screens/ExerciseEditor";
import { WorkoutLibrary, WorkoutEditor, WorkoutBuilder } from "@/screens/Build";
import { LogHub, Logging, History } from "@/screens/Log";
import { ExportScreen } from "@/screens/ExportScreen";
import { SettingsScreen } from "@/screens/SettingsScreen";

function Router() {
  const { screen } = useStore();
  switch (screen.name) {
    case "onboarding": return <Onboarding />;
    case "home": return <Home />;
    case "cards": return <CardsLibrary />;
    case "build": return <WorkoutLibrary />;
    case "log": return <LogHub />;
    case "export": return <ExportScreen />;
    case "settings": return <SettingsScreen />;
    case "exercise-editor": return <ExerciseEditor id={screen.id} />;
    case "exercise-details": return <ExerciseDetails id={screen.id} />;
    case "video-flow": return <VideoFlow />;
    case "workout-editor": return <WorkoutEditor id={screen.id} />;
    case "workout-builder": return <WorkoutBuilder id={screen.id} />;
    case "logging": return <Logging exerciseId={screen.exerciseId} workoutId={screen.workoutId} />;
    case "history": return <History exerciseId={screen.exerciseId} />;
    default: return null;
  }
}

const Index = () => (
  <StoreProvider>
    <div className="min-h-[100dvh] bg-muted/30">
      <div className="app-shell">
        <Router />
        <BottomNav />
      </div>
    </div>
  </StoreProvider>
);

export default Index;
