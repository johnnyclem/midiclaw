import Foundation
#if os(macOS)
import CoreMIDI

/// Sends MIDI events to hardware or virtual destinations.
public final class MIDIOutput: @unchecked Sendable {
    private let manager: MIDIManager
    private var outputPort: MIDIPortRef = 0

    public init(manager: MIDIManager) {
        self.manager = manager
    }

    /// Create an output port for sending to hardware destinations.
    public func createOutputPort(name: String = "MidiClaw Output") throws {
        guard manager.isStarted else { throw MIDIManagerError.notStarted }

        let status = MIDIOutputPortCreate(
            manager.clientRef,
            name as CFString,
            &outputPort
        )
        guard status == noErr else {
            throw MIDIManagerError.portCreationFailed(status: status)
        }
        Log.midi.info("Output port '\(name)' created")
    }

    /// Send MIDI events to a specific destination endpoint.
    public func send(events: [MIDIEvent], to destination: MIDIEndpointRef) throws {
        guard outputPort != 0 else { throw MIDIManagerError.notStarted }

        for event in events {
            let bytes = event.message.rawBytes
            var packetList = MIDIPacketList()
            var packet = MIDIPacketListInit(&packetList)
            packet = MIDIPacketListAdd(
                &packetList,
                MemoryLayout<MIDIPacketList>.size,
                packet,
                0, // timestamp 0 = send immediately
                bytes.count,
                bytes
            )

            let status = MIDISend(outputPort, destination, &packetList)
            if status != noErr {
                Log.midi.error("Failed to send MIDI event: OSStatus \(status)")
            }
        }
    }

    /// Dispose of the output port.
    public func dispose() {
        if outputPort != 0 {
            MIDIPortDispose(outputPort)
            outputPort = 0
        }
    }

    deinit {
        dispose()
    }
}
#else
/// Stub for non-macOS platforms.
public final class MIDIOutput: @unchecked Sendable {
    public init(manager: MIDIManager) {}

    public func createOutputPort(name: String = "MidiClaw Output") throws {}
    public func send(events: [MIDIEvent], to destination: Int) throws {}
    public func dispose() {}
}
#endif
