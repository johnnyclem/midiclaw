import Foundation

/// A single token in the MidiClaw vocabulary.
/// Raw value is UInt16 in range 0-511 (~512 base tokens).
///
/// Token classes:
///   - NOTE_ON_[0-127]:   0–127    (one per MIDI note)
///   - NOTE_OFF_[0-127]:  128–255  (explicit note-off)
///   - VEL_[bucket]:      256–287  (32 velocity buckets, 4-unit resolution)
///   - DELTA_[bucket]:    288–351  (64 time-delta buckets, log-scaled 1ms–4s)
///   - CC_[num]_[bucket]: 352–479  (CC 0–31, 4 value buckets each)
///   - SPECIAL:           480–511  (PAD, BOS, EOS, BAR, PHRASE, CHANNEL_0-15, etc.)
public struct MidiToken: Hashable, Codable, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    // MARK: - Token Class Ranges

    public static let noteOnRange: ClosedRange<UInt16> = 0...127
    public static let noteOffRange: ClosedRange<UInt16> = 128...255
    public static let velocityRange: ClosedRange<UInt16> = 256...287
    public static let deltaRange: ClosedRange<UInt16> = 288...351
    public static let ccRange: ClosedRange<UInt16> = 352...479
    public static let specialRange: ClosedRange<UInt16> = 480...511

    // MARK: - Token Class Identification

    public var isNoteOn: Bool { Self.noteOnRange.contains(rawValue) }
    public var isNoteOff: Bool { Self.noteOffRange.contains(rawValue) }
    public var isVelocity: Bool { Self.velocityRange.contains(rawValue) }
    public var isDelta: Bool { Self.deltaRange.contains(rawValue) }
    public var isCC: Bool { Self.ccRange.contains(rawValue) }
    public var isSpecial: Bool { Self.specialRange.contains(rawValue) }

    // MARK: - Data Extraction

    /// MIDI note number (0-127) for NOTE_ON and NOTE_OFF tokens.
    public var noteNumber: UInt8? {
        if isNoteOn { return UInt8(rawValue) }
        if isNoteOff { return UInt8(rawValue - 128) }
        return nil
    }

    /// Velocity bucket index (0-31) for VEL tokens.
    public var velocityBucket: Int? {
        guard isVelocity else { return nil }
        return Int(rawValue - 256)
    }

    /// Time delta bucket index (0-63) for DELTA tokens.
    public var deltaBucket: Int? {
        guard isDelta else { return nil }
        return Int(rawValue - 288)
    }

    /// CC number (0-31) for CC tokens.
    public var ccNumber: Int? {
        guard isCC else { return nil }
        return Int((rawValue - 352) / 4)
    }

    /// CC value bucket (0-3) for CC tokens.
    public var ccValueBucket: Int? {
        guard isCC else { return nil }
        return Int((rawValue - 352) % 4)
    }

    // MARK: - Factory Methods

    public static func noteOn(_ note: UInt8) -> MidiToken {
        MidiToken(rawValue: UInt16(note & 0x7F))
    }

    public static func noteOff(_ note: UInt8) -> MidiToken {
        MidiToken(rawValue: 128 + UInt16(note & 0x7F))
    }

    public static func velocity(bucket: Int) -> MidiToken {
        MidiToken(rawValue: 256 + UInt16(min(max(bucket, 0), 31)))
    }

    public static func delta(bucket: Int) -> MidiToken {
        MidiToken(rawValue: 288 + UInt16(min(max(bucket, 0), 63)))
    }

    public static func controlChange(number: Int, valueBucket: Int) -> MidiToken {
        let num = min(max(number, 0), 31)
        let val = min(max(valueBucket, 0), 3)
        return MidiToken(rawValue: 352 + UInt16(num * 4 + val))
    }

    // MARK: - Special Tokens

    public static let pad     = MidiToken(rawValue: 480)
    public static let bos     = MidiToken(rawValue: 481)
    public static let eos     = MidiToken(rawValue: 482)
    public static let bar     = MidiToken(rawValue: 483)
    public static let phrase  = MidiToken(rawValue: 484)

    /// Channel tokens: 485-500 (channels 0-15).
    public static func channel(_ ch: UInt8) -> MidiToken {
        MidiToken(rawValue: 485 + UInt16(ch & 0x0F))
    }

    /// Extract channel number from a CHANNEL token (0-15), nil if not a channel token.
    public var channelNumber: UInt8? {
        guard rawValue >= 485 && rawValue <= 500 else { return nil }
        return UInt8(rawValue - 485)
    }

    // MARK: - Vocabulary Size

    public static let vocabularySize: Int = 512
}

// MARK: - CustomStringConvertible

extension MidiToken: CustomStringConvertible {
    public var description: String {
        if isNoteOn, let note = noteNumber {
            return "NOTE_ON_\(note)(\(MIDIMessage.noteName(note)))"
        }
        if isNoteOff, let note = noteNumber {
            return "NOTE_OFF_\(note)(\(MIDIMessage.noteName(note)))"
        }
        if let bucket = velocityBucket {
            return "VEL_\(bucket)"
        }
        if let bucket = deltaBucket {
            return "DELTA_\(bucket)"
        }
        if let cc = ccNumber, let val = ccValueBucket {
            return "CC_\(cc)_\(val)"
        }
        if let ch = channelNumber {
            return "CHANNEL_\(ch)"
        }
        switch self {
        case .pad: return "PAD"
        case .bos: return "BOS"
        case .eos: return "EOS"
        case .bar: return "BAR"
        case .phrase: return "PHRASE"
        default: return "SPECIAL_\(rawValue)"
        }
    }
}
