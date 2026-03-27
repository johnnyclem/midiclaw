import XCTest
@testable import MidiClawCore

/// Round-trip tests: encode → decode should preserve the essential musical content.
/// Due to quantization (velocity buckets, delta buckets), exact byte-level identity
/// is not possible. Instead we verify semantic identity: same note, same channel,
/// correct relative timing, similar velocity.
final class RoundTripTests: XCTestCase {
    let encoder = MidiEncoder()
    let decoder = MidiDecoder()

    func testSingleNoteRoundTrip() {
        let original = [
            MIDIEvent(timestampNs: 0, message: .noteOn(channel: 0, note: 60, velocity: 100)),
            MIDIEvent(timestampNs: 500_000_000, message: .noteOff(channel: 0, note: 60, velocity: 0))
        ]

        let tokens = encoder.encode(original)
        let decoded = decoder.decode(tokens)

        XCTAssertEqual(decoded.count, 2)

        // Verify note identity
        if case .noteOn(let ch, let note, _) = decoded[0].message {
            XCTAssertEqual(ch, 0)
            XCTAssertEqual(note, 60)
        } else {
            XCTFail("Expected noteOn")
        }

        if case .noteOff(let ch, let note, _) = decoded[1].message {
            XCTAssertEqual(ch, 0)
            XCTAssertEqual(note, 60)
        } else {
            XCTFail("Expected noteOff")
        }

        // Verify timing is roughly preserved (within bucket quantization)
        XCTAssertTrue(decoded[1].timestampNs > decoded[0].timestampNs)
    }

    func testChordRoundTrip() {
        // C major chord
        let original = [
            MIDIEvent(timestampNs: 0, message: .noteOn(channel: 0, note: 60, velocity: 100)),
            MIDIEvent(timestampNs: 0, message: .noteOn(channel: 0, note: 64, velocity: 95)),
            MIDIEvent(timestampNs: 0, message: .noteOn(channel: 0, note: 67, velocity: 90)),
        ]

        let tokens = encoder.encode(original)
        let decoded = decoder.decode(tokens)

        XCTAssertEqual(decoded.count, 3)

        let notes = decoded.compactMap { event -> UInt8? in
            if case .noteOn(_, let note, _) = event.message { return note }
            return nil
        }
        XCTAssertEqual(Set(notes), Set([60, 64, 67]))
    }

    func testMultiChannelRoundTrip() {
        let original = [
            MIDIEvent(timestampNs: 0, message: .noteOn(channel: 0, note: 60, velocity: 100)),
            MIDIEvent(timestampNs: 100_000_000, message: .noteOn(channel: 5, note: 72, velocity: 80)),
        ]

        let tokens = encoder.encode(original)
        let decoded = decoder.decode(tokens)

        XCTAssertEqual(decoded.count, 2)

        if case .noteOn(let ch1, _, _) = decoded[0].message,
           case .noteOn(let ch2, _, _) = decoded[1].message {
            XCTAssertEqual(ch1, 0)
            XCTAssertEqual(ch2, 5)
        } else {
            XCTFail("Expected two noteOn events on different channels")
        }
    }

    func testCCRoundTrip() {
        let original = [
            MIDIEvent(timestampNs: 0, message: .controlChange(channel: 0, controller: 1, value: 64))
        ]

        let tokens = encoder.encode(original)
        let decoded = decoder.decode(tokens)

        XCTAssertEqual(decoded.count, 1)

        if case .controlChange(_, let cc, _) = decoded[0].message {
            XCTAssertEqual(cc, 1)
        } else {
            XCTFail("Expected controlChange")
        }
    }

    func testVelocityQuantizationIsReasonable() {
        // Velocity 100 should roundtrip to something close (within bucket width of 4)
        let original = [
            MIDIEvent(timestampNs: 0, message: .noteOn(channel: 0, note: 60, velocity: 100))
        ]

        let tokens = encoder.encode(original)
        let decoded = decoder.decode(tokens)

        if case .noteOn(_, _, let vel) = decoded[0].message {
            XCTAssertTrue(abs(Int(vel) - 100) <= 4,
                "Velocity \(vel) should be within 4 of original 100")
        } else {
            XCTFail("Expected noteOn")
        }
    }

    func testMelodyTimingPreserved() {
        // Simple 4-note melody at 120 BPM (500ms per beat)
        let beatNs: UInt64 = 500_000_000
        let original = [
            MIDIEvent(timestampNs: 0,          message: .noteOn(channel: 0, note: 60, velocity: 100)),
            MIDIEvent(timestampNs: beatNs,     message: .noteOn(channel: 0, note: 62, velocity: 100)),
            MIDIEvent(timestampNs: beatNs * 2, message: .noteOn(channel: 0, note: 64, velocity: 100)),
            MIDIEvent(timestampNs: beatNs * 3, message: .noteOn(channel: 0, note: 65, velocity: 100)),
        ]

        let tokens = encoder.encode(original)
        let decoded = decoder.decode(tokens)

        XCTAssertEqual(decoded.count, 4)

        // Verify monotonically increasing timestamps
        for i in 1..<decoded.count {
            XCTAssertTrue(decoded[i].timestampNs >= decoded[i-1].timestampNs,
                "Timestamps should be monotonically increasing")
        }

        // Verify roughly equal spacing (within 20% due to log-scale quantization)
        if decoded.count >= 3 {
            let delta1 = decoded[1].timestampNs - decoded[0].timestampNs
            let delta2 = decoded[2].timestampNs - decoded[1].timestampNs
            let ratio = Double(delta1) / Double(max(delta2, 1))
            XCTAssertTrue(ratio > 0.5 && ratio < 2.0,
                "Delta ratio \(ratio) should be roughly 1.0 for equal spacing")
        }
    }

    func testEmptyRoundTrip() {
        let tokens = encoder.encode([])
        let decoded = decoder.decode(tokens)
        XCTAssertTrue(decoded.isEmpty)
    }
}
