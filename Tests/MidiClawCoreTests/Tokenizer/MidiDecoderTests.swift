import XCTest
@testable import MidiClawCore

final class MidiDecoderTests: XCTestCase {
    let decoder = MidiDecoder()

    func testEmptyInput() {
        let events = decoder.decode([])
        XCTAssertTrue(events.isEmpty)
    }

    func testBosEosOnly() {
        let events = decoder.decode([.bos, .eos])
        XCTAssertTrue(events.isEmpty)
    }

    func testSingleNoteOn() {
        let tokens: [MidiToken] = [
            .bos,
            .channel(0),
            .noteOn(60),
            .velocity(bucket: 25), // bucket 25 → velocity ~102
            .eos
        ]
        let events = decoder.decode(tokens)
        XCTAssertEqual(events.count, 1)

        if case .noteOn(let ch, let note, let vel) = events[0].message {
            XCTAssertEqual(ch, 0)
            XCTAssertEqual(note, 60)
            XCTAssertEqual(vel, TokenVocabulary.bucketToVelocity(25))
        } else {
            XCTFail("Expected noteOn")
        }
    }

    func testNoteOnWithoutVelocityUsesDefault() {
        let tokens: [MidiToken] = [.noteOn(60), .noteOff(60)]
        let events = decoder.decode(tokens)
        XCTAssertEqual(events.count, 2)

        if case .noteOn(_, _, let vel) = events[0].message {
            XCTAssertEqual(vel, 100) // default velocity
        } else {
            XCTFail("Expected noteOn")
        }
    }

    func testNoteOff() {
        let tokens: [MidiToken] = [.noteOff(60)]
        let events = decoder.decode(tokens)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].message, .noteOff(channel: 0, note: 60, velocity: 0))
    }

    func testDeltaAdvancesTimestamp() {
        let bucket = TokenVocabulary.deltaToBucket(100.0) // ~100ms
        let tokens: [MidiToken] = [
            .noteOn(60), .velocity(bucket: 25),
            .delta(bucket: bucket),
            .noteOff(60),
        ]
        let events = decoder.decode(tokens, baseTimestampNs: 0)
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events[1].timestampNs > events[0].timestampNs)
    }

    func testChannelSwitch() {
        let tokens: [MidiToken] = [
            .channel(0),
            .noteOn(60), .velocity(bucket: 25),
            .channel(5),
            .noteOn(64), .velocity(bucket: 20),
        ]
        let events = decoder.decode(tokens)
        XCTAssertEqual(events.count, 2)

        if case .noteOn(let ch1, _, _) = events[0].message,
           case .noteOn(let ch2, _, _) = events[1].message {
            XCTAssertEqual(ch1, 0)
            XCTAssertEqual(ch2, 5)
        } else {
            XCTFail("Expected two noteOn events")
        }
    }

    func testControlChange() {
        let tokens: [MidiToken] = [
            .controlChange(number: 7, valueBucket: 2)
        ]
        let events = decoder.decode(tokens)
        XCTAssertEqual(events.count, 1)

        if case .controlChange(_, let cc, let val) = events[0].message {
            XCTAssertEqual(cc, 7)
            XCTAssertEqual(val, TokenVocabulary.bucketToCCValue(2))
        } else {
            XCTFail("Expected controlChange")
        }
    }

    func testBaseTimestamp() {
        let tokens: [MidiToken] = [.noteOn(60), .velocity(bucket: 25)]
        let events = decoder.decode(tokens, baseTimestampNs: 5_000_000)
        XCTAssertEqual(events[0].timestampNs, 5_000_000)
    }
}
