import Foundation
#if os(macOS)
import CoreMIDI

/// Represents a discovered MIDI endpoint (source or destination).
public struct MIDIEndpointInfo: Identifiable, Equatable, Sendable {
    public let id: Int  // MIDIEndpointRef as Int
    public let name: String
    public let manufacturer: String
    public let isVirtual: Bool
    public let isSource: Bool

    public init(id: Int, name: String, manufacturer: String, isVirtual: Bool, isSource: Bool) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.isVirtual = isVirtual
        self.isSource = isSource
    }
}

/// Enumerates hardware and virtual MIDI devices.
/// Re-scan on setup change notifications from MIDIManager.
public final class MIDIHardwareScanner: @unchecked Sendable {
    public private(set) var sources: [MIDIEndpointInfo] = []
    public private(set) var destinations: [MIDIEndpointInfo] = []

    public init() {}

    /// Scan all available MIDI sources and destinations.
    public func scan() {
        sources = scanSources()
        destinations = scanDestinations()
        Log.midi.info("Scanned MIDI devices: \(sources.count) sources, \(destinations.count) destinations")
    }

    private func scanSources() -> [MIDIEndpointInfo] {
        let count = MIDIGetNumberOfSources()
        return (0..<count).compactMap { i in
            let endpoint = MIDIGetSource(i)
            return endpointInfo(for: endpoint, isSource: true)
        }
    }

    private func scanDestinations() -> [MIDIEndpointInfo] {
        let count = MIDIGetNumberOfDestinations()
        return (0..<count).compactMap { i in
            let endpoint = MIDIGetDestination(i)
            return endpointInfo(for: endpoint, isSource: false)
        }
    }

    private func endpointInfo(for endpoint: MIDIEndpointRef, isSource: Bool) -> MIDIEndpointInfo? {
        guard endpoint != 0 else { return nil }

        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
        let displayName = (name?.takeRetainedValue() as String?) ?? "Unknown"

        var manufacturer: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyManufacturer, &manufacturer)
        let mfg = (manufacturer?.takeRetainedValue() as String?) ?? ""

        // Check if this endpoint is virtual (no connected entity)
        var entity: MIDIEntityRef = 0
        MIDIEndpointGetEntity(endpoint, &entity)
        let isVirtual = entity == 0

        return MIDIEndpointInfo(
            id: Int(endpoint),
            name: displayName,
            manufacturer: mfg,
            isVirtual: isVirtual,
            isSource: isSource
        )
    }

    /// Get the MIDIEndpointRef for a source by its info ID.
    public func sourceEndpoint(for info: MIDIEndpointInfo) -> MIDIEndpointRef {
        return MIDIEndpointRef(info.id)
    }

    /// Get the MIDIEndpointRef for a destination by its info ID.
    public func destinationEndpoint(for info: MIDIEndpointInfo) -> MIDIEndpointRef {
        return MIDIEndpointRef(info.id)
    }
}
#else
/// Stub for non-macOS platforms.
public struct MIDIEndpointInfo: Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let manufacturer: String
    public let isVirtual: Bool
    public let isSource: Bool

    public init(id: Int, name: String, manufacturer: String, isVirtual: Bool, isSource: Bool) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.isVirtual = isVirtual
        self.isSource = isSource
    }
}

public final class MIDIHardwareScanner: @unchecked Sendable {
    public private(set) var sources: [MIDIEndpointInfo] = []
    public private(set) var destinations: [MIDIEndpointInfo] = []

    public init() {}

    public func scan() {
        sources = []
        destinations = []
    }
}
#endif
