import XCTest
@testable import MidiClawCore

final class MIDIEventTests: XCTestCase {

    // MARK: - Raw Bytes Encoding

    func testNoteOnRawBytes() {
        let msg = MIDIMessage.noteOn(channel: 0, note: 60, velocity: 100)
        XCTAssertEqual(msg.rawBytes, [0x90, 60, 100])
    }

    func testNoteOnChannel5RawBytes() {
        let msg = MIDIMessage.noteOn(channel: 5, note: 72, velocity: 80)
        XCTAssertEqual(msg.rawBytes, [0x95, 72, 80])
    }

    func testNoteOffRawBytes() {
        let msg = MIDIMessage.noteOff(channel: 0, note: 60, velocity: 0)
        XCTAssertEqual(msg.rawBytes, [0x80, 60, 0])
    }

    func testControlChangeRawBytes() {
        let msg = MIDIMessage.controlChange(channel: 0, controller: 7, value: 100)
        XCTAssertEqual(msg.rawBytes, [0xB0, 7, 100])
    }

    func testProgramChangeRawBytes() {
        let msg = MIDIMessage.programChange(channel: 3, program: 42)
        XCTAssertEqual(msg.rawBytes, [0xC3, 42])
    }

    func testPitchBendRawBytes() {
        // Center value = 8192 (0x2000)
        let msg = MIDIMessage.pitchBend(channel: 0, value: 8192)
        let lsb = UInt8(8192 & 0x7F)       // 0
        let msb = UInt8((8192 >> 7) & 0x7F) // 64
        XCTAssertEqual(msg.rawBytes, [0xE0, lsb, msb])
    }

    func testChannelPressureRawBytes() {
        let msg = MIDIMessage.channelPressure(channel: 2, pressure: 50)
        XCTAssertEqual(msg.rawBytes, [0xD2, 50])
    }

    func testSystemMessages() {
        XCTAssertEqual(MIDIMessage.clock.rawBytes, [0xF8])
        XCTAssertEqual(MIDIMessage.start.rawBytes, [0xFA])
        XCTAssertEqual(MIDIMessage.stop.rawBytes, [0xFC])
        XCTAssertEqual(MIDIMessage.continue.rawBytes, [0xFB])
    }

    // MARK: - Channel Extraction

    func testChannelExtraction() {
        XCTAssertEqual(MIDIMessage.noteOn(channel: 5, note: 60, velocity: 100).channel, 5)
        XCTAssertEqual(MIDIMessage.controlChange(channel: 15, controller: 1, value: 0).channel, 15)
        XCTAssertNil(MIDIMessage.clock.channel)
        XCTAssertNil(MIDIMessage.systemExclusive(data: Data()).channel)
    }

    // MARK: - Note Name

    func testNoteNames() {
        XCTAssertEqual(MIDIMessage.noteName(60), "C4")
        XCTAssertEqual(MIDIMessage.noteName(69), "A4")
        XCTAssertEqual(MIDIMessage.noteName(0), "C-1")
        XCTAssertEqual(MIDIMessage.noteName(127), "G9")
        XCTAssertEqual(MIDIMessage.noteName(61), "C#4")
    }

    // MARK: - Equality

    func testEquality() {
        let a = MIDIMessage.noteOn(channel: 0, note: 60, velocity: 100)
        let b = MIDIMessage.noteOn(channel: 0, note: 60, velocity: 100)
        let c = MIDIMessage.noteOn(channel: 0, note: 60, velocity: 99)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Event

    func testEventCreation() {
        let event = MIDIEvent(
            timestampNs: 1_000_000,
            message: .noteOn(channel: 0, note: 60, velocity: 100)
        )
        XCTAssertEqual(event.timestampNs, 1_000_000)
        XCTAssertEqual(event.message, .noteOn(channel: 0, note: 60, velocity: 100))
    }
}
