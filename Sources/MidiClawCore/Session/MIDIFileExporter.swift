import Foundation

/// Exports MIDIEvent arrays to Standard MIDI Files (.mid).
/// Produces Format 0 (single track) files.
public struct MIDIFileExporter {
    /// Ticks per quarter note in the output file.
    public let ticksPerQuarterNote: UInt16

    /// Tempo in BPM (used for tick calculation).
    public let tempoBPM: Double

    public init(ticksPerQuarterNote: UInt16 = 480, tempoBPM: Double = 120.0) {
        self.ticksPerQuarterNote = ticksPerQuarterNote
        self.tempoBPM = tempoBPM
    }

    /// Export events to a .mid file at the given URL.
    public func exportFile(events: [MIDIEvent], to url: URL) throws {
        let data = try export(events: events)
        try data.write(to: url, options: .atomic)
    }

    /// Export events to MIDI file data.
    public func export(events: [MIDIEvent]) throws -> Data {
        let sortedEvents = events.sorted { $0.timestampNs < $1.timestampNs }

        var trackData = Data()

        // Write tempo meta event at the start
        let microsecondsPerQuarter = UInt32(60_000_000.0 / tempoBPM)
        trackData.append(0x00) // delta time = 0
        trackData.append(0xFF) // meta event
        trackData.append(0x51) // tempo
        trackData.append(0x03) // length
        trackData.append(UInt8((microsecondsPerQuarter >> 16) & 0xFF))
        trackData.append(UInt8((microsecondsPerQuarter >> 8) & 0xFF))
        trackData.append(UInt8(microsecondsPerQuarter & 0xFF))

        // Convert events to track data
        let nsPerTick = (60_000_000_000.0 / tempoBPM) / Double(ticksPerQuarterNote)
        var previousTick: UInt64 = 0

        for event in sortedEvents {
            let absoluteTick = UInt64(Double(event.timestampNs) / nsPerTick)
            let deltaTick = absoluteTick >= previousTick ? absoluteTick - previousTick : 0
            previousTick = absoluteTick

            // Write delta time as variable-length quantity
            writeVariableLength(UInt32(min(deltaTick, UInt64(UInt32.max))), to: &trackData)

            // Write MIDI message bytes
            let bytes = event.message.rawBytes
            trackData.append(contentsOf: bytes)
        }

        // End of track meta event
        trackData.append(0x00) // delta time
        trackData.append(0xFF)
        trackData.append(0x2F)
        trackData.append(0x00)

        // Build the complete file
        var fileData = Data()

        // Header chunk: MThd
        fileData.append(contentsOf: [0x4D, 0x54, 0x68, 0x64]) // "MThd"
        writeUInt32(6, to: &fileData) // chunk length
        writeUInt16(0, to: &fileData) // format 0
        writeUInt16(1, to: &fileData) // 1 track
        writeUInt16(ticksPerQuarterNote, to: &fileData)

        // Track chunk: MTrk
        fileData.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"
        writeUInt32(UInt32(trackData.count), to: &fileData)
        fileData.append(trackData)

        return fileData
    }

    // MARK: - Binary Helpers

    private func writeUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    private func writeUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    private func writeVariableLength(_ value: UInt32, to data: inout Data) {
        if value == 0 {
            data.append(0x00)
            return
        }

        var val = value
        var bytes: [UInt8] = []

        bytes.append(UInt8(val & 0x7F))
        val >>= 7

        while val > 0 {
            bytes.append(UInt8(val & 0x7F) | 0x80)
            val >>= 7
        }

        // Write in reverse order (MSB first)
        for byte in bytes.reversed() {
            data.append(byte)
        }
    }
}
