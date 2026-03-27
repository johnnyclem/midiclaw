#if os(macOS)
import SwiftUI
import MidiClawCore

/// Menu bar dropdown content: mode selector, port status, recording controls.
struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "pianokeys")
                Text("MidiClaw")
                    .font(.headline)
                Spacer()
                connectionIndicator
            }
            .padding(.bottom, 4)

            Divider()

            // Mode Selector
            VStack(alignment: .leading, spacing: 6) {
                Text("Agent Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Mode", selection: $appState.currentMode) {
                    ForEach(AgentMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            // Recording Controls
            HStack {
                if appState.isRecording {
                    Button(action: { appState.stopRecording() }) {
                        Label("Stop Recording", systemImage: "stop.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)

                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(0.8)
                } else {
                    Button(action: { appState.startRecording() }) {
                        Label("Record", systemImage: "record.circle")
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("\(appState.recentEvents.count) events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Mindi Toggle
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(appState.mindi.isEnabled ? .accent : .secondary)
                Text("Mindi Accompanist")
                Spacer()
                Toggle("", isOn: $appState.mindi.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }

            Divider()

            // Quick Actions
            Button(action: { openWindow(id: "sessions") }) {
                Label("Sessions (\(appState.sessions.count))", systemImage: "list.bullet")
            }
            .buttonStyle(.plain)

            Divider()

            // MIDI Port Summary
            VStack(alignment: .leading, spacing: 2) {
                Text("MIDI Ports")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(appState.availableSources.count) sources, \(appState.availableDestinations.count) destinations")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            Button("Quit MidiClaw") {
                appState.teardown()
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            appState.setup()
        }
    }

    private var connectionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(appState.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(appState.isConnected ? "Active" : "Offline")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
