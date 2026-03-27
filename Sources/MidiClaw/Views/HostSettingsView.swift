#if os(macOS)
import SwiftUI

/// Settings view for the host application.
struct HostSettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Agent Mode
                GroupBox("Agent Mode") {
                    VStack(alignment: .leading, spacing: 12) {
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
                    .padding(4)
                }

                // Mindi Configuration
                GroupBox("Mindi Accompanist") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Mindi", isOn: $appState.mindi.isEnabled)

                        Divider()

                        HStack {
                            Text("LLM Model:")
                                .font(.caption)
                            TextField("Model name", text: $appState.llmManager.modelName)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption.monospaced())
                        }

                        HStack {
                            Text("LLM Status:")
                                .font(.caption)
                            statusBadge
                        }

                        Button("Check LLM Dependencies") {
                            Task {
                                await appState.llmManager.checkDependencies()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(4)
                }

                // MIDI Configuration
                GroupBox("MIDI") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Circle()
                                .fill(appState.isConnected ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(appState.isConnected ? "MIDI system active" : "MIDI not connected")
                                .font(.caption)
                        }

                        HStack {
                            Text("Sources: \(appState.availableSources.count)")
                                .font(.caption)
                            Spacer()
                            Text("Destinations: \(appState.availableDestinations.count)")
                                .font(.caption)
                        }

                        Button("Refresh MIDI Ports") {
                            appState.refreshMIDIPorts()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(4)
                }

                // Sequencer Settings
                GroupBox("Sequencer") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("BPM:")
                                .font(.caption)
                            Slider(value: $appState.sequencerModel.bpm, in: 40...300, step: 1)
                            Text("\(Int(appState.sequencerModel.bpm))")
                                .font(.caption.monospaced())
                                .frame(width: 30)
                        }
                    }
                    .padding(4)
                }

                // Onboarding
                GroupBox("Setup") {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Re-run Onboarding") {
                            appState.resetOnboarding()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(4)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch appState.llmManager.setupStatus {
        case .notStarted:
            Label("Not checked", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .checkingDependencies:
            Label("Checking...", systemImage: "arrow.clockwise")
                .font(.caption)
                .foregroundStyle(.orange)
        case .needsInstall(let msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        case .downloading(let progress):
            HStack {
                ProgressView(value: progress)
                    .frame(width: 100)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
            }
        case .ready:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .error(let msg):
            Label(msg, systemImage: "xmark.circle")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
#endif
