import Foundation

/// Replays a recorded session with original timing.
/// Decodes stored tokens back to MIDIEvents and sends them to the output callback.
public final class SessionPlayer: @unchecked Sendable {
    public enum State: Sendable {
        case idle
        case playing
        case paused
    }

    private let store: SessionStore
    private let decoder = MidiDecoder()
    private let queue = DispatchQueue(label: "com.midiclaw.player", qos: .userInitiated)

    /// Called when events should be sent to MIDI output.
    public var onEventsOutput: (([MIDIEvent]) -> Void)?

    /// Called when playback completes.
    public var onPlaybackComplete: (() -> Void)?

    public private(set) var state: State = .idle
    private var playbackWorkItem: DispatchWorkItem?

    public init(store: SessionStore) {
        self.store = store
    }

    /// Start playing a session from the beginning.
    public func play(sessionId: UUID) throws {
        guard state == .idle else { return }

        let sessionEvents = try store.fetchEvents(forSession: sessionId)
        guard !sessionEvents.isEmpty else { return }

        state = .playing

        // Group events by timestamp and reconstruct MIDIEvents
        let tokens = sessionEvents.map { MidiToken(rawValue: $0.rawValue) }
        let events = decoder.decode(tokens)

        guard !events.isEmpty else {
            state = .idle
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            let baseTimestamp = events[0].timestampNs
            var lastOutputTime = DispatchTime.now()

            for event in events {
                guard self.state == .playing else { break }

                let relativeNs = event.timestampNs >= baseTimestamp
                    ? event.timestampNs - baseTimestamp
                    : 0

                if relativeNs > 0 {
                    let targetTime = lastOutputTime + .nanoseconds(Int(relativeNs))
                    let waitNs = targetTime.uptimeNanoseconds - DispatchTime.now().uptimeNanoseconds
                    if waitNs > 0 {
                        Thread.sleep(forTimeInterval: Double(waitNs) / 1_000_000_000.0)
                    }
                }

                lastOutputTime = DispatchTime.now()
                self.onEventsOutput?([event])
            }

            DispatchQueue.main.async {
                self.state = .idle
                self.onPlaybackComplete?()
            }
        }

        playbackWorkItem = workItem
        queue.async(execute: workItem)
    }

    /// Pause playback.
    public func pause() {
        guard state == .playing else { return }
        state = .paused
    }

    /// Stop playback.
    public func stop() {
        state = .idle
        playbackWorkItem?.cancel()
        playbackWorkItem = nil
    }
}

// MARK: - Helpers

private extension SessionEvent {
    /// Convenience to get the raw token value.
    var rawValue: UInt16 { tokenId }
}
