#if os(macOS)
import Foundation
import MidiClawCore

/// A single step in the sequencer grid.
struct SequencerStep: Identifiable, Equatable {
    let id = UUID()
    var isActive: Bool = false
    var velocity: UInt8 = 100
}

/// A row in the sequencer representing one drum sound.
struct DrumTrack: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let noteNumber: UInt8
    var steps: [SequencerStep]

    init(name: String, noteNumber: UInt8, stepCount: Int = 16) {
        self.name = name
        self.noteNumber = noteNumber
        self.steps = (0..<stepCount).map { _ in SequencerStep() }
    }
}

/// Model for the step sequencer / drum machine.
@MainActor
final class StepSequencerModel: ObservableObject {
    @Published var tracks: [DrumTrack]
    @Published var currentStep: Int = 0
    @Published var isPlaying: Bool = false
    @Published var bpm: Double = 120.0
    @Published var stepCount: Int = 16

    /// MIDI channel for drums (GM standard channel 10 = index 9).
    let midiChannel: UInt8 = 9

    private var timer: Timer?

    init() {
        // General MIDI drum map subset
        self.tracks = [
            DrumTrack(name: "Kick", noteNumber: 36),
            DrumTrack(name: "Snare", noteNumber: 38),
            DrumTrack(name: "Closed HH", noteNumber: 42),
            DrumTrack(name: "Open HH", noteNumber: 46),
            DrumTrack(name: "Low Tom", noteNumber: 45),
            DrumTrack(name: "Mid Tom", noteNumber: 47),
            DrumTrack(name: "High Tom", noteNumber: 50),
            DrumTrack(name: "Clap", noteNumber: 39),
        ]
    }

    func toggleStep(trackIndex: Int, stepIndex: Int) {
        guard trackIndex < tracks.count, stepIndex < tracks[trackIndex].steps.count else { return }
        tracks[trackIndex].steps[stepIndex].isActive.toggle()
    }

    func play(sendMIDI: @escaping ([MIDIEvent]) -> Void) {
        guard !isPlaying else { return }
        isPlaying = true
        currentStep = 0

        let interval = 60.0 / bpm / 4.0 // 16th notes
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isPlaying else { return }
                self.tickStep(sendMIDI: sendMIDI)
            }
        }
    }

    func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        currentStep = 0
    }

    private func tickStep(sendMIDI: @escaping ([MIDIEvent]) -> Void) {
        let now = mach_absolute_time()
        var events: [MIDIEvent] = []

        for track in tracks {
            guard currentStep < track.steps.count else { continue }
            let step = track.steps[currentStep]
            if step.isActive {
                let noteOn = MIDIEvent(
                    timestampNs: UInt64(now),
                    message: .noteOn(channel: midiChannel, note: track.noteNumber, velocity: step.velocity)
                )
                let noteOff = MIDIEvent(
                    timestampNs: UInt64(now) + 50_000_000, // 50ms duration
                    message: .noteOff(channel: midiChannel, note: track.noteNumber, velocity: 0)
                )
                events.append(noteOn)
                events.append(noteOff)
            }
        }

        if !events.isEmpty {
            sendMIDI(events)
        }

        currentStep = (currentStep + 1) % stepCount
    }

    /// Generate events for all active steps (used by Mindi to read the pattern).
    func currentPattern() -> [(trackName: String, noteNumber: UInt8, activeSteps: [Int])] {
        tracks.map { track in
            let active = track.steps.enumerated().compactMap { $0.element.isActive ? $0.offset : nil }
            return (track.name, track.noteNumber, active)
        }
    }

    /// Load a pattern from Mindi-generated data.
    func loadPattern(_ pattern: [(noteNumber: UInt8, activeSteps: [Int])]) {
        for entry in pattern {
            if let trackIdx = tracks.firstIndex(where: { $0.noteNumber == entry.noteNumber }) {
                for stepIdx in 0..<tracks[trackIdx].steps.count {
                    tracks[trackIdx].steps[stepIdx].isActive = entry.activeSteps.contains(stepIdx)
                }
            }
        }
    }
}
#endif
