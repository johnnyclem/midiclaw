import XCTest
@testable import MidiClawCore

final class MIDIParserTests: XCTestCase {

    func testParseNoteOn() {
        var parser = MIDIParser()
        let events = parser.parse(bytes: [0x90, 60, 100], timestampNs: 0)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].message, .noteOn(channel: 0, note: 60, velocity: 100))
    }

    func testParseNoteOnZeroVelocityBecomesNoteOff() {
        var parser = MIDIParser()
        let events = parser.parse(bytes: [0x90, 60, 0], timestampNs: 0)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].message, .noteOff(channel: 0, note: 60, velocity: 0))
    }

    func testParseNoteOff() {
        var parser = MIDIParser()
        let events = parser.parse(bytes: [0x80, 60, 64], timestampNs: 0)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].message, .noteOff(channel: 0, note: 60, velocity: 64))
    }

    func testParseControlChange() {
        var parser = MIDIParser()
        let events = parser.parse(bytes: [0xB0, 7, 100], timestampNs: 0)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].message, .controlChange(channel: 0, controller: 7, value: 100))
    }

    func testParseProgramChange() {
        var parser = MIDIParser()
        let events = parser.parse(bytes: [0xC0, 42], timestampNs: 0)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].message, .programChange(channel: 0, program: 42))
    }

    func testParsePitchBend() {
        var parser = MIDIParser()
        let events = parser.parse(bytes: [0xE0, 0x00, 0x40], timestampNs: 0)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].message, .pitchBend(channel: 0, value: 8192))
    }

    func testParseMultipleMessages() {
        var parser = MIDIParser()
        let bytes: [UInt8] = [
            0x90, 60, 100,  // Note On C4
            0x90, 64, 90,   // Note On E4
            0x80, 60, 0,    // Note Off C4
        ]
        let events = parser.parse(bytes: bytes, timestampNs: 1000)
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].message, .noteOn(channel: 0, note: 60, velocity: 100))
        XCTAssertEqual(events[1].message, .noteOn(channel: 0, note: 64, velocity: 90))
        XCTAssertEqual(events[2].message, .noteOff(channel: 0, note: 60, velocity: 0))
    }

    func testRunningStatus() {
        var parser = MIDIParser()
        let bytes: [UInt8] = [
            0x90, 60, 100,  // Note On with status byte
            64, 90,          // Note On with running status (no status byte)
        ]
        let events = parser.parse(bytes: bytes, timestampNs: 0)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].message, .noteOn(channel: 0, note: 60, velocity: 100))
        XCTAssertEqual(events[1].message, .noteOn(channel: 0, note: 64, velocity: 90))
    }

    func testParseChannelMessages() {
        var parser = MIDIParser()
        // Note On channel 5
        let events = parser.parse(bytes: [0x95, 60, 100], timestampNs: 0)
        XCTAssertEqual(events[0].message, .noteOn(channel: 5, note: 60, velocity: 100))
    }

    func testParseSystemRealtime() {
        var parser = MIDIParser()
        let events = parser.parse(bytes: [0xF8], timestampNs: 0)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].message, .clock)
    }

    func testParseSystemRealtimeDoesNotAffectRunningStatus() {
        var parser = MIDIParser()
        let bytes: [UInt8] = [
            0x90, 60, 100,  // Note On
            0xF8,            // Clock (system realtime — doesn't clear running status)
            64, 90,          // Running status Note On
        ]
        let events = parser.parse(bytes: bytes, timestampNs: 0)
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].message, .noteOn(channel: 0, note: 60, velocity: 100))
        XCTAssertEqual(events[1].message, .clock)
        XCTAssertEqual(events[2].message, .noteOn(channel: 0, note: 64, velocity: 90))
    }

    func testParseSysEx() {
        var parser = MIDIParser()
        let bytes: [UInt8] = [0xF0, 0x7E, 0x7F, 0x09, 0x01, 0xF7]
        let events = parser.parse(bytes: bytes, timestampNs: 0)
        XCTAssertEqual(events.count, 1)
        if case .systemExclusive(let data) = events[0].message {
            XCTAssertEqual(data, Data([0x7E, 0x7F, 0x09, 0x01]))
        } else {
            XCTFail("Expected SysEx message")
        }
    }

    func testTimestampPreserved() {
        var parser = MIDIParser()
        let events = parser.parse(bytes: [0x90, 60, 100], timestampNs: 42_000_000)
        XCTAssertEqual(events[0].timestampNs, 42_000_000)
    }

    func testEmptyInput() {
        var parser = MIDIParser()
        let events = parser.parse(bytes: [], timestampNs: 0)
        XCTAssertTrue(events.isEmpty)
    }
}
