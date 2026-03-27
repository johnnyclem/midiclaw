import Foundation

/// Centralizes all bucket quantization math for the MidiToken vocabulary.
/// Both encoder and decoder use these functions to ensure perfect symmetry.
public enum TokenVocabulary {

    // MARK: - Velocity Buckets (32 buckets, 4-unit resolution)

    /// Map MIDI velocity (0-127) to bucket index (0-31).
    public static func velocityToBucket(_ velocity: UInt8) -> Int {
        return Int(velocity) / 4
    }

    /// Map velocity bucket (0-31) to representative MIDI velocity.
    /// Returns the center value of the bucket range.
    public static func bucketToVelocity(_ bucket: Int) -> UInt8 {
        let clamped = min(max(bucket, 0), 31)
        return UInt8(clamped * 4 + 2) // center of the 4-unit bucket
    }

    // MARK: - Time Delta Buckets (64 buckets, log-scaled 1ms–4000ms)

    /// The log base used for delta bucket scaling.
    /// 64 buckets cover 1ms to 4000ms on a log scale.
    private static let deltaLogBase = log(4000.0)

    /// Map a time delta in milliseconds to bucket index (0-63).
    public static func deltaToBucket(_ deltaMs: Double) -> Int {
        guard deltaMs > 0 else { return 0 }
        let clamped = min(max(deltaMs, 1.0), 4000.0)
        let bucket = 63.0 * log(clamped) / deltaLogBase
        return Int(bucket.rounded(.toNearestOrAwayFromZero).clamped(to: 0...63))
    }

    /// Map delta bucket (0-63) to representative time delta in milliseconds.
    public static func bucketToDelta(_ bucket: Int) -> Double {
        let clamped = Double(min(max(bucket, 0), 63))
        return exp(clamped / 63.0 * deltaLogBase)
    }

    // MARK: - CC Value Buckets (4 buckets per CC number)

    /// Map CC value (0-127) to bucket index (0-3).
    public static func ccValueToBucket(_ value: UInt8) -> Int {
        return Int(value) / 32
    }

    /// Map CC value bucket (0-3) to representative CC value.
    public static func bucketToCCValue(_ bucket: Int) -> UInt8 {
        let clamped = min(max(bucket, 0), 3)
        return UInt8(clamped * 32 + 16) // center of the 32-unit bucket
    }

    // MARK: - Vocabulary Export

    /// Generate the full vocabulary as an array of (id, name, class) tuples.
    /// Useful for training pipeline data prep.
    public static func exportVocabulary() -> [(id: Int, name: String, tokenClass: String)] {
        var vocab: [(id: Int, name: String, tokenClass: String)] = []

        // NOTE_ON tokens
        for note in 0...127 {
            let name = MIDIMessage.noteName(UInt8(note))
            vocab.append((id: note, name: "NOTE_ON_\(note)_\(name)", tokenClass: "NOTE_ON"))
        }

        // NOTE_OFF tokens
        for note in 0...127 {
            let name = MIDIMessage.noteName(UInt8(note))
            vocab.append((id: 128 + note, name: "NOTE_OFF_\(note)_\(name)", tokenClass: "NOTE_OFF"))
        }

        // VEL tokens
        for bucket in 0...31 {
            let velRange = "\(bucket * 4)-\(bucket * 4 + 3)"
            vocab.append((id: 256 + bucket, name: "VEL_\(bucket)_[\(velRange)]", tokenClass: "VEL"))
        }

        // DELTA tokens
        for bucket in 0...63 {
            let ms = bucketToDelta(bucket)
            vocab.append((id: 288 + bucket, name: "DELTA_\(bucket)_\(String(format: "%.1f", ms))ms", tokenClass: "DELTA"))
        }

        // CC tokens
        for cc in 0...31 {
            for valBucket in 0...3 {
                let valRange = "\(valBucket * 32)-\(valBucket * 32 + 31)"
                vocab.append((
                    id: 352 + cc * 4 + valBucket,
                    name: "CC_\(cc)_\(valBucket)_[\(valRange)]",
                    tokenClass: "CC"
                ))
            }
        }

        // SPECIAL tokens
        vocab.append((id: 480, name: "PAD", tokenClass: "SPECIAL"))
        vocab.append((id: 481, name: "BOS", tokenClass: "SPECIAL"))
        vocab.append((id: 482, name: "EOS", tokenClass: "SPECIAL"))
        vocab.append((id: 483, name: "BAR", tokenClass: "SPECIAL"))
        vocab.append((id: 484, name: "PHRASE", tokenClass: "SPECIAL"))
        for ch in 0...15 {
            vocab.append((id: 485 + ch, name: "CHANNEL_\(ch)", tokenClass: "SPECIAL"))
        }
        // Remaining special slots (501-511) reserved
        for i in 501...511 {
            vocab.append((id: i, name: "RESERVED_\(i)", tokenClass: "SPECIAL"))
        }

        return vocab
    }

    /// Export vocabulary as JSON data.
    public static func exportVocabularyJSON() throws -> Data {
        let vocab = exportVocabulary()
        let entries = vocab.map { entry in
            ["id": entry.id, "name": entry.name, "class": entry.tokenClass] as [String: Any]
        }
        return try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
    }
}

// MARK: - Comparable helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
