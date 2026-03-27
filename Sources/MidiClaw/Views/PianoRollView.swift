#if os(macOS)
import SwiftUI
import MidiClawCore

/// Interactive piano keyboard view with note display.
struct PianoRollView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pianokeys")
                    .font(.title2)
                    .foregroundStyle(.accent)
                VStack(alignment: .leading) {
                    Text("Piano")
                        .font(.headline)
                    Text("Click keys or use your computer keyboard to play")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Octave controls
                HStack(spacing: 4) {
                    Button {
                        shiftOctave(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Text("C\(appState.pianoModel.lowestNote / 12 - 1)")
                        .font(.caption.monospaced())
                        .frame(width: 30)

                    Button {
                        shiftOctave(1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if appState.mindi.isEnabled {
                    MindiStatusBadge(
                        instrument: .piano,
                        mindi: appState.mindi
                    )
                }
            }
            .padding()

            Divider()

            // Piano keyboard
            GeometryReader { geometry in
                PianoKeyboardView(
                    pianoModel: appState.pianoModel,
                    width: geometry.size.width,
                    height: min(geometry.size.height * 0.45, 200),
                    sendMIDI: { events in appState.sendMIDI(events) }
                )
                .frame(height: min(geometry.size.height * 0.45, 200))
                .frame(maxWidth: .infinity)

                // Recent notes display
                VStack {
                    Spacer()
                        .frame(height: min(geometry.size.height * 0.45, 200) + 8)

                    NoteHistoryView(events: appState.pianoModel.recentNotes)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func shiftOctave(_ direction: Int) {
        let newLow = Int(appState.pianoModel.lowestNote) + direction * 12
        let newHigh = Int(appState.pianoModel.highestNote) + direction * 12
        if newLow >= 0 && newHigh <= 127 {
            appState.pianoModel.lowestNote = UInt8(newLow)
            appState.pianoModel.highestNote = UInt8(newHigh)
        }
    }
}

/// The actual keyboard rendering.
struct PianoKeyboardView: View {
    @ObservedObject var pianoModel: PianoModel
    let width: CGFloat
    let height: CGFloat
    let sendMIDI: ([MIDIEvent]) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // White keys
            HStack(spacing: 1) {
                ForEach(whiteKeys, id: \.self) { note in
                    WhiteKeyView(
                        note: note,
                        isActive: pianoModel.activeNotes.contains(note),
                        height: height,
                        onPress: { pianoModel.noteOn(note, sendMIDI: sendMIDI) },
                        onRelease: { pianoModel.noteOff(note, sendMIDI: sendMIDI) }
                    )
                }
            }

            // Black keys overlay
            ForEach(blackKeyPositions, id: \.note) { pos in
                BlackKeyView(
                    note: pos.note,
                    isActive: pianoModel.activeNotes.contains(pos.note),
                    height: height * 0.6,
                    xOffset: pos.xOffset,
                    keyWidth: blackKeyWidth,
                    onPress: { pianoModel.noteOn(pos.note, sendMIDI: sendMIDI) },
                    onRelease: { pianoModel.noteOff(pos.note, sendMIDI: sendMIDI) }
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var whiteKeys: [UInt8] {
        (pianoModel.lowestNote...pianoModel.highestNote).filter { !PianoModel.isBlackKey($0) }
    }

    private var whiteKeyWidth: CGFloat {
        let count = CGFloat(whiteKeys.count)
        return max((width - count) / count, 20)
    }

    private var blackKeyWidth: CGFloat {
        whiteKeyWidth * 0.6
    }

    private struct BlackKeyPosition {
        let note: UInt8
        let xOffset: CGFloat
    }

    private var blackKeyPositions: [BlackKeyPosition] {
        var positions: [BlackKeyPosition] = []
        var whiteIndex = 0
        for note in pianoModel.lowestNote...pianoModel.highestNote {
            if PianoModel.isBlackKey(note) {
                let x = CGFloat(whiteIndex) * (whiteKeyWidth + 1) - blackKeyWidth / 2
                positions.append(BlackKeyPosition(note: note, xOffset: x))
            } else {
                whiteIndex += 1
            }
        }
        return positions
    }
}

struct WhiteKeyView: View {
    let note: UInt8
    let isActive: Bool
    let height: CGFloat
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isActive ? Color.accentColor.opacity(0.3) : .white)
                .frame(height: height - 24)

            Text(PianoModel.noteName(note))
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .frame(height: 24)
                .frame(maxWidth: .infinity)
                .background(isActive ? Color.accentColor.opacity(0.3) : Color(.controlBackgroundColor))
        }
        .border(Color.gray.opacity(0.3), width: 0.5)
        .onTapGesture {
            onPress()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onRelease()
            }
        }
    }
}

struct BlackKeyView: View {
    let note: UInt8
    let isActive: Bool
    let height: CGFloat
    let xOffset: CGFloat
    let keyWidth: CGFloat
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        Rectangle()
            .fill(isActive ? Color.accentColor : Color.black)
            .frame(width: keyWidth, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .shadow(radius: 2)
            .offset(x: xOffset)
            .onTapGesture {
                onPress()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onRelease()
                }
            }
    }
}

/// Scrolling display of recent note events.
struct NoteHistoryView: View {
    let events: [MIDIEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent Notes")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(noteOnEvents.suffix(32).enumerated()), id: \.offset) { _, event in
                        if case .noteOn(_, let note, let velocity) = event.message {
                            NoteChip(note: note, velocity: velocity)
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var noteOnEvents: [MIDIEvent] {
        events.filter {
            if case .noteOn = $0.message { return true }
            return false
        }
    }
}

struct NoteChip: View {
    let note: UInt8
    let velocity: UInt8

    var body: some View {
        Text(MIDIMessage.noteName(note))
            .font(.caption2.monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(Double(velocity) / 127.0 * 0.6 + 0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

/// Small badge showing Mindi status for the current instrument.
struct MindiStatusBadge: View {
    let instrument: ControlledInstrument
    @ObservedObject var mindi: MindiAccompanist

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wand.and.stars")
                .font(.caption)
            Text("Mindi: \(instrument.accompanimentInstrument.rawValue)")
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.purple.opacity(0.15))
        .clipShape(Capsule())
    }
}
#endif
