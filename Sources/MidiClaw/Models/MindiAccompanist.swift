#if os(macOS)
import Foundation
import MidiClawCore

/// Mindi - the MidiClaw AI accompanist.
/// Listens to whichever instrument the user controls and generates
/// MIDI for the other instrument.
@MainActor
final class MindiAccompanist: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var isGenerating: Bool = false
    @Published var lastGeneratedDescription: String = ""

    private var llmManager: LLMManager?

    func configure(llmManager: LLMManager) {
        self.llmManager = llmManager
    }

    /// Generate accompanying drum pattern based on piano input.
    func generateDrumAccompaniment(
        pianoNotes: [MIDIEvent],
        currentBPM: Double
    ) async -> [(noteNumber: UInt8, activeSteps: [Int])] {
        isGenerating = true
        defer { isGenerating = false }

        // Analyze the piano input to determine style
        let noteCount = pianoNotes.filter {
            if case .noteOn = $0.message { return true }
            return false
        }.count

        // Generate a complementary drum pattern
        // In production, this uses the LLM + adapter to generate tokens
        // For now, generate musically sensible patterns based on analysis
        var pattern: [(noteNumber: UInt8, activeSteps: [Int])] = []

        if noteCount > 8 {
            // Busy piano -> simple drums
            lastGeneratedDescription = "Simple beat to complement busy piano"
            pattern = [
                (36, [0, 8]),                    // Kick: 1, 3
                (38, [4, 12]),                   // Snare: 2, 4
                (42, [0, 2, 4, 6, 8, 10, 12, 14]) // HH: 8ths
            ]
        } else {
            // Sparse piano -> more active drums
            lastGeneratedDescription = "Active pattern to fill out sparse arrangement"
            pattern = [
                (36, [0, 3, 6, 8, 11, 14]),     // Syncopated kick
                (38, [4, 12]),                   // Snare: 2, 4
                (42, (0..<16).map { $0 }),        // HH: 16ths
                (39, [4, 12]),                   // Clap with snare
            ]
        }

        return pattern
    }

    /// Generate accompanying piano chords based on drum pattern.
    func generatePianoAccompaniment(
        drumPattern: [(trackName: String, noteNumber: UInt8, activeSteps: [Int])],
        currentBPM: Double
    ) async -> [MIDIEvent] {
        isGenerating = true
        defer { isGenerating = false }

        let now = mach_absolute_time()
        let stepDurationNs = UInt64(60.0 / currentBPM / 4.0 * 1_000_000_000)

        // Determine groove density from drum pattern
        let totalActiveSteps = drumPattern.reduce(0) { $0 + $1.activeSteps.count }

        // Generate chord progression
        // In production, LLM generates token sequences decoded to MIDI
        let chords: [[UInt8]]
        if totalActiveSteps > 20 {
            // Busy drums -> sustained chords
            lastGeneratedDescription = "Sustained chords over busy groove"
            chords = [
                [60, 64, 67],    // C major
                [57, 60, 64],    // A minor
                [53, 57, 60],    // F major
                [55, 59, 62],    // G major
            ]
        } else {
            // Sparse drums -> rhythmic comping
            lastGeneratedDescription = "Rhythmic comping over sparse beat"
            chords = [
                [60, 64, 67, 72], // C major 7
                [65, 69, 72, 76], // F major 7
                [62, 65, 69, 72], // D minor 7
                [55, 59, 62, 65], // G7
            ]
        }

        var events: [MIDIEvent] = []
        for (chordIdx, chord) in chords.enumerated() {
            let startStep = chordIdx * 4
            let startNs = UInt64(now) + UInt64(startStep) * stepDurationNs
            let endNs = startNs + 4 * stepDurationNs - stepDurationNs / 4

            for note in chord {
                events.append(MIDIEvent(
                    timestampNs: startNs,
                    message: .noteOn(channel: 0, note: note, velocity: 80)
                ))
                events.append(MIDIEvent(
                    timestampNs: endNs,
                    message: .noteOff(channel: 0, note: note, velocity: 0)
                ))
            }
        }

        return events
    }
}
#endif
