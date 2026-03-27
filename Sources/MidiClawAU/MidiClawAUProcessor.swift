import Foundation
import MidiClawCore

/// Operating modes for the MidiClaw AudioUnit.
public enum MidiClawAUMode: Int {
    /// Monitor only: observe MIDI, tokenize, but produce no output.
    case monitor = 0
    /// Passthrough: forward all MIDI unmodified (with optional velocity scaling).
    case passthrough = 1
    /// Transform: apply tokenize → decode round-trip (demonstrates token fidelity).
    case transform = 2
}

/// Processes MIDI events using MidiClawCore's tokenizer pipeline.
///
/// Thread-safety: This processor is designed to be called from the AU render thread.
/// Parameter reads use atomic-style access (Float is naturally atomic on ARM64/x86_64).
public final class MidiClawAUProcessor {
    private let encoder = MidiEncoder()
    private let decoder = MidiDecoder()
    private var parser = MIDIParser()

    // Streaming state for the encoder
    private var previousTimestampNs: UInt64 = 0
    private var previousChannel: UInt8? = nil

    /// Most recently generated tokens (for monitoring UI). Ring buffer.
    private let tokenBufferCapacity = 512
    private var _tokenBuffer: [MidiToken] = []
    private let tokenLock = NSLock()

    /// Current parameters (set from main thread, read from render thread).
    public var mode: MidiClawAUMode = .passthrough
    public var channelFilter: Int = 0        // 0 = all, 1–16 = specific
    public var velocityScale: Float = 1.0
    public var tokenMonitorEnabled: Bool = true

    public init() {}

    /// Process raw MIDI bytes and return output MIDI events.
    ///
    /// - Parameters:
    ///   - bytes: Raw MIDI message bytes from the host.
    ///   - timestampNs: Timestamp in nanoseconds.
    /// - Returns: Array of MIDI events to send to output. Empty in monitor mode.
    public func process(bytes: [UInt8], timestampNs: UInt64) -> [MIDIEvent] {
        // Parse raw bytes into structured events
        var events = parser.parse(bytes: bytes, timestampNs: timestampNs)

        // Apply channel filter
        if channelFilter > 0 {
            let targetChannel = UInt8(channelFilter - 1)
            events = events.filter { event in
                guard let ch = event.message.channel else { return true }
                return ch == targetChannel
            }
        }

        guard !events.isEmpty else { return [] }

        // Tokenize for monitoring
        if tokenMonitorEnabled {
            tokenize(events: events)
        }

        switch mode {
        case .monitor:
            return []

        case .passthrough:
            return applyVelocityScale(events)

        case .transform:
            return transformViaTokenizer(events)
        }
    }

    /// Process a single structured MIDIEvent.
    public func process(event: MIDIEvent) -> [MIDIEvent] {
        let bytes = event.message.rawBytes
        return process(bytes: bytes, timestampNs: event.timestampNs)
    }

    /// Get a snapshot of recent tokens (thread-safe).
    public func recentTokens() -> [MidiToken] {
        tokenLock.lock()
        defer { tokenLock.unlock() }
        return _tokenBuffer
    }

    /// Clear token buffer and reset streaming state.
    public func reset() {
        tokenLock.lock()
        _tokenBuffer.removeAll()
        tokenLock.unlock()
        previousTimestampNs = 0
        previousChannel = nil
        parser = MIDIParser()
    }

    // MARK: - Private

    private func tokenize(events: [MIDIEvent]) {
        var newTokens: [MidiToken] = []
        for event in events {
            let result = encoder.encodeStreaming(
                event: event,
                previousTimestampNs: previousTimestampNs,
                previousChannel: previousChannel
            )
            newTokens.append(contentsOf: result.tokens)
            previousTimestampNs = result.newTimestampNs
            previousChannel = result.newChannel
        }

        guard !newTokens.isEmpty else { return }

        tokenLock.lock()
        _tokenBuffer.append(contentsOf: newTokens)
        if _tokenBuffer.count > tokenBufferCapacity {
            _tokenBuffer.removeFirst(_tokenBuffer.count - tokenBufferCapacity)
        }
        tokenLock.unlock()
    }

    private func applyVelocityScale(_ events: [MIDIEvent]) -> [MIDIEvent] {
        guard velocityScale != 1.0 else { return events }

        return events.map { event in
            switch event.message {
            case .noteOn(let ch, let note, let vel):
                let scaled = UInt8(min(127, max(1, Float(vel) * velocityScale)))
                return MIDIEvent(
                    timestampNs: event.timestampNs,
                    message: .noteOn(channel: ch, note: note, velocity: scaled)
                )
            default:
                return event
            }
        }
    }

    private func transformViaTokenizer(_ events: [MIDIEvent]) -> [MIDIEvent] {
        // Encode events to tokens, then decode back to events.
        // This demonstrates the tokenizer's round-trip fidelity.
        let tokens = encoder.encode(events)
        let baseTimestamp = events.first?.timestampNs ?? 0
        var decoded = decoder.decode(tokens, baseTimestampNs: baseTimestamp)

        // Apply velocity scaling to the decoded events too
        decoded = applyVelocityScale(decoded)

        return decoded
    }
}
