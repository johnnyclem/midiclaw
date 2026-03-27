import XCTest
@testable import MidiClawCore

final class MidiTokenTests: XCTestCase {

    // MARK: - Token Range Validation

    func testNoteOnRange() {
        for note in 0...127 {
            let token = MidiToken.noteOn(UInt8(note))
            XCTAssertTrue(token.isNoteOn, "Token \(token) should be noteOn")
            XCTAssertEqual(token.noteNumber, UInt8(note))
            XCTAssertFalse(token.isNoteOff)
            XCTAssertFalse(token.isVelocity)
            XCTAssertFalse(token.isDelta)
            XCTAssertFalse(token.isCC)
        }
    }

    func testNoteOffRange() {
        for note in 0...127 {
            let token = MidiToken.noteOff(UInt8(note))
            XCTAssertTrue(token.isNoteOff, "Token \(token) should be noteOff")
            XCTAssertEqual(token.noteNumber, UInt8(note))
            XCTAssertFalse(token.isNoteOn)
        }
    }

    func testVelocityRange() {
        for bucket in 0...31 {
            let token = MidiToken.velocity(bucket: bucket)
            XCTAssertTrue(token.isVelocity)
            XCTAssertEqual(token.velocityBucket, bucket)
        }
    }

    func testDeltaRange() {
        for bucket in 0...63 {
            let token = MidiToken.delta(bucket: bucket)
            XCTAssertTrue(token.isDelta)
            XCTAssertEqual(token.deltaBucket, bucket)
        }
    }

    func testCCRange() {
        for cc in 0...31 {
            for val in 0...3 {
                let token = MidiToken.controlChange(number: cc, valueBucket: val)
                XCTAssertTrue(token.isCC)
                XCTAssertEqual(token.ccNumber, cc)
                XCTAssertEqual(token.ccValueBucket, val)
            }
        }
    }

    // MARK: - Special Tokens

    func testSpecialTokens() {
        XCTAssertTrue(MidiToken.pad.isSpecial)
        XCTAssertTrue(MidiToken.bos.isSpecial)
        XCTAssertTrue(MidiToken.eos.isSpecial)
        XCTAssertTrue(MidiToken.bar.isSpecial)
        XCTAssertTrue(MidiToken.phrase.isSpecial)
    }

    func testChannelTokens() {
        for ch in 0...15 {
            let token = MidiToken.channel(UInt8(ch))
            XCTAssertTrue(token.isSpecial)
            XCTAssertEqual(token.channelNumber, UInt8(ch))
        }
    }

    // MARK: - Vocabulary Size

    func testVocabularySize() {
        XCTAssertEqual(MidiToken.vocabularySize, 512)
    }

    // MARK: - No Overlap

    func testTokenClassesDoNotOverlap() {
        for rawValue in 0..<UInt16(MidiToken.vocabularySize) {
            let token = MidiToken(rawValue: rawValue)
            let classCount = [
                token.isNoteOn,
                token.isNoteOff,
                token.isVelocity,
                token.isDelta,
                token.isCC,
                token.isSpecial
            ].filter { $0 }.count

            XCTAssertEqual(classCount, 1,
                "Token \(rawValue) belongs to \(classCount) classes (should be exactly 1)")
        }
    }

    // MARK: - Description

    func testDescription() {
        XCTAssertTrue(MidiToken.noteOn(60).description.contains("NOTE_ON"))
        XCTAssertTrue(MidiToken.noteOff(60).description.contains("NOTE_OFF"))
        XCTAssertTrue(MidiToken.velocity(bucket: 15).description.contains("VEL"))
        XCTAssertTrue(MidiToken.delta(bucket: 10).description.contains("DELTA"))
        XCTAssertTrue(MidiToken.controlChange(number: 1, valueBucket: 2).description.contains("CC"))
        XCTAssertEqual(MidiToken.bos.description, "BOS")
        XCTAssertEqual(MidiToken.eos.description, "EOS")
    }

    // MARK: - Clamping

    func testVelocityBucketClamping() {
        let token = MidiToken.velocity(bucket: 100) // exceeds max of 31
        XCTAssertTrue(token.isVelocity)
        XCTAssertEqual(token.velocityBucket, 31)
    }

    func testDeltaBucketClamping() {
        let token = MidiToken.delta(bucket: 200) // exceeds max of 63
        XCTAssertTrue(token.isDelta)
        XCTAssertEqual(token.deltaBucket, 63)
    }
}
