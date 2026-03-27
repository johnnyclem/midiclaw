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

        // Main monitor window
        Window("MidiClaw Monitor", id: "monitor") {
            MonitorView(appState: appState)
                .frame(minWidth: 600, minHeight: 400)
        }

        // Session browser window
        Window("Sessions", id: "sessions") {
            SessionListView(appState: appState)
                .frame(minWidth: 500, minHeight: 300)
        }

        // Settings window
        Settings {
            SettingsView(appState: appState)
        }
    }

    private var menuBarIcon: String {
        switch appState.currentMode {
        case .monitor: return "eye"
        case .copilot: return "person.2"
        case .autonomous: return "bolt"
        }
    }

    init() {}
}

/// Placeholder settings view.
struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Section("Agent Mode") {
                Picker("Mode", selection: $appState.currentMode) {
                    ForEach(AgentMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(appState.currentMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 200)
    }
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
