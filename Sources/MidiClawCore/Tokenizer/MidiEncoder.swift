import Foundation

/// Encodes a sequence of MIDIEvents into MidiTokens.
/// Deterministic and stateless per invocation.
///
/// Encoding scheme for each event:
/// 1. DELTA token (time since previous event)
/// 2. CHANNEL token (if channel changes from previous event)
/// 3. Event-specific tokens:
///    - Note On:  NOTE_ON_[note] + VEL_[bucket]
///    - Note Off: NOTE_OFF_[note]
///    - CC 0-31:  CC_[num]_[bucket]
public struct MidiEncoder {
    public init() {}

    /// Encode an array of MIDIEvents (must be sorted by timestamp) into MidiTokens.
    /// Wraps the sequence with BOS and EOS tokens.
    public func encode(_ events: [MIDIEvent]) -> [MidiToken] {
        guard !events.isEmpty else { return [.bos, .eos] }

        var tokens: [MidiToken] = [.bos]
        var previousTimestampNs: UInt64 = events[0].timestampNs
        var previousChannel: UInt8? = nil

        for (index, event) in events.enumerated() {
            // Emit delta token (skip for the first event — delta is 0)
            if index > 0 {
                let deltaNs = event.timestampNs >= previousTimestampNs
                    ? event.timestampNs - previousTimestampNs
                    : 0
                let deltaMs = MachTime.nanosecondsToMilliseconds(deltaNs)
                if deltaMs > 0 {
                    let bucket = TokenVocabulary.deltaToBucket(deltaMs)
                    tokens.append(.delta(bucket: bucket))
                }
            }
            previousTimestampNs = event.timestampNs

            // Emit channel token if channel changes
            if let channel = event.message.channel, channel != previousChannel {
                tokens.append(.channel(channel))
                previousChannel = channel
            }

            // Emit event-specific tokens
            switch event.message {
            case .noteOn(_, let note, let velocity):
                tokens.append(.noteOn(note))
                let velBucket = TokenVocabulary.velocityToBucket(velocity)
                tokens.append(.velocity(bucket: velBucket))

            case .noteOff(_, let note, _):
                tokens.append(.noteOff(note))

            case .controlChange(_, let controller, let value):
                // Only CC 0-31 are in the vocabulary
                if controller < 32 {
                    let valBucket = TokenVocabulary.ccValueToBucket(value)
                    tokens.append(.controlChange(number: Int(controller), valueBucket: valBucket))
                }
                // CC > 31 silently dropped in v1

            default:
                // Other message types (program change, pitch bend, sysex, etc.)
                // are not in the v1 vocabulary — silently skip
                break
            }
        }

        tokens.append(.eos)
        return tokens
    }

    /// Encode a single event relative to a reference timestamp and channel.
    /// Returns tokens without BOS/EOS wrappers (for streaming use).
    public func encodeStreaming(
        event: MIDIEvent,
        previousTimestampNs: UInt64,
        previousChannel: UInt8?
    ) -> (tokens: [MidiToken], newTimestampNs: UInt64, newChannel: UInt8?) {
        var tokens: [MidiToken] = []
        var channel = previousChannel

        // Delta
        let deltaNs = event.timestampNs >= previousTimestampNs
            ? event.timestampNs - previousTimestampNs
            : 0
        let deltaMs = MachTime.nanosecondsToMilliseconds(deltaNs)
        if deltaMs > 0 {
            let bucket = TokenVocabulary.deltaToBucket(deltaMs)
            tokens.append(.delta(bucket: bucket))
        }

        // Channel
        if let ch = event.message.channel, ch != previousChannel {
            tokens.append(.channel(ch))
            channel = ch
        }

        // Event tokens
        switch event.message {
        case .noteOn(_, let note, let velocity):
            tokens.append(.noteOn(note))
            tokens.append(.velocity(bucket: TokenVocabulary.velocityToBucket(velocity)))
        case .noteOff(_, let note, _):
            tokens.append(.noteOff(note))
        case .controlChange(_, let controller, let value):
            if controller < 32 {
                tokens.append(.controlChange(
                    number: Int(controller),
                    valueBucket: TokenVocabulary.ccValueToBucket(value)
                ))
            }
        default:
            break
        }

        return (tokens, event.timestampNs, channel)
    }
}
