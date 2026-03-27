import Foundation
#if os(macOS)
import CoreMIDI

/// Creates and manages virtual MIDI ports (source + destination).
/// The destination port receives incoming MIDI; the source port sends outgoing MIDI.
public final class MIDIPortManager: @unchecked Sendable {
    private let manager: MIDIManager
    private var virtualSource: MIDIEndpointRef = 0
    private var virtualDestination: MIDIEndpointRef = 0
    private var inputPort: MIDIPortRef = 0
    private var parser = MIDIParser()

    /// Called on a background queue when MIDI events arrive.
    public var onEventsReceived: (([MIDIEvent]) -> Void)?

    public private(set) var isActive = false

    public init(manager: MIDIManager) {
        self.manager = manager
    }

    /// Create virtual ports that appear in other apps' MIDI port lists.
    public func createVirtualPorts(
        sourceName: String = "MidiClaw Out",
        destinationName: String = "MidiClaw In"
    ) throws {
        guard manager.isStarted else { throw MIDIManagerError.notStarted }

        // Virtual source: MidiClaw sends MIDI out through this
        var status = MIDISourceCreateWithProtocol(
            manager.clientRef,
            sourceName as CFString,
            ._1_0,
            &virtualSource
        )
        guard status == noErr else {
            throw MIDIManagerError.portCreationFailed(status: status)
        }

        // Virtual destination: MidiClaw receives MIDI through this
        status = MIDIDestinationCreateWithProtocol(
            manager.clientRef,
            destinationName as CFString,
            ._1_0,
            &virtualDestination
        ) { [weak self] eventList, _ in
            self?.handleIncomingEvents(eventList)
        }
        guard status == noErr else {
            MIDIEndpointDispose(virtualSource)
            virtualSource = 0
            throw MIDIManagerError.portCreationFailed(status: status)
        }

        isActive = true
        Log.midi.info("Virtual ports created: '\(sourceName)' / '\(destinationName)'")
    }

    /// Create an input port to receive from a specific hardware source.
    public func createInputPort(name: String = "MidiClaw Input") throws {
        guard manager.isStarted else { throw MIDIManagerError.notStarted }

        let status = MIDIInputPortCreateWithProtocol(
            manager.clientRef,
            name as CFString,
            ._1_0,
            &inputPort
        ) { [weak self] eventList, _ in
            self?.handleIncomingEvents(eventList)
        }

        guard status == noErr else {
            throw MIDIManagerError.portCreationFailed(status: status)
        }

        Log.midi.info("Input port '\(name)' created")
    }

    /// Connect the input port to a hardware MIDI source.
    public func connectSource(_ source: MIDIEndpointRef) throws {
        guard inputPort != 0 else { throw MIDIManagerError.notStarted }
        let status = MIDIPortConnectSource(inputPort, source, nil)
        guard status == noErr else {
            throw MIDIManagerError.portCreationFailed(status: status)
        }
    }

    /// Disconnect a hardware MIDI source from the input port.
    public func disconnectSource(_ source: MIDIEndpointRef) {
        if inputPort != 0 {
            MIDIPortDisconnectSource(inputPort, source)
        }
    }

    /// Send MIDI events through the virtual source port.
    public func send(events: [MIDIEvent]) throws {
        guard virtualSource != 0 else { throw MIDIManagerError.notStarted }

        for event in events {
            let bytes = event.message.rawBytes
            let wordCount = (bytes.count + 3) / 4
            var words: [UInt32] = []

            // Build MIDI 1.0 Universal MIDI Packet words
            if bytes.count <= 3 {
                var word: UInt32 = 0x20000000 // MIDI 1.0 channel voice message type
                for (i, byte) in bytes.enumerated() {
                    word |= UInt32(byte) << UInt32((2 - i) * 8)
                }
                words.append(word)
            } else {
                // SysEx or longer — send as raw bytes
                for byte in bytes {
                    words.append(UInt32(byte))
                }
            }

            // Build and send event list
            var eventList = MIDIEventList()
            var packet = MIDIEventListInit(&eventList, ._1_0)
            for word in words {
                packet = MIDIEventListAdd(&eventList, 256, packet, 0, 1, [word])
            }

            MIDIReceivedEventList(virtualSource, &eventList)
        }
    }

    /// Dispose of all ports.
    public func dispose() {
        if virtualSource != 0 {
            MIDIEndpointDispose(virtualSource)
            virtualSource = 0
        }
        if virtualDestination != 0 {
            MIDIEndpointDispose(virtualDestination)
            virtualDestination = 0
        }
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
            inputPort = 0
        }
        isActive = false
        Log.midi.info("All MIDI ports disposed")
    }

    private func handleIncomingEvents(_ eventListPtr: UnsafePointer<MIDIEventList>) {
        let timestampNs = MachTime.nowNanoseconds
        let eventList = eventListPtr.pointee

        var rawBytes: [UInt8] = []

        // Extract bytes from MIDIEventList
        withUnsafePointer(to: eventList.packet) { firstPacket in
            var packet = firstPacket
            for _ in 0..<eventList.numPackets {
                let p = packet.pointee
                let wordCount = Int(p.wordCount)
                withUnsafePointer(to: p.words) { wordsPtr in
                    wordsPtr.withMemoryRebound(to: UInt32.self, capacity: wordCount) { words in
                        for j in 0..<wordCount {
                            let word = words[j]
                            // Extract bytes from UMP word
                            rawBytes.append(UInt8((word >> 16) & 0xFF))
                            rawBytes.append(UInt8((word >> 8) & 0xFF))
                            rawBytes.append(UInt8(word & 0xFF))
                        }
                    }
                }
                packet = UnsafePointer(MIDIEventPacketNext(packet))
            }
        }

        let events = parser.parse(bytes: rawBytes, timestampNs: timestampNs)
        if !events.isEmpty {
            onEventsReceived?(events)
        }
    }

    deinit {
        dispose()
    }
}
#else
/// Stub for non-macOS platforms.
public final class MIDIPortManager: @unchecked Sendable {
    public var onEventsReceived: (([MIDIEvent]) -> Void)?
    public private(set) var isActive = false

    public init(manager: MIDIManager) {}

    public func createVirtualPorts(
        sourceName: String = "MidiClaw Out",
        destinationName: String = "MidiClaw In"
    ) throws {
        isActive = true
    }

    public func send(events: [MIDIEvent]) throws {}

    public func dispose() {
        isActive = false
    }
}
#endif
