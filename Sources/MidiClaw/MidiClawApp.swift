#if os(macOS)
import SwiftUI
import MidiClawCore

@main
struct MidiClawApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Menu bar presence
        MenuBarExtra("MidiClaw", systemImage: menuBarIcon) {
            MenuBarView(appState: appState)
        }
        .menuBarExtraStyle(.window)

        // Main application window
        WindowGroup("MidiClaw") {
            Group {
                if appState.hasCompletedOnboarding {
                    MainContentView(appState: appState)
                } else {
                    OnboardingView(appState: appState)
                        .onAppear {
                            appState.setup()
                        }
                }
            }
        }
        .defaultSize(width: 1100, height: 700)

        // Session browser window
        Window("Sessions", id: "sessions") {
            SessionListView(appState: appState)
                .frame(minWidth: 500, minHeight: 300)
        }

        // Settings window
        Settings {
            HostSettingsView(appState: appState)
                .frame(width: 500, height: 600)
        }
    }

    private var menuBarIcon: String {
        if appState.mindi.isEnabled {
            return "wand.and.stars"
        }
        switch appState.currentMode {
        case .monitor: return "eye"
        case .copilot: return "person.2"
        case .autonomous: return "bolt"
        }
    }

    init() {}
}
#else
// Non-macOS: simple entry point for build verification
@main
struct MidiClawApp {
    static func main() {
        print("MidiClaw requires macOS 14.0 or later.")
    }
}
#endif
