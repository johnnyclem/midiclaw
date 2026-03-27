import XCTest
@testable import MidiClawCore

final class MidiEncoderTests: XCTestCase {
    let encoder = MidiEncoder()

    func testEmptyInput() {
        let tokens = encoder.encode([])
        XCTAssertEqual(tokens, [.bos, .eos])
    }

    func testSingleNoteOn() {
        let events = [
            MIDIEvent(timestampNs: 0, message: .noteOn(channel: 0, note: 60, velocity: 100))
        ]
        let tokens = encoder.encode(events)

        // BOS, CHANNEL_0, NOTE_ON_60, VEL_[bucket], EOS
        XCTAssertEqual(tokens.first, .bos)
        XCTAssertEqual(tokens.last, .eos)

        // Should contain NOTE_ON_60
        XCTAssertTrue(tokens.contains(.noteOn(60)))

        // Should contain a velocity token
        let velTokens = tokens.filter { $0.isVelocity }
        XCTAssertEqual(velTokens.count, 1)
        XCTAssertEqual(velTokens[0].velocityBucket, TokenVocabulary.velocityToBucket(100))
    }

    func testNoteOnOff() {
        let events = [
            MIDIEvent(timestampNs: 0, message: .noteOn(channel: 0, note: 60, velocity: 100)),
            MIDIEvent(timestampNs: 500_000_000, message: .noteOff(channel: 0, note: 60, velocity: 0))
        ]
        let tokens = encoder.encode(events)

        XCTAssertTrue(tokens.contains(.noteOn(60)))
        XCTAssertTrue(tokens.contains(.noteOff(60)))

        // Should have a delta token between the two events
        let deltaTokens = tokens.filter { $0.isDelta }
        XCTAssertEqual(deltaTokens.count, 1)
    }

    func testChannelSwitching() {
        let events = [
            MIDIEvent(timestampNs: 0, message: .noteOn(channel: 0, note: 60, velocity: 100)),
            MIDIEvent(timestampNs: 100_000_000, message: .noteOn(channel: 5, note: 64, velocity: 80))
        ]
        let tokens = encoder.encode(events)

        // Should have channel tokens for both channels
        let channelTokens = tokens.filter { $0.channelNumber != nil }
        XCTAssertTrue(channelTokens.count >= 2)
    }

    func testControlChange() {
        let events = [
            MIDIEvent(timestampNs: 0, message: .controlChange(channel: 0, controller: 1, value: 64))
        ]
        let tokens = encoder.encode(events)

        let ccTokens = tokens.filter { $0.isCC }
        XCTAssertEqual(ccTokens.count, 1)
        XCTAssertEqual(ccTokens[0].ccNumber, 1)
    }

    func testCCAbove31Skipped() {
        let events = [
            MIDIEvent(timestampNs: 0, message: .controlChange(channel: 0, controller: 64, value: 127))
        ]
        let tokens = encoder.encode(events)

        // Should only have BOS, possibly channel, and EOS — no CC token
        let ccTokens = tokens.filter { $0.isCC }
        XCTAssertEqual(ccTokens.count, 0)
    }

    func testNonTokenizableMessagesSkipped() {
        let events = [
            MIDIEvent(timestampNs: 0, message: .pitchBend(channel: 0, value: 8192)),
            MIDIEvent(timestampNs: 0, message: .programChange(channel: 0, program: 1)),
        ]
        let tokens = encoder.encode(events)

        // Only BOS and EOS (and maybe channel)
        let meaningful = tokens.filter { !$0.isSpecial }
        XCTAssertEqual(meaningful.count, 0)
    }

    func testDeltaTokenOrdering() {
        // Three events at 0ms, 100ms, 500ms
        let events = [
            MIDIEvent(timestampNs: 0, message: .noteOn(channel: 0, note: 60, velocity: 100)),
            MIDIEvent(timestampNs: 100_000_000, message: .noteOn(channel: 0, note: 64, velocity: 80)),
            MIDIEvent(timestampNs: 500_000_000, message: .noteOff(channel: 0, note: 60, velocity: 0)),
        ]
        let tokens = encoder.encode(events)

        let deltaTokens = tokens.filter { $0.isDelta }
        XCTAssertEqual(deltaTokens.count, 2) // between events 1-2 and 2-3
    }
}
