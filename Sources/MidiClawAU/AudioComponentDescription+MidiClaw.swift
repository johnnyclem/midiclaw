import AudioToolbox

extension AudioComponentDescription {
    /// AudioUnit component description for MidiClaw MIDI effect.
    ///
    /// - Type: `kAudioUnitType_MIDIProcessor` ('aumi') — MIDI effect plugin
    /// - SubType: 'MCla' — MidiClaw
    /// - Manufacturer: 'MCjc' — MidiClaw / John Clem
    public static let midiClaw = AudioComponentDescription(
        componentType: kAudioUnitType_MIDIProcessor,
        componentSubType: fourCharCode("MCla"),
        componentManufacturer: fourCharCode("MCjc"),
        componentFlags: 0,
        componentFlagsMask: 0
    )
}

/// Convert a 4-character string to a `UInt32` FourCharCode.
func fourCharCode(_ string: String) -> UInt32 {
    var result: UInt32 = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) | UInt32(char)
    }
    return result
}
