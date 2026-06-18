import { BottomNav } from "@/components/ui-bits";
import { StoreProvider, useStore } from "@/lib/store";
import { CaptureScreen, ReviewScreen } from "@/screens/Capture";
import { ExportScreen } from "@/screens/ExportScreen";
import { Home } from "@/screens/Home";
import { ItemDetails, LibraryScreen } from "@/screens/Library";
import { SettingsScreen } from "@/screens/SettingsScreen";

function Router() {
  const { screen } = useStore();
  switch (screen.name) {
    case "home":
      return <Home />;
    case "capture":
      return <CaptureScreen />;
    case "review":
      return <ReviewScreen />;
    case "library":
      return <LibraryScreen />;
    case "details":
      return <ItemDetails id={screen.id} />;
    case "export":
      return <ExportScreen />;
    case "settings":
      return <SettingsScreen />;
    default:
      return null;
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
