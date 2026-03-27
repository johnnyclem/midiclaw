import XCTest
@testable import MidiClawAU
@testable import MidiClawCore

final class MidiClawAUProcessorTests: XCTestCase {

    // MARK: - Monitor Mode

    func testMonitorModeProducesNoOutput() {
        let processor = MidiClawAUProcessor()
        processor.mode = .monitor

        let noteOnBytes: [UInt8] = [0x90, 60, 100] // Note On, C4, vel 100
        let output = processor.process(bytes: noteOnBytes, timestampNs: 1_000_000)

        XCTAssertTrue(output.isEmpty, "Monitor mode should produce no MIDI output")
    }

    func testMonitorModeStillTokenizes() {
        let processor = MidiClawAUProcessor()
        processor.mode = .monitor
        processor.tokenMonitorEnabled = true

        let noteOnBytes: [UInt8] = [0x90, 60, 100]
        _ = processor.process(bytes: noteOnBytes, timestampNs: 1_000_000)

        let tokens = processor.recentTokens()
        XCTAssertFalse(tokens.isEmpty, "Monitor mode should still tokenize events")
        XCTAssertTrue(tokens.contains(where: { $0.isNoteOn }), "Should contain a NOTE_ON token")
    }

    // MARK: - Passthrough Mode

    func testPassthroughForwardsEvents() {
        let processor = MidiClawAUProcessor()
        processor.mode = .passthrough

        let noteOnBytes: [UInt8] = [0x90, 60, 100]
        let output = processor.process(bytes: noteOnBytes, timestampNs: 1_000_000)

        XCTAssertEqual(output.count, 1)
        if case .noteOn(_, let note, let vel) = output[0].message {
            XCTAssertEqual(note, 60)
            XCTAssertEqual(vel, 100)
        } else {
            XCTFail("Expected noteOn message")
        }
    }

    func testPassthroughWithVelocityScaling() {
        let processor = MidiClawAUProcessor()
        processor.mode = .passthrough
        processor.velocityScale = 0.5

        let noteOnBytes: [UInt8] = [0x90, 60, 100]
        let output = processor.process(bytes: noteOnBytes, timestampNs: 1_000_000)

        XCTAssertEqual(output.count, 1)
        if case .noteOn(_, _, let vel) = output[0].message {
            XCTAssertEqual(vel, 50, "Velocity should be scaled to 50%")
        } else {
            XCTFail("Expected noteOn message")
        }
    }

    func testVelocityScaleClampsAt127() {
        let processor = MidiClawAUProcessor()
        processor.mode = .passthrough
        processor.velocityScale = 2.0

        let noteOnBytes: [UInt8] = [0x90, 60, 100]
        let output = processor.process(bytes: noteOnBytes, timestampNs: 1_000_000)

        XCTAssertEqual(output.count, 1)
        if case .noteOn(_, _, let vel) = output[0].message {
            XCTAssertEqual(vel, 127, "Velocity should clamp at 127")
        } else {
            XCTFail("Expected noteOn message")
        }
    }

    func testVelocityScaleDoesNotAffectNoteOff() {
        let processor = MidiClawAUProcessor()
        processor.mode = .passthrough
        processor.velocityScale = 2.0

        let noteOffBytes: [UInt8] = [0x80, 60, 64]
        let output = processor.process(bytes: noteOffBytes, timestampNs: 1_000_000)

        XCTAssertEqual(output.count, 1)
        if case .noteOff(_, let note, let vel) = output[0].message {
            XCTAssertEqual(note, 60)
            XCTAssertEqual(vel, 64, "Note off velocity should not be scaled")
        } else {
            XCTFail("Expected noteOff message")
        }
    }

    // MARK: - Transform Mode

