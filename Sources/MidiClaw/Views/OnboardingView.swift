#if os(macOS)
import SwiftUI

/// Onboarding flow to help users set up the local LLM for Mindi.
struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(index <= currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                midiSetupPage.tag(1)
                llmSetupPage.tag(2)
                readyPage.tag(3)
            }
            .tabViewStyle(.automatic)

            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation { currentPage -= 1 }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentPage < 3 {
                    Button("Next") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        appState.completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(24)
        }
        .frame(width: 600, height: 500)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "pianokeys")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Welcome to MidiClaw")
                .font(.largeTitle.bold())

            Text("Meet **Mindi**, your AI music accompanist.")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Play piano or program drums, and Mindi will generate accompaniment for the other instrument in real time using a local LLM.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            Spacer()
        }
        .padding()
    }

    private var midiSetupPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "cable.connector")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("MIDI Setup")
                .font(.title.bold())

            Text("MidiClaw creates virtual MIDI ports that appear in any DAW or music app.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Virtual MIDI ports are created automatically", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Label("Connect hardware MIDI controllers in Settings", systemImage: "info.circle")
                        .foregroundStyle(.secondary)

                    Label("The AUv3 plugin can be loaded in your DAW", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
            .frame(maxWidth: 400)

            HStack {
                Circle()
                    .fill(appState.isConnected ? .green : .red)
                    .frame(width: 10, height: 10)
                Text(appState.isConnected ? "MIDI system connected" : "MIDI not connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private var llmSetupPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Local LLM Setup")
                .font(.title.bold())

            Text("Mindi uses an on-device language model for intelligent accompaniment. No cloud required.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    SetupStepRow(
                        number: 1,
                        title: "Install Python 3",
                        command: "brew install python3",
                        status: appState.llmManager.setupStatus
                    )

                    SetupStepRow(
                        number: 2,
                        title: "Install MLX Framework",
                        command: "pip3 install mlx mlx-lm",
                        status: appState.llmManager.setupStatus
                    )

                    SetupStepRow(
                        number: 3,
                        title: "Download Model",
                        command: "Auto-downloaded on first use",
                        status: appState.llmManager.setupStatus
                    )
                }
                .padding(8)
            }
            .frame(maxWidth: 450)

            Button("Check Dependencies") {
                Task {
                    await appState.llmManager.checkDependencies()
                }
            }
            .buttonStyle(.bordered)

            if case .needsInstall(let msg) = appState.llmManager.setupStatus {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: 400)
            }

            Text("You can skip this step and set up later in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    private var readyPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("You're Ready!")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 12) {
                Label("Play piano or program drums", systemImage: "pianokeys")
                Label("Chat with Mindi for suggestions", systemImage: "bubble.left.and.bubble.right")
                Label("Toggle Mindi on for auto-accompaniment", systemImage: "wand.and.stars")
                Label("Test the AUv3 plugin from the AU Host tab", systemImage: "puzzlepiece.extension")
            }
            .font(.body)
            .frame(maxWidth: 350, alignment: .leading)

            Spacer()
        }
        .padding()
    }
}

/// A single setup step row in the onboarding flow.
struct SetupStepRow: View {
    let number: Int
    let title: String
    let command: String
    let status: LLMSetupStatus

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.bold())
                Text(command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}
#endif
