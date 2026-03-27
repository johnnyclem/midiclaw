import Foundation

/// Parses Standard MIDI Files (.mid) into MIDIEvent arrays.
/// Supports Format 0 (single track) and Format 1 (multi-track).
/// Pure Swift implementation — no AudioToolbox dependency.
public struct MIDIFileImporter {
    public init() {}

    /// Import a .mid file and return all events sorted by absolute timestamp.
    public func importFile(at url: URL) throws -> [MIDIEvent] {
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }

    /// Parse MIDI file data.
    public func parse(data: Data) throws -> [MIDIEvent] {
        let bytes = [UInt8](data)
        var offset = 0

        // Parse header chunk
        let header = try parseHeaderChunk(bytes: bytes, offset: &offset)

        // Parse track chunks
        var allEvents: [MIDIEvent] = []
        for _ in 0..<header.trackCount {
            let trackEvents = try parseTrackChunk(
                bytes: bytes,
                offset: &offset,
                ticksPerQuarterNote: header.ticksPerQuarterNote
            )
            allEvents.append(contentsOf: trackEvents)
        }

        // Sort by timestamp
        allEvents.sort { $0.timestampNs < $1.timestampNs }
        return allEvents
    }

    // MARK: - Header Chunk

    private struct MIDIFileHeader {
        let format: UInt16      // 0, 1, or 2
        let trackCount: UInt16
        let ticksPerQuarterNote: UInt16
    }

    private func parseHeaderChunk(bytes: [UInt8], offset: inout Int) throws -> MIDIFileHeader {
        guard offset + 14 <= bytes.count else {
            throw MIDIFileError.unexpectedEndOfData
        }

        // "MThd"
        guard bytes[offset] == 0x4D, bytes[offset+1] == 0x54,
              bytes[offset+2] == 0x68, bytes[offset+3] == 0x64 else {
            throw MIDIFileError.invalidHeader
        }
        offset += 4

        // Chunk length (should be 6)
        let length = readUInt32(bytes: bytes, offset: &offset)
        guard length == 6 else {
            throw MIDIFileError.invalidHeader
        }

        let format = readUInt16(bytes: bytes, offset: &offset)
        let trackCount = readUInt16(bytes: bytes, offset: &offset)
        let division = readUInt16(bytes: bytes, offset: &offset)

        // Only support ticks-per-quarter-note timing (bit 15 = 0)
        guard division & 0x8000 == 0 else {
            throw MIDIFileError.unsupportedTimingFormat
        }

        return MIDIFileHeader(
            format: format,
            trackCount: trackCount,
            ticksPerQuarterNote: division
        )
    }

    // MARK: - Track Chunk

