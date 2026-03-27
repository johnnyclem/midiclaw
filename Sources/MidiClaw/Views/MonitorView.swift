#if os(macOS)
import SwiftUI
import MidiClawCore

/// Main monitor window: live MIDI event log alongside token stream.
struct MonitorView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HSplitView {
            // Left panel: MIDI events
            VStack(alignment: .leading, spacing: 0) {
                headerBar(title: "MIDI Events", icon: "music.note.list")

                if appState.recentEvents.isEmpty {
                    emptyState(message: "No MIDI events yet.\nConnect a MIDI device or virtual port.")
                } else {
                    ScrollViewReader { proxy in
                        List(Array(appState.recentEvents.enumerated()), id: \.offset) { index, event in
                            MIDIEventRow(event: event)
                                .id(index)
                        }
                        .listStyle(.plain)
                        .onChange(of: appState.recentEvents.count) { _, _ in
                            if let last = appState.recentEvents.indices.last {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 300)

            // Right panel: Token stream
            TokenStreamView(tokens: appState.recentTokens)
                .frame(minWidth: 250)
        }
        .toolbar {
            ToolbarItemGroup {
                modeIndicator
                Spacer()
                recordingControls
            }
        }
    }

    private func headerBar(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(appState.recentEvents.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(Capsule())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func emptyState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "pianokeys")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var modeIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: appState.currentMode.icon)
            Text(appState.currentMode.rawValue)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary)
        .clipShape(Capsule())
    }

    private var recordingControls: some View {
        Group {
            if appState.isRecording {
                Button(action: { appState.stopRecording() }) {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .foregroundStyle(.red)
                }
            } else {
                Button(action: { appState.startRecording() }) {
                    Label("Record", systemImage: "record.circle")
                }
            }
        }
    }
}

/// A single row in the MIDI event list.
struct MIDIEventRow: View {
    let event: MIDIEvent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundStyle(iconColor)

            Text(messageDescription)
                .font(.system(.body, design: .monospaced))

            Spacer()

            Text(timestampString)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch event.message {
        case .noteOn: return "arrow.up.circle.fill"
        case .noteOff: return "arrow.down.circle"
        case .controlChange: return "slider.horizontal.3"
        case .programChange: return "square.grid.2x2"
        case .pitchBend: return "arrow.left.arrow.right"
        default: return "circle"
        }
    }

    private var iconColor: Color {
        switch event.message {
        case .noteOn: return .green
        case .noteOff: return .gray
        case .controlChange: return .blue
        case .programChange: return .orange
        case .pitchBend: return .purple
        default: return .secondary
        }
    }

    private var messageDescription: String {
        switch event.message {
        case .noteOn(let ch, let note, let vel):
            return "Ch\(ch + 1) NoteOn  \(MIDIMessage.noteName(note)) vel:\(vel)"
        case .noteOff(let ch, let note, _):
            return "Ch\(ch + 1) NoteOff \(MIDIMessage.noteName(note))"
        case .controlChange(let ch, let cc, let val):
            return "Ch\(ch + 1) CC\(cc) val:\(val)"
        case .programChange(let ch, let prog):
            return "Ch\(ch + 1) PC \(prog)"
        case .pitchBend(let ch, let val):
            return "Ch\(ch + 1) PitchBend \(val)"
        case .channelPressure(let ch, let p):
            return "Ch\(ch + 1) ChanPress \(p)"
        case .polyPressure(let ch, let n, let p):
            return "Ch\(ch + 1) PolyPress \(MIDIMessage.noteName(n)) \(p)"
        case .systemExclusive:
            return "SysEx"
        case .clock: return "Clock"
        case .start: return "Start"
        case .stop: return "Stop"
        case .continue: return "Continue"
        case .activeSensing: return "ActiveSense"
        case .reset: return "Reset"
        }
    }

    private var timestampString: String {
        let ms = Double(event.timestampNs) / 1_000_000.0
        return String(format: "%.1fms", ms)
    }
}
#endif
