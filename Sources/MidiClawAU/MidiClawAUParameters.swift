import AudioToolbox

/// Parameter addresses for the MidiClaw AudioUnit.
public enum MidiClawAUParameterAddress: UInt64 {
    /// Operating mode: 0 = Monitor, 1 = Passthrough, 2 = Transform
    case mode = 0
    /// MIDI channel filter: 0 = All channels, 1–16 = specific channel
    case channelFilter = 1
    /// Velocity scale factor: 0.0–2.0 (1.0 = no change)
    case velocityScale = 2
    /// Token monitor enable: 0 = off, 1 = on
    case tokenMonitor = 3
}

/// Defines and creates the AUParameterTree for MidiClaw.
public struct MidiClawAUParameterDefinitions {
    public static let modeDefault: Float = 1.0        // Passthrough
    public static let channelFilterDefault: Float = 0  // All channels
    public static let velocityScaleDefault: Float = 1.0
    public static let tokenMonitorDefault: Float = 1.0 // On

    /// Create the full parameter tree for the AudioUnit.
    public static func createParameterTree() -> AUParameterTree {
        let mode = AUParameterTree.createParameter(
            withIdentifier: "mode",
            name: "Mode",
            address: MidiClawAUParameterAddress.mode.rawValue,
            min: 0,
            max: 2,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: ["Monitor", "Passthrough", "Transform"],
            dependentParameters: nil
        )
        mode.value = modeDefault

        let channelFilter = AUParameterTree.createParameter(
            withIdentifier: "channelFilter",
            name: "Channel Filter",
            address: MidiClawAUParameterAddress.channelFilter.rawValue,
            min: 0,
            max: 16,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: ["All", "1", "2", "3", "4", "5", "6", "7", "8",
                           "9", "10", "11", "12", "13", "14", "15", "16"],
            dependentParameters: nil
        )
        channelFilter.value = channelFilterDefault

        let velocityScale = AUParameterTree.createParameter(
            withIdentifier: "velocityScale",
            name: "Velocity Scale",
            address: MidiClawAUParameterAddress.velocityScale.rawValue,
            min: 0.0,
            max: 2.0,
            unit: .linearGain,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        velocityScale.value = velocityScaleDefault

        let tokenMonitor = AUParameterTree.createParameter(
            withIdentifier: "tokenMonitor",
            name: "Token Monitor",
            address: MidiClawAUParameterAddress.tokenMonitor.rawValue,
            min: 0,
            max: 1,
            unit: .boolean,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        tokenMonitor.value = tokenMonitorDefault

        return AUParameterTree.createTree(withChildren: [
            mode, channelFilter, velocityScale, tokenMonitor
        ])
    }
}
