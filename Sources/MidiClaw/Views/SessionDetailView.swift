#if os(macOS)
import SwiftUI
import MidiClawCore

/// Detail view for a selected session: playback controls, export, token preview.
struct SessionDetailView: View {
    let session: Session
    @ObservedObject var appState: AppState
    @State private var showingExporter = false
    @State private var isPlaying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Session info header
            VStack(alignment: .leading, spacing: 8) {
                Text(session.name)
                    .font(.title2)

                HStack(spacing: 16) {
                    Label(dateString, systemImage: "calendar")
                    if let duration = session.durationSeconds {
                        Label(durationString(duration), systemImage: "clock")
                    }
                    Label("\(session.eventCount) events", systemImage: "music.note")
                }
                .foregroundStyle(.secondary)
            }

            Divider()

            // Playback controls
            HStack(spacing: 12) {
                Button(action: togglePlayback) {
                    Label(
                        isPlaying ? "Stop" : "Play",
                        systemImage: isPlaying ? "stop.fill" : "play.fill"
                    )
                }
                .controlSize(.large)

                Spacer()

                Button("Export MIDI...") {
                    showingExporter = true
                }
            }

            Divider()

            // Event preview
            Text("Event Preview")
                .font(.headline)

            Text("Load session events to see a preview of the token stream.")
                .foregroundStyle(.secondary)
                .font(.callout)

            Spacer()
        }
        .padding()
        .fileExporter(
            isPresented: $showingExporter,
            document: MIDIFileDocument(session: session, store: appState.sessionStore),
            contentType: .midi,
            defaultFilename: "\(session.name).mid"
        ) { result in
            if case .failure(let error) = result {
                Log.app.error("Export failed: \(error.localizedDescription)")
            }
        }
    }

    private func togglePlayback() {
        if isPlaying {
            appState.player?.stop()
            isPlaying = false
        } else {
            do {
                appState.player?.onEventsOutput = { events in
                    // Send to MIDI output
                    try? appState.portManager?.send(events: events)
                }
                appState.player?.onPlaybackComplete = {
                    Task { @MainActor in
                        isPlaying = false
                    }
                }
                try appState.player?.play(sessionId: session.id)
                isPlaying = true
            } catch {
                Log.app.error("Playback failed: \(error.localizedDescription)")
            }
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: session.createdAt)
    }

    private func durationString(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - MIDI File Document for export

import UniformTypeIdentifiers

struct MIDIFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.midi] }
    static var writableContentTypes: [UTType] { [.midi] }

    let data: Data

    init(session: Session, store: SessionStore?) {
        // Attempt to build MIDI file data from session
        guard let store = store,
              let events = try? store.fetchEvents(forSession: session.id) else {
            self.data = Data()
            return
        }

        let tokens = events.map { MidiToken(rawValue: $0.tokenId) }
        let decoder = MidiDecoder()
        let midiEvents = decoder.decode(tokens)
        let exporter = MIDIFileExporter()

        self.data = (try? exporter.export(events: midiEvents)) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
#endif