    private func parseTrackChunk(
        bytes: [UInt8],
        offset: inout Int,
        ticksPerQuarterNote: UInt16
    ) throws -> [MIDIEvent] {
        guard offset + 8 <= bytes.count else {
            throw MIDIFileError.unexpectedEndOfData
        }

        // "MTrk"
        guard bytes[offset] == 0x4D, bytes[offset+1] == 0x54,
              bytes[offset+2] == 0x72, bytes[offset+3] == 0x6B else {
            throw MIDIFileError.invalidTrackHeader
        }
        offset += 4

        let chunkLength = Int(readUInt32(bytes: bytes, offset: &offset))
        let chunkEnd = offset + chunkLength

        guard chunkEnd <= bytes.count else {
            throw MIDIFileError.unexpectedEndOfData
        }

        var events: [MIDIEvent] = []
        var absoluteTicks: UInt64 = 0
        var runningStatus: UInt8 = 0

        // Default tempo: 120 BPM = 500,000 microseconds per quarter note
        let microsecondsPerTick = 500_000.0 / Double(ticksPerQuarterNote)

        while offset < chunkEnd {
            // Read delta time (variable-length quantity)
            let deltaTicks = readVariableLength(bytes: bytes, offset: &offset)
            absoluteTicks += UInt64(deltaTicks)

            guard offset < chunkEnd else { break }

            let byte = bytes[offset]

            // Meta event
            if byte == 0xFF {
                offset += 1
                guard offset < chunkEnd else { break }
                let metaType = bytes[offset]
                offset += 1
                let metaLength = readVariableLength(bytes: bytes, offset: &offset)
                // Skip meta events (tempo changes could be handled here in future)
                _ = metaType
                offset += Int(metaLength)
                continue
            }

            // SysEx event
            if byte == 0xF0 || byte == 0xF7 {
                offset += 1
                let sysexLength = readVariableLength(bytes: bytes, offset: &offset)
                let sysexEnd = offset + Int(sysexLength)
                if byte == 0xF0 && sysexEnd <= bytes.count {
                    let sysexData = Data(bytes[offset..<sysexEnd])
                    let timestampNs = UInt64(Double(absoluteTicks) * microsecondsPerTick * 1000.0)
                    events.append(MIDIEvent(
                        timestampNs: timestampNs,
                        message: .systemExclusive(data: sysexData)
                    ))
                }
                offset = sysexEnd
                continue
            }

            // Channel message
            var status: UInt8
            if byte >= 0x80 {
                status = byte
                runningStatus = byte
                offset += 1
            } else {
                status = runningStatus
            }

            let channel = status & 0x0F
            let messageType = status & 0xF0
            let timestampNs = UInt64(Double(absoluteTicks) * microsecondsPerTick * 1000.0)

            switch messageType {
            case 0x90:
                guard offset + 1 < chunkEnd else { break }
                let note = bytes[offset] & 0x7F
                let velocity = bytes[offset + 1] & 0x7F
                offset += 2
                if velocity == 0 {
                    events.append(MIDIEvent(timestampNs: timestampNs,
                        message: .noteOff(channel: channel, note: note, velocity: 0)))
                } else {
                    events.append(MIDIEvent(timestampNs: timestampNs,
                        message: .noteOn(channel: channel, note: note, velocity: velocity)))
                }

            case 0x80:
                guard offset + 1 < chunkEnd else { break }
                let note = bytes[offset] & 0x7F
                let velocity = bytes[offset + 1] & 0x7F
                offset += 2
                events.append(MIDIEvent(timestampNs: timestampNs,
                    message: .noteOff(channel: channel, note: note, velocity: velocity)))

            case 0xB0:
                guard offset + 1 < chunkEnd else { break }
                let cc = bytes[offset] & 0x7F
                let val = bytes[offset + 1] & 0x7F
                offset += 2
                events.append(MIDIEvent(timestampNs: timestampNs,
                    message: .controlChange(channel: channel, controller: cc, value: val)))

            case 0xC0:
                guard offset < chunkEnd else { break }
                let program = bytes[offset] & 0x7F
                offset += 1
                events.append(MIDIEvent(timestampNs: timestampNs,
                    message: .programChange(channel: channel, program: program)))

            case 0xE0:
                guard offset + 1 < chunkEnd else { break }
                let lsb = UInt16(bytes[offset] & 0x7F)
                let msb = UInt16(bytes[offset + 1] & 0x7F)
                offset += 2
                events.append(MIDIEvent(timestampNs: timestampNs,
                    message: .pitchBend(channel: channel, value: (msb << 7) | lsb)))

            case 0xD0:
                guard offset < chunkEnd else { break }
                let pressure = bytes[offset] & 0x7F
                offset += 1
                events.append(MIDIEvent(timestampNs: timestampNs,
                    message: .channelPressure(channel: channel, pressure: pressure)))

            case 0xA0:
                guard offset + 1 < chunkEnd else { break }
                let note = bytes[offset] & 0x7F
                let pressure = bytes[offset + 1] & 0x7F
                offset += 2
                events.append(MIDIEvent(timestampNs: timestampNs,
                    message: .polyPressure(channel: channel, note: note, pressure: pressure)))

            default:
                break
            }
        }

        offset = chunkEnd
        return events
    }

    // MARK: - Binary Helpers

    private func readUInt32(bytes: [UInt8], offset: inout Int) -> UInt32 {
        let value = UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset+1]) << 16
            | UInt32(bytes[offset+2]) << 8
            | UInt32(bytes[offset+3])
        offset += 4
        return value
    }

    private func readUInt16(bytes: [UInt8], offset: inout Int) -> UInt16 {
        let value = UInt16(bytes[offset]) << 8 | UInt16(bytes[offset+1])
        offset += 2
        return value
    }

    private func readVariableLength(bytes: [UInt8], offset: inout Int) -> UInt32 {
        var value: UInt32 = 0
        while offset < bytes.count {
            let byte = bytes[offset]
            offset += 1
            value = (value << 7) | UInt32(byte & 0x7F)
            if byte & 0x80 == 0 {
                break
            }
        }
        return value
    }
}

// MARK: - Errors

public enum MIDIFileError: Error, LocalizedError {
    case invalidHeader
    case invalidTrackHeader
    case unexpectedEndOfData
    case unsupportedTimingFormat
    case exportError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHeader: return "Invalid MIDI file header (expected MThd)"
        case .invalidTrackHeader: return "Invalid track header (expected MTrk)"
        case .unexpectedEndOfData: return "Unexpected end of MIDI file data"
        case .unsupportedTimingFormat: return "SMPTE timing not supported (use ticks-per-quarter-note)"
        case .exportError(let msg): return "MIDI export error: \(msg)"
        }
    }
}
