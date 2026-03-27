import Foundation
#if os(macOS)
import CoreMIDI

/// Manages the CoreMIDI client lifecycle and coordinates port/device management.
public final class MIDIManager: @unchecked Sendable {
    private var client: MIDIClientRef = 0
    private let clientName: String
    private var setupChangeHandler: (() -> Void)?

    public private(set) var isStarted = false

    public init(clientName: String = "MidiClaw") {
        self.clientName = clientName
    }

    /// Start the MIDI client and begin listening for setup changes.
    public func start(onSetupChange: @escaping () -> Void) throws {
        guard !isStarted else { return }
        self.setupChangeHandler = onSetupChange

        let status = MIDIClientCreateWithBlock(clientName as CFString, &client) { [weak self] notification in
            self?.handleNotification(notification)
        }

        guard status == noErr else {
            throw MIDIManagerError.clientCreationFailed(status: status)
        }

        isStarted = true
        Log.midi.info("MIDI client '\(clientName)' started")
    }

    /// Stop the MIDI client and dispose of all resources.
    public func stop() {
        guard isStarted else { return }
        MIDIClientDispose(client)
        client = 0
        isStarted = false
        Log.midi.info("MIDI client '\(clientName)' stopped")
    }

    /// Access the underlying CoreMIDI client reference.
    public var clientRef: MIDIClientRef {
        return client
    }

    private func handleNotification(_ notificationPtr: UnsafePointer<MIDINotification>) {
        let notification = notificationPtr.pointee
        switch notification.messageID {
        case .msgSetupChanged:
            Log.midi.info("MIDI setup changed")
            setupChangeHandler?()
        case .msgObjectAdded:
            Log.midi.info("MIDI object added")
            setupChangeHandler?()
        case .msgObjectRemoved:
            Log.midi.info("MIDI object removed")
            setupChangeHandler?()
        default:
            break
        }
    }

    deinit {
        stop()
    }
}

public enum MIDIManagerError: Error, LocalizedError {
    case clientCreationFailed(status: OSStatus)
    case portCreationFailed(status: OSStatus)
    case notStarted

    public var errorDescription: String? {
        switch self {
        case .clientCreationFailed(let status):
            return "Failed to create MIDI client (OSStatus: \(status))"
        case .portCreationFailed(let status):
            return "Failed to create MIDI port (OSStatus: \(status))"
        case .notStarted:
            return "MIDI manager has not been started"
        }
    }
}
#else
/// Stub for non-macOS platforms.
public final class MIDIManager: @unchecked Sendable {
    public private(set) var isStarted = false

    public init(clientName: String = "MidiClaw") {}

    public func start(onSetupChange: @escaping () -> Void) throws {
        isStarted = true
    }

    public func stop() {
        isStarted = false
    }
}

public enum MIDIManagerError: Error, LocalizedError {
    case clientCreationFailed(status: Int32)
    case portCreationFailed(status: Int32)
    case notStarted

    public var errorDescription: String? {
        switch self {
        case .clientCreationFailed(let status):
            return "Failed to create MIDI client (status: \(status))"
        case .portCreationFailed(let status):
            return "Failed to create MIDI port (status: \(status))"
        case .notStarted:
            return "MIDI manager has not been started"
        }
    }
}
#endif
