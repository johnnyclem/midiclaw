#if os(macOS)
import Foundation
import MidiClawCore

/// Model for the piano keyboard instrument.
@MainActor
final class PianoModel: ObservableObject {
    /// Currently held notes (note number -> velocity).
    @Published var activeNotes: Set<UInt8> = []

    /// The range of notes to display.
    @Published var lowestNote: UInt8 = 48  // C3
    @Published var highestNote: UInt8 = 84 // C6 (3 octaves)

    /// MIDI channel for piano.
    let midiChannel: UInt8 = 0

    /// The most recent note events for Mindi to analyze.
    @Published var recentNotes: [MIDIEvent] = []
    private static let maxRecentNotes = 64

    func noteOn(_ note: UInt8, velocity: UInt8 = 100, sendMIDI: @escaping ([MIDIEvent]) -> Void) {
        activeNotes.insert(note)
        let now = mach_absolute_time()
        let event = MIDIEvent(
            timestampNs: UInt64(now),
            message: .noteOn(channel: midiChannel, note: note, velocity: velocity)
        )
        recentNotes.append(event)
        if recentNotes.count > Self.maxRecentNotes {
            recentNotes.removeFirst(recentNotes.count - Self.maxRecentNotes)
        }
        sendMIDI([event])
    }

    func noteOff(_ note: UInt8, sendMIDI: @escaping ([MIDIEvent]) -> Void) {
        activeNotes.remove(note)
        let now = mach_absolute_time()
        let event = MIDIEvent(
            timestampNs: UInt64(now),
            message: .noteOff(channel: midiChannel, note: note, velocity: 0)
        )
        recentNotes.append(event)
        if recentNotes.count > Self.maxRecentNotes {
            recentNotes.removeFirst(recentNotes.count - Self.maxRecentNotes)
        }
        sendMIDI([event])
    }

    /// Check if a note number is a black key.
    static func isBlackKey(_ note: UInt8) -> Bool {
        let n = note % 12
        return n == 1 || n == 3 || n == 6 || n == 8 || n == 10
    }

    /// Get the note name for display.
    static func noteName(_ note: UInt8) -> String {
        MIDIMessage.noteName(note)
    }

    /// Clear all active notes.
    func allNotesOff(sendMIDI: @escaping ([MIDIEvent]) -> Void) {
        let now = mach_absolute_time()
        let events = activeNotes.map { note in
            MIDIEvent(
                timestampNs: UInt64(now),
                message: .noteOff(channel: midiChannel, note: note, velocity: 0)
            )
        }
        activeNotes.removeAll()
        if !events.isEmpty {
            sendMIDI(events)
        }
    }
}
#endif