    func testTransformModeRoundTrips() {
        let processor = MidiClawAUProcessor()
        processor.mode = .transform

        let noteOnBytes: [UInt8] = [0x90, 60, 100]
        let output = processor.process(bytes: noteOnBytes, timestampNs: 1_000_000)

        // Transform mode encodes → decodes. Note should survive round-trip.
        XCTAssertFalse(output.isEmpty, "Transform mode should produce output")
        let hasNoteOn = output.contains { event in
            if case .noteOn(_, let note, _) = event.message {
                return note == 60
            }
            return false
        }
        XCTAssertTrue(hasNoteOn, "Round-tripped note should preserve note number")
    }

    // MARK: - Channel Filter

    func testChannelFilterPassesMatchingChannel() {
        let processor = MidiClawAUProcessor()
        processor.mode = .passthrough
        processor.channelFilter = 1 // Channel 1 = MIDI channel 0

        let noteOnCh0: [UInt8] = [0x90, 60, 100] // Channel 0
        let output = processor.process(bytes: noteOnCh0, timestampNs: 1_000_000)

        XCTAssertEqual(output.count, 1, "Should pass events on matching channel")
    }

    func testChannelFilterBlocksNonMatchingChannel() {
        let processor = MidiClawAUProcessor()
        processor.mode = .passthrough
        processor.channelFilter = 2 // Channel 2 = MIDI channel 1

        let noteOnCh0: [UInt8] = [0x90, 60, 100] // Channel 0
        let output = processor.process(bytes: noteOnCh0, timestampNs: 1_000_000)

        XCTAssertTrue(output.isEmpty, "Should block events on non-matching channel")
    }

    func testChannelFilterAllPassesEverything() {
        let processor = MidiClawAUProcessor()
        processor.mode = .passthrough
        processor.channelFilter = 0 // All channels

        let noteOnCh5: [UInt8] = [0x95, 60, 100] // Channel 5
        let output = processor.process(bytes: noteOnCh5, timestampNs: 1_000_000)

        XCTAssertEqual(output.count, 1, "Channel filter 'All' should pass everything")
    }

    // MARK: - Token Monitor

    func testTokenMonitorDisabledSkipsTokenization() {
        let processor = MidiClawAUProcessor()
        processor.mode = .passthrough
        processor.tokenMonitorEnabled = false

        let noteOnBytes: [UInt8] = [0x90, 60, 100]
        _ = processor.process(bytes: noteOnBytes, timestampNs: 1_000_000)

        let tokens = processor.recentTokens()
        XCTAssertTrue(tokens.isEmpty, "Token monitor disabled should not tokenize")
    }

    // MARK: - Reset

    func testResetClearsTokenBuffer() {
        let processor = MidiClawAUProcessor()
        processor.mode = .passthrough

        let noteOnBytes: [UInt8] = [0x90, 60, 100]
        _ = processor.process(bytes: noteOnBytes, timestampNs: 1_000_000)
        XCTAssertFalse(processor.recentTokens().isEmpty)

        processor.reset()
        XCTAssertTrue(processor.recentTokens().isEmpty, "Reset should clear token buffer")
    }

    // MARK: - Multiple Events

    func testMultipleEventsInSingleBuffer() {
        let processor = MidiClawAUProcessor()
        processor.mode = .passthrough

        // Two note-on events in one buffer
        let bytes: [UInt8] = [0x90, 60, 100, 0x90, 64, 80]
        let output = processor.process(bytes: bytes, timestampNs: 1_000_000)

        XCTAssertEqual(output.count, 2, "Should parse and output both events")
    }

    func testControlChangePassthrough() {
        let processor = MidiClawAUProcessor()
        processor.mode = .passthrough

        let ccBytes: [UInt8] = [0xB0, 1, 64] // CC#1 (mod wheel), value 64
        let output = processor.process(bytes: ccBytes, timestampNs: 1_000_000)

        XCTAssertEqual(output.count, 1)
        if case .controlChange(_, let cc, let val) = output[0].message {
            XCTAssertEqual(cc, 1)
            XCTAssertEqual(val, 64)
        } else {
            XCTFail("Expected controlChange message")
        }
    }
}
