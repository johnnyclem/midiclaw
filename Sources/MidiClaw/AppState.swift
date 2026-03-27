import Foundation
import MidiClawCore
#if os(macOS)
import SwiftUI

/// The three agent operating modes.
public enum AgentMode: String, CaseIterable, Identifiable {
    case monitor = "Monitor"
    case copilot = "Copilot"
    case autonomous = "Autonomous"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .monitor: return "Observe and annotate MIDI stream"
        case .copilot: return "Suggest transformations with approval"
        case .autonomous: return "Closed-loop generation and response"
        }
    }

    public var icon: String {
        switch self {
        case .monitor: return "eye"
        case .copilot: return "person.2"
        case .autonomous: return "bolt"
        }
    }
}

/// Global application state, observable by all views.
@MainActor
public final class AppState: ObservableObject {
    // MARK: - Mode
    @Published public var currentMode: AgentMode = .monitor

    // MARK: - MIDI State
    @Published public var isConnected = false
    @Published public var availableSources: [MIDIEndpointInfo] = []
    @Published public var availableDestinations: [MIDIEndpointInfo] = []
    @Published public var recentEvents: [MIDIEvent] = []
    @Published public var recentTokens: [MidiToken] = []

    // MARK: - Recording State
    @Published public var isRecording = false
    @Published public var currentSession: Session? = nil
    @Published public var sessions: [Session] = []

    // MARK: - Services
    public let midiManager = MIDIManager()
    public let hardwareScanner = MIDIHardwareScanner()
    public var portManager: MIDIPortManager?
    public var sessionStore: SessionStore?
    public var recorder: SessionRecorder?
    public var player: SessionPlayer?

    // MARK: - Token Encoder
    private let encoder = MidiEncoder()
    private var previousTimestampNs: UInt64 = 0
    private var previousChannel: UInt8? = nil

    /// Maximum events to keep in the live display buffer.
    private static let maxRecentEvents = 200
    private static let maxRecentTokens = 500

    public init() {}

    /// Initialize all services and start MIDI.
    public func setup() {
        do {
            // Session store
            let store = try SessionStore()
            sessionStore = store
            recorder = SessionRecorder(store: store)
            player = SessionPlayer(store: store)
            sessions = (try? store.fetchSessions()) ?? []

            // MIDI
            try midiManager.start { [weak self] in
                Task { @MainActor in
                    self?.refreshMIDIPorts()
                }
            }

            let ports = MIDIPortManager(manager: midiManager)
            try ports.createVirtualPorts()
            ports.onEventsReceived = { [weak self] events in
                Task { @MainActor in
                    self?.handleIncomingEvents(events)
                }
            }
            portManager = ports
            isConnected = true

            refreshMIDIPorts()
        } catch {
            Log.app.error("Setup failed: \(error.localizedDescription)")
        }
    }

    /// Refresh the list of available MIDI ports.
    public func refreshMIDIPorts() {
        hardwareScanner.scan()
        availableSources = hardwareScanner.sources
        availableDestinations = hardwareScanner.destinations
    }

    /// Handle incoming MIDI events from any source.
    public func handleIncomingEvents(_ events: [MIDIEvent]) {
        // Add to recent events buffer
        recentEvents.append(contentsOf: events)
        if recentEvents.count > Self.maxRecentEvents {
            recentEvents.removeFirst(recentEvents.count - Self.maxRecentEvents)
        }

        // Tokenize for display
        for event in events {
            let (tokens, newTs, newCh) = encoder.encodeStreaming(
                event: event,
                previousTimestampNs: previousTimestampNs,
                previousChannel: previousChannel
            )
            previousTimestampNs = newTs
            previousChannel = newCh
            recentTokens.append(contentsOf: tokens)
        }
        if recentTokens.count > Self.maxRecentTokens {
            recentTokens.removeFirst(recentTokens.count - Self.maxRecentTokens)
        }

        // Forward to recorder if recording
        if isRecording {
            recorder?.record(events: events)
        }
    }

    // MARK: - Recording Controls

    public func startRecording() {
        guard !isRecording else { return }
        do {
            let session = try recorder?.startRecording()
            currentSession = session
            isRecording = true
        } catch {
            Log.app.error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    public func stopRecording() {
        guard isRecording else { return }
        do {
            let session = try recorder?.stopRecording()
            currentSession = nil
            isRecording = false
            if session != nil {
                sessions = (try? sessionStore?.fetchSessions()) ?? sessions
            }
        } catch {
            Log.app.error("Failed to stop recording: \(error.localizedDescription)")
        }
    }

    /// Clean up all resources.
    public func teardown() {
        if isRecording {
            stopRecording()
        }
        player?.stop()
        portManager?.dispose()
        midiManager.stop()
    }
}
#else
// Non-macOS stub
public enum AgentMode: String, CaseIterable {
    case monitor = "Monitor"
    case copilot = "Copilot"
    case autonomous = "Autonomous"
}

public final class AppState {
    public var currentMode: AgentMode = .monitor
    public init() {}
    public func setup() {}
    public func teardown() {}
}
#endif
