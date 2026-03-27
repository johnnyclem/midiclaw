#if os(macOS)
import Foundation

/// The two instruments the user can control.
enum ControlledInstrument: String, CaseIterable, Identifiable {
    case piano = "Piano"
    case drums = "Drums"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .piano: return "pianokeys"
        case .drums: return "square.grid.3x3.fill"
        }
    }

    var description: String {
        switch self {
        case .piano: return "Play melodies and chords on the piano"
        case .drums: return "Program beats on the step sequencer"
        }
    }

    /// The instrument Mindi will accompany on (the opposite).
    var accompanimentInstrument: ControlledInstrument {
        switch self {
        case .piano: return .drums
        case .drums: return .piano
        }
    }
}
#endif
