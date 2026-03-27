import XCTest
import AudioToolbox
@testable import MidiClawAU

final class MidiClawAUParameterTests: XCTestCase {

    func testParameterTreeHasAllParameters() {
        let tree = MidiClawAUParameterDefinitions.createParameterTree()

        XCTAssertNotNil(tree.parameter(withAddress: MidiClawAUParameterAddress.mode.rawValue))
        XCTAssertNotNil(tree.parameter(withAddress: MidiClawAUParameterAddress.channelFilter.rawValue))
        XCTAssertNotNil(tree.parameter(withAddress: MidiClawAUParameterAddress.velocityScale.rawValue))
        XCTAssertNotNil(tree.parameter(withAddress: MidiClawAUParameterAddress.tokenMonitor.rawValue))
    }

    func testModeParameterDefaults() {
        let tree = MidiClawAUParameterDefinitions.createParameterTree()
        let mode = tree.parameter(withAddress: MidiClawAUParameterAddress.mode.rawValue)!

        XCTAssertEqual(mode.value, 1.0, "Default mode should be Passthrough (1)")
        XCTAssertEqual(mode.minValue, 0)
        XCTAssertEqual(mode.maxValue, 2)
    }

    func testChannelFilterParameterDefaults() {
        let tree = MidiClawAUParameterDefinitions.createParameterTree()
        let channelFilter = tree.parameter(withAddress: MidiClawAUParameterAddress.channelFilter.rawValue)!

        XCTAssertEqual(channelFilter.value, 0, "Default channel filter should be All (0)")
        XCTAssertEqual(channelFilter.minValue, 0)
        XCTAssertEqual(channelFilter.maxValue, 16)
    }

    func testVelocityScaleParameterDefaults() {
        let tree = MidiClawAUParameterDefinitions.createParameterTree()
        let velocityScale = tree.parameter(withAddress: MidiClawAUParameterAddress.velocityScale.rawValue)!

        XCTAssertEqual(velocityScale.value, 1.0, "Default velocity scale should be 1.0")
        XCTAssertEqual(velocityScale.minValue, 0.0)
        XCTAssertEqual(velocityScale.maxValue, 2.0)
    }

    func testTokenMonitorParameterDefaults() {
        let tree = MidiClawAUParameterDefinitions.createParameterTree()
        let tokenMonitor = tree.parameter(withAddress: MidiClawAUParameterAddress.tokenMonitor.rawValue)!

        XCTAssertEqual(tokenMonitor.value, 1.0, "Default token monitor should be on")
    }

    func testModeParameterValueStrings() {
        let tree = MidiClawAUParameterDefinitions.createParameterTree()
        let mode = tree.parameter(withAddress: MidiClawAUParameterAddress.mode.rawValue)!

        XCTAssertEqual(mode.valueStrings, ["Monitor", "Passthrough", "Transform"])
    }

    func testComponentDescriptionValues() {
        let desc = AudioComponentDescription.midiClaw
        XCTAssertEqual(desc.componentType, kAudioUnitType_MIDIProcessor)
        XCTAssertEqual(desc.componentSubType, fourCharCode("MCla"))
        XCTAssertEqual(desc.componentManufacturer, fourCharCode("MCjc"))
    }

    func testFourCharCodeConversion() {
        let code = fourCharCode("MCla")
        // 'M' = 0x4D, 'C' = 0x43, 'l' = 0x6C, 'a' = 0x61
        let expected: UInt32 = (0x4D << 24) | (0x43 << 16) | (0x6C << 8) | 0x61
        XCTAssertEqual(code, expected)
    }
}
