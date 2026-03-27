import Foundation

/// Parses raw MIDI byte streams into MIDIEvent arrays.
/// Handles running status, multi-byte messages, and system messages.
public struct MIDIParser {
    private var runningStatus: UInt8 = 0

    public init() {}

    /// Parse a buffer of raw MIDI bytes into events.
    /// All events share the same timestamp (caller provides it from CoreMIDI packet).
    public mutating func parse(bytes: [UInt8], timestampNs: UInt64) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        var i = 0

        while i < bytes.count {
            let byte = bytes[i]

            // System real-time messages (single byte, don't affect running status)
            if byte >= 0xF8 {
                if let msg = parseSystemRealtime(byte) {
                    events.append(MIDIEvent(timestampNs: timestampNs, message: msg))
                }
                i += 1
                continue
            }

            // System common messages (cancel running status)
            if byte >= 0xF0 && byte < 0xF8 {
                if byte == 0xF0 {
                    // SysEx: read until 0xF7
                    let startIndex = i + 1
                    i += 1
                    while i < bytes.count && bytes[i] != 0xF7 {
                        i += 1
                    }
                    let sysexData = Data(bytes[startIndex..<i])
                    events.append(MIDIEvent(
                        timestampNs: timestampNs,
                        message: .systemExclusive(data: sysexData)
                    ))
                    if i < bytes.count { i += 1 } // skip 0xF7
                } else {
                    // Other system common messages — skip for v1
                    runningStatus = 0
                    i += 1
                    // Skip data bytes
                    switch byte {
                    case 0xF1, 0xF3: i += 1 // 1 data byte
                    case 0xF2: i += 2        // 2 data bytes
                    default: break           // 0xF4, 0xF5, 0xF6, 0xF7: no data
                    }
                }
                continue
            }

            // Status byte for channel messages
            var status: UInt8
            if byte >= 0x80 {
                status = byte
                runningStatus = byte
                i += 1
            } else {
                // Data byte: use running status
                guard runningStatus != 0 else {
                    i += 1
                    continue
                }
                status = runningStatus
            }

            let channel = status & 0x0F
            let messageType = status & 0xF0

            guard let msg = parseChannelMessage(
                messageType: messageType,
                channel: channel,
                bytes: bytes,
                index: &i
            ) else {
                continue
            }

            events.append(MIDIEvent(timestampNs: timestampNs, message: msg))
        }

        return events
    }

    private func parseSystemRealtime(_ byte: UInt8) -> MIDIMessage? {
        switch byte {
        case 0xF8: return .clock
        case 0xFA: return .start
        case 0xFB: return .continue
        case 0xFC: return .stop
        case 0xFE: return .activeSensing
        case 0xFF: return .reset
        default: return nil
        }
    }

    private func parseChannelMessage(
        messageType: UInt8,
        channel: UInt8,
        bytes: [UInt8],
        index: inout Int
    ) -> MIDIMessage? {
        switch messageType {
        case 0x90: // Note On
            guard index + 1 < bytes.count else { return nil }
            let note = bytes[index] & 0x7F
            let velocity = bytes[index + 1] & 0x7F
            index += 2
            // Note On with velocity 0 is treated as Note Off
            if velocity == 0 {
                return .noteOff(channel: channel, note: note, velocity: 0)
            }
            return .noteOn(channel: channel, note: note, velocity: velocity)

        case 0x80: // Note Off
            guard index + 1 < bytes.count else { return nil }
            let note = bytes[index] & 0x7F
            let velocity = bytes[index + 1] & 0x7F
            index += 2
            return .noteOff(channel: channel, note: note, velocity: velocity)

        case 0xB0: // Control Change
            guard index + 1 < bytes.count else { return nil }
            let controller = bytes[index] & 0x7F
            let value = bytes[index + 1] & 0x7F
            index += 2
            return .controlChange(channel: channel, controller: controller, value: value)

        case 0xC0: // Program Change
            guard index < bytes.count else { return nil }
            let program = bytes[index] & 0x7F
            index += 1
            return .programChange(channel: channel, program: program)

        case 0xE0: // Pitch Bend
            guard index + 1 < bytes.count else { return nil }
            let lsb = UInt16(bytes[index] & 0x7F)
            let msb = UInt16(bytes[index + 1] & 0x7F)
            index += 2
            return .pitchBend(channel: channel, value: (msb << 7) | lsb)

        case 0xD0: // Channel Pressure
            guard index < bytes.count else { return nil }
            let pressure = bytes[index] & 0x7F
            index += 1
            return .channelPressure(channel: channel, pressure: pressure)

        case 0xA0: // Poly Pressure
            guard index + 1 < bytes.count else { return nil }
            let note = bytes[index] & 0x7F
            let pressure = bytes[index + 1] & 0x7F
            index += 2
            return .polyPressure(channel: channel, note: note, pressure: pressure)

        default:
            return nil
        }
    }
}
