#if os(macOS)
import SwiftUI

/// The primary content view with sidebar navigation.
struct MainContentView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab: SidebarTab = .instrument

    enum SidebarTab: String, CaseIterable, Identifiable {
        case instrument = "Instrument"
        case chat = "Chat"
        case monitor = "Monitor"
        case sessions = "Sessions"
        case auHost = "AU Host"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .instrument: return "pianokeys"
            case .chat: return "bubble.left.and.bubble.right"
            case .monitor: return "waveform"
            case .sessions: return "list.bullet.rectangle"
            case .auHost: return "puzzlepiece.extension"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            appState.setup()
        }
        .onDisappear {
            appState.teardown()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(SidebarTab.allCases, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            mindiStatusBar
        }
        .safeAreaInset(edge: .bottom) {
            instrumentSelector
        }
    }

    private var mindiStatusBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(appState.mindi.isEnabled ? Color.accentColor : .secondary)
                Text("Mindi")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $appState.mindi.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }

            if appState.mindi.isEnabled {
                HStack {
                    Circle()
                        .fill(appState.mindi.isGenerating ? .orange : .green)
                        .frame(width: 6, height: 6)
                    Text(appState.mindi.isGenerating ? "Generating..." : "Listening")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Accompanying: \(appState.controlledInstrument.accompanimentInstrument.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    private var instrumentSelector: some View {
        VStack(spacing: 8) {
            Text("You're controlling:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Instrument", selection: $appState.controlledInstrument) {
                ForEach(ControlledInstrument.allCases) { inst in
                    Label(inst.rawValue, systemImage: inst.icon).tag(inst)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 4) {
                Circle()
                    .fill(appState.isConnected ? .green : .red)
                    .frame(width: 6, height: 6)
                Text(appState.isConnected ? "MIDI Connected" : "MIDI Offline")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Detail Views

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .instrument:
            instrumentView
        case .chat:
            ChatView(appState: appState)
        case .monitor:
            MonitorView(appState: appState)
        case .sessions:
            SessionListView(appState: appState)
        case .auHost:
            AUHostView(appState: appState)
        case .settings:
            HostSettingsView(appState: appState)
        }
    }

    @ViewBuilder
    private var instrumentView: some View {
        switch appState.controlledInstrument {
        case .piano:
            PianoRollView(appState: appState)
        case .drums:
            StepSequencerView(appState: appState)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            HStack(spacing: 12) {
                // Recording indicator
                if appState.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                }

                Button {
                    if appState.isRecording {
                        appState.stopRecording()
                    } else {
                        appState.startRecording()
                    }
                } label: {
                    Image(systemName: appState.isRecording ? "stop.circle.fill" : "record.circle")
                        .foregroundStyle(appState.isRecording ? .red : .primary)
                }
                .help(appState.isRecording ? "Stop Recording" : "Start Recording")
            }
        }
    }
}
#endif
