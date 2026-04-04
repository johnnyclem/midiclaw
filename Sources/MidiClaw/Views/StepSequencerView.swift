#if os(macOS)
import SwiftUI
import MidiClawCore

/// Grid-based step sequencer for drum programming.
struct StepSequencerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sequencerHeader

            Divider()

            // Transport controls
            transportBar

            Divider()

            // Step grid
            ScrollView {
                VStack(spacing: 0) {
                    // Step numbers header
                    stepNumbersHeader

                    // Track rows
                    ForEach(Array(appState.sequencerModel.tracks.enumerated()), id: \.element.id) { trackIdx, track in
                        TrackRow(
                            track: track,
                            trackIndex: trackIdx,
                            currentStep: appState.sequencerModel.currentStep,
                            isPlaying: appState.sequencerModel.isPlaying,
                            onToggle: { stepIdx in
                                appState.sequencerModel.toggleStep(trackIndex: trackIdx, stepIndex: stepIdx)
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }

    private var sequencerHeader: some View {
        HStack {
            Image(systemName: "square.grid.3x3.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading) {
                Text("Step Sequencer")
                    .font(.headline)
                Text("Click cells to toggle steps, use transport to play")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if appState.mindi.isEnabled {
                MindiStatusBadge(
                    instrument: .drums,
                    mindi: appState.mindi
                )

                Button {
                    Task {
                        await appState.triggerMindiAccompaniment()
                    }
                } label: {
                    Label("Generate", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appState.mindi.isGenerating)
            }
        }
        .padding()
    }

    private var transportBar: some View {
        HStack(spacing: 16) {
            // Play / Stop
            Button {
                if appState.sequencerModel.isPlaying {
                    appState.sequencerModel.stop()
                } else {
                    appState.sequencerModel.play { events in
                        appState.sendMIDI(events)
                    }
                }
            } label: {
                Image(systemName: appState.sequencerModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            // BPM
            HStack(spacing: 4) {
                Text("BPM:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("BPM", value: $appState.sequencerModel.bpm, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)

                Stepper("", value: $appState.sequencerModel.bpm, in: 40...300, step: 1)
                    .labelsHidden()
            }

            Spacer()

            // Pattern info
            if !appState.mindi.lastGeneratedDescription.isEmpty && appState.mindi.isEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text(appState.mindi.lastGeneratedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Clear
            Button("Clear All") {
                for trackIdx in 0..<appState.sequencerModel.tracks.count {
                    for stepIdx in 0..<appState.sequencerModel.stepCount {
                        appState.sequencerModel.tracks[trackIdx].steps[stepIdx].isActive = false
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var stepNumbersHeader: some View {
        HStack(spacing: 0) {
            // Track name column
            Text("")
                .frame(width: 80)

            // Step numbers
            ForEach(0..<appState.sequencerModel.stepCount, id: \.self) { step in
                Text("\(step + 1)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(step % 4 == 0 ? .primary : .tertiary)
                    .frame(width: 28, height: 20)
            }
        }
    }
}

/// A single drum track row in the sequencer.
struct TrackRow: View {
    let track: DrumTrack
    let trackIndex: Int
    let currentStep: Int
    let isPlaying: Bool
    let onToggle: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Track name
            Text(track.name)
                .font(.caption.bold())
                .frame(width: 80, alignment: .leading)

            // Steps
            ForEach(Array(track.steps.enumerated()), id: \.element.id) { stepIdx, step in
                StepCell(
                    isActive: step.isActive,
                    isCurrent: isPlaying && stepIdx == currentStep,
                    isDownbeat: stepIdx % 4 == 0,
                    onToggle: { onToggle(stepIdx) }
                )
            }
        }
        .padding(.vertical, 1)
    }
}

/// A single step cell in the sequencer grid.
struct StepCell: View {
    let isActive: Bool
    let isCurrent: Bool
    let isDownbeat: Bool
    let onToggle: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(fillColor)
            .frame(width: 26, height: 26)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(borderColor, lineWidth: isCurrent ? 2 : 0.5)
            )
            .padding(1)
            .onTapGesture {
                onToggle()
            }
    }

    private var fillColor: Color {
        if isActive && isCurrent {
            return .orange
        } else if isActive {
            return .accentColor
        } else if isCurrent {
            return Color.orange.opacity(0.2)
        } else if isDownbeat {
            return Color(.controlBackgroundColor)
        } else {
            return Color(.controlBackgroundColor).opacity(0.5)
        }
    }

    private var borderColor: Color {
        if isCurrent {
            return .orange
        } else if isDownbeat {
            return .secondary.opacity(0.3)
        } else {
            return .secondary.opacity(0.15)
        }
    }
}
#endif
