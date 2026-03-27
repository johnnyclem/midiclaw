import XCTest
@testable import MidiClawCore

final class MIDIFileRoundTripTests: XCTestCase {
    let importer = MIDIFileImporter()
    let exporter = MIDIFileExporter(ticksPerQuarterNote: 480, tempoBPM: 120.0)

    func testExportAndReimport() throws {
        let original = [
            MIDIEvent(timestampNs: 0,
                      message: .noteOn(channel: 0, note: 60, velocity: 100)),
            MIDIEvent(timestampNs: 500_000_000,
                      message: .noteOff(channel: 0, note: 60, velocity: 0)),
            MIDIEvent(timestampNs: 500_000_000,
                      message: .noteOn(channel: 0, note: 64, velocity: 90)),
            MIDIEvent(timestampNs: 1_000_000_000,
                      message: .noteOff(channel: 0, note: 64, velocity: 0)),
        ]

        let data = try exporter.export(events: original)
        let reimported = try importer.parse(data: data)

        // Same number of events
        XCTAssertEqual(reimported.count, original.count)

        // Same notes in same order
        for (orig, reimp) in zip(original, reimported) {
            switch (orig.message, reimp.message) {
            case (.noteOn(let ch1, let n1, let v1), .noteOn(let ch2, let n2, let v2)):
                XCTAssertEqual(ch1, ch2)
                XCTAssertEqual(n1, n2)
                XCTAssertEqual(v1, v2)
            case (.noteOff(let ch1, let n1, _), .noteOff(let ch2, let n2, _)):
                XCTAssertEqual(ch1, ch2)
                XCTAssertEqual(n1, n2)
            default:
                XCTFail("Message type mismatch: \(orig.message) vs \(reimp.message)")
            }
        }

        // Timestamps should be monotonically increasing
        for i in 1..<reimported.count {
            XCTAssertTrue(reimported[i].timestampNs >= reimported[i-1].timestampNs)
        }
    }

    func testExportControlChange() throws {
        let events = [
            MIDIEvent(timestampNs: 0,
                      message: .controlChange(channel: 0, controller: 7, value: 100)),
            MIDIEvent(timestampNs: 250_000_000,
                      message: .controlChange(channel: 0, controller: 7, value: 64)),
        ]

        let data = try exporter.export(events: events)
        let reimported = try importer.parse(data: data)

        XCTAssertEqual(reimported.count, 2)
        if case .controlChange(_, let cc1, let v1) = reimported[0].message {
            XCTAssertEqual(cc1, 7)
            XCTAssertEqual(v1, 100)
        } else {
            XCTFail("Expected CC event")
        }
    }

    func testEmptyExport() throws {
        let data = try exporter.export(events: [])
        let reimported = try importer.parse(data: data)
        XCTAssertTrue(reimported.isEmpty)
    }

    func testHeaderParsing() throws {
        let events = [
            MIDIEvent(timestampNs: 0, message: .noteOn(channel: 0, note: 60, velocity: 100))
        ]
        let data = try exporter.export(events: events)

        // Verify MThd header
        XCTAssertEqual(data[0], 0x4D) // M
        XCTAssertEqual(data[1], 0x54) // T
        XCTAssertEqual(data[2], 0x68) // h
        XCTAssertEqual(data[3], 0x64) // d
    }

    func testInvalidHeaderThrows() {
        let badData = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertThrowsError(try importer.parse(data: badData)) { error in
            XCTAssertTrue(error is MIDIFileError)
        }
    }

    func testFileWriteAndRead() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let filePath = tempDir.appendingPathComponent("test_\(UUID().uuidString).mid")
        defer { try? FileManager.default.removeItem(at: filePath) }

        let events = [
            MIDIEvent(timestampNs: 0, message: .noteOn(channel: 0, note: 60, velocity: 100)),
            MIDIEvent(timestampNs: 500_000_000, message: .noteOff(channel: 0, note: 60, velocity: 0)),
        ]

        try exporter.exportFile(events: events, to: filePath)
        let reimported = try importer.importFile(at: filePath)

        XCTAssertEqual(reimported.count, 2)
    }
}
