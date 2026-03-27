import Foundation

/// Records live MIDI events into a session.
/// Tokenizes events on the fly and batches writes to SQLite.
public final class SessionRecorder: @unchecked Sendable {
    public enum State: Sendable {
        case idle
        case recording
    }

    private let store: SessionStore
    private let encoder = MidiEncoder()
    private let queue = DispatchQueue(label: "com.midiclaw.recorder", qos: .userInitiated)

    private var currentSession: Session?
    private var sessionStartNs: UInt64 = 0
    private var previousTimestampNs: UInt64 = 0
    private var previousChannel: UInt8? = nil
    private var eventBuffer: [SessionEvent] = []
    private var totalEvents: Int = 0

    private static let flushThreshold = 100
    private static let flushIntervalSeconds: TimeInterval = 0.5

    public private(set) var state: State = .idle
    private var flushTimer: DispatchSourceTimer?

    public init(store: SessionStore) {
        self.store = store
    }

    /// Start recording a new session.
    public func startRecording(name: String? = nil) throws -> Session {
        guard state == .idle else {
            throw RecorderError.alreadyRecording
        }

        let sessionName = name ?? Self.defaultSessionName()
        let session = Session(name: sessionName)
        try store.createSession(session)

        currentSession = session
        sessionStartNs = MachTime.nowNanoseconds
        previousTimestampNs = sessionStartNs
        previousChannel = nil
        eventBuffer = []
        totalEvents = 0
        state = .recording

        startFlushTimer()

        return session
    }

    /// Record incoming MIDI events.
    public func record(events: [MIDIEvent]) {
        guard state == .recording, let session = currentSession else { return }

        queue.async { [weak self] in
            guard let self else { return }

            for event in events {
                let (tokens, newTimestamp, newChannel) = self.encoder.encodeStreaming(
                    event: event,
                    previousTimestampNs: self.previousTimestampNs,
                    previousChannel: self.previousChannel
                )
                self.previousTimestampNs = newTimestamp
                self.previousChannel = newChannel

                let relativeNs = event.timestampNs >= self.sessionStartNs
                    ? event.timestampNs - self.sessionStartNs
                    : 0

                for token in tokens {
                    let sessionEvent = SessionEvent(
                        sessionId: session.id,
                        timestampNs: relativeNs,
                        tokenId: token.rawValue,
                        rawMIDIBytes: Data(event.message.rawBytes)
                    )
                    self.eventBuffer.append(sessionEvent)
                }
                self.totalEvents += 1
            }

            if self.eventBuffer.count >= Self.flushThreshold {
                self.flush()
            }
        }
    }

    /// Stop recording and finalize the session.
    public func stopRecording() throws -> Session? {
        guard state == .recording, var session = currentSession else { return nil }

        stopFlushTimer()

        // Flush remaining events synchronously
        queue.sync {
            self.flush()
        }

        let endNs = MachTime.nowNanoseconds
        let durationNs = endNs >= sessionStartNs ? endNs - sessionStartNs : 0
        session.durationSeconds = Double(durationNs) / 1_000_000_000.0
        session.eventCount = totalEvents

        try store.updateSession(session)

        state = .idle
        currentSession = nil
        return session
    }

    // MARK: - Private

    private func flush() {
        guard !eventBuffer.isEmpty else { return }
        let batch = eventBuffer
        eventBuffer = []
        do {
            try store.appendEvents(batch)
        } catch {
            Log.session.error("Failed to flush events: \(error.localizedDescription)")
        }
    }

    private func startFlushTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now() + Self.flushIntervalSeconds,
            repeating: Self.flushIntervalSeconds
        )
        timer.setEventHandler { [weak self] in
            self?.flush()
        }
        timer.resume()
        flushTimer = timer
    }

    private func stopFlushTimer() {
        flushTimer?.cancel()
        flushTimer = nil
    }

    private static func defaultSessionName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "Session \(formatter.string(from: Date()))"
    }

    public enum RecorderError: Error, LocalizedError {
        case alreadyRecording
        case notRecording

        public var errorDescription: String? {
            switch self {
            case .alreadyRecording: return "A recording is already in progress"
            case .notRecording: return "No recording in progress"
            }
        }
    }
}
