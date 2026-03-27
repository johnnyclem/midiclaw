import Foundation

/// Represents a single MIDI message with a precise timestamp.
/// This is the internal currency of MidiClaw — all layers communicate through MIDIEvent.
public struct MIDIEvent: Equatable, Codable, Sendable {
    /// Timestamp in nanoseconds (from mach_absolute_time, converted).
    public let timestampNs: UInt64

    /// The MIDI message type and associated data.
    public let message: MIDIMessage

    public init(timestampNs: UInt64, message: MIDIMessage) {
        self.timestampNs = timestampNs
        self.message = message
    }

    /// Convenience: create with current timestamp.
    public static func now(_ message: MIDIMessage) -> MIDIEvent {
        MIDIEvent(timestampNs: MachTime.nowNanoseconds, message: message)
    }
}

/// Strongly-typed MIDI message representation.
public enum MIDIMessage: Equatable, Codable, Sendable {
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOff(channel: UInt8, note: UInt8, velocity: UInt8)
    case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
    case programChange(channel: UInt8, program: UInt8)
    case pitchBend(channel: UInt8, value: UInt16)
    case channelPressure(channel: UInt8, pressure: UInt8)
    case polyPressure(channel: UInt8, note: UInt8, pressure: UInt8)
    case systemExclusive(data: Data)
    case clock
    case start
    case stop
    case `continue`
    case activeSensing
    case reset

    /// The MIDI channel (0-15) if applicable, nil for system messages.
    public var channel: UInt8? {
        switch self {
        case .noteOn(let ch, _, _),
             .noteOff(let ch, _, _),
             .controlChange(let ch, _, _),
             .programChange(let ch, _),
             .pitchBend(let ch, _),
             .channelPressure(let ch, _),
             .polyPressure(let ch, _, _):
            return ch
        default:
            return nil
        }
    }

    /// Encode this message to raw MIDI bytes.
    public var rawBytes: [UInt8] {
        switch self {
        case .noteOn(let ch, let note, let vel):
            return [0x90 | (ch & 0x0F), note & 0x7F, vel & 0x7F]
        case .noteOff(let ch, let note, let vel):
            return [0x80 | (ch & 0x0F), note & 0x7F, vel & 0x7F]
        case .controlChange(let ch, let cc, let val):
            return [0xB0 | (ch & 0x0F), cc & 0x7F, val & 0x7F]
        case .programChange(let ch, let prog):
            return [0xC0 | (ch & 0x0F), prog & 0x7F]
        case .pitchBend(let ch, let val):
            let lsb = UInt8(val & 0x7F)
            let msb = UInt8((val >> 7) & 0x7F)
            return [0xE0 | (ch & 0x0F), lsb, msb]
        case .channelPressure(let ch, let pressure):
            return [0xD0 | (ch & 0x0F), pressure & 0x7F]
        case .polyPressure(let ch, let note, let pressure):
            return [0xA0 | (ch & 0x0F), note & 0x7F, pressure & 0x7F]
        case .systemExclusive(let data):
            var bytes: [UInt8] = [0xF0]
            bytes.append(contentsOf: data)
            bytes.append(0xF7)
            return bytes
        case .clock: return [0xF8]
        case .start: return [0xFA]
        case .stop: return [0xFC]
        case .continue: return [0xFB]
        case .activeSensing: return [0xFE]
        case .reset: return [0xFF]
        }
    }

    /// Human-readable description of a MIDI note number.
    public static func noteName(_ note: UInt8) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let name = names[Int(note) % 12]
        return "\(name)\(octave)"
    }
}
