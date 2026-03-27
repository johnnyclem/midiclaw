#if os(macOS)
import SwiftUI
import MidiClawCore

/// Browse, search, and manage recorded MIDI sessions.
struct SessionListView: View {
    @ObservedObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedSessionId: UUID?
    @State private var showingImporter = false

    private var filteredSessions: [Session] {
        if searchText.isEmpty {
            return appState.sessions
        }
        return appState.sessions.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(filteredSessions, selection: $selectedSessionId) { session in
                SessionRow(session: session)
                    .tag(session.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            deleteSession(session)
                        }
                    }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, prompt: "Search sessions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Import MIDI File...") {
                            showingImporter = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationTitle("Sessions")
        } detail: {
            if let sessionId = selectedSessionId,
               let session = appState.sessions.first(where: { $0.id == sessionId }) {
                SessionDetailView(session: session, appState: appState)
            } else {
                Text("Select a session")
                    .foregroundStyle(.secondary)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.midi],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    private func deleteSession(_ session: Session) {
        do {
            try appState.sessionStore?.deleteSession(id: session.id)
            appState.sessions = (try? appState.sessionStore?.fetchSessions()) ?? []
            if selectedSessionId == session.id {
                selectedSessionId = nil
            }
        } catch {
            Log.app.error("Failed to delete session: \(error.localizedDescription)")
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        do {
            let importer = MIDIFileImporter()
            let events = try importer.importFile(at: url)

            let session = Session(
                name: url.deletingPathExtension().lastPathComponent,
                eventCount: events.count
            )
            try appState.sessionStore?.createSession(session)

            // Tokenize and store events
            let encoder = MidiEncoder()
            let tokens = encoder.encode(events)
            let sessionEvents = tokens.enumerated().map { index, token in
                SessionEvent(
                    sessionId: session.id,
                    timestampNs: UInt64(index),
                    tokenId: token.rawValue
                )
            }
            try appState.sessionStore?.appendEvents(sessionEvents)
            appState.sessions = (try? appState.sessionStore?.fetchSessions()) ?? []
        } catch {
            Log.app.error("Failed to import MIDI file: \(error.localizedDescription)")
        }
    }
}

/// A row in the session list.
struct SessionRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.name)
                .font(.body)
                .lineLimit(1)

            HStack(spacing: 12) {
                Label(dateString, systemImage: "calendar")
                if let duration = session.durationSeconds {
                    Label(durationString(duration), systemImage: "clock")
                }
                Label("\(session.eventCount) events", systemImage: "music.note")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.createdAt)
    }

    private func durationString(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
#endif
