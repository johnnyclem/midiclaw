import Foundation

/// Decodes a sequence of MidiTokens back into MIDIEvents.
/// Reconstructs timing from DELTA tokens and velocity from VEL tokens.
public struct MidiDecoder {
    public init() {}

    /// Decode a token sequence into MIDIEvents.
    /// Starts timing from the given base timestamp (default 0).
    public func decode(_ tokens: [MidiToken], baseTimestampNs: UInt64 = 0) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        var currentTimestampNs = baseTimestampNs
        var currentChannel: UInt8 = 0
        var i = 0

        while i < tokens.count {
            let token = tokens[i]

            // Skip BOS/EOS/PAD
            if token == .bos || token == .eos || token == .pad {
                i += 1
                continue
            }

            // Delta: advance timestamp
            if token.isDelta, let bucket = token.deltaBucket {
                let deltaMs = TokenVocabulary.bucketToDelta(bucket)
                currentTimestampNs += MachTime.millisecondsToNanoseconds(deltaMs)
                i += 1
                continue
            }

            // Channel change
            if let ch = token.channelNumber {
                currentChannel = ch
                i += 1
                continue
            }

            // Note On: expect next token to be VEL
            if token.isNoteOn, let note = token.noteNumber {
                var velocity: UInt8 = 100 // default if VEL token missing
                if i + 1 < tokens.count && tokens[i + 1].isVelocity,
                   let velBucket = tokens[i + 1].velocityBucket {
                    velocity = TokenVocabulary.bucketToVelocity(velBucket)
                    i += 1 // consume the VEL token
                }
                events.append(MIDIEvent(
                    timestampNs: currentTimestampNs,
                    message: .noteOn(channel: currentChannel, note: note, velocity: velocity)
                ))
                i += 1
                continue
            }

            // Note Off
            if token.isNoteOff, let note = token.noteNumber {
                events.append(MIDIEvent(
                    timestampNs: currentTimestampNs,
                    message: .noteOff(channel: currentChannel, note: note, velocity: 0)
                ))
                i += 1
                continue
            }

            // CC
            if token.isCC, let ccNum = token.ccNumber, let valBucket = token.ccValueBucket {
                let value = TokenVocabulary.bucketToCCValue(valBucket)
                events.append(MIDIEvent(
                    timestampNs: currentTimestampNs,
                    message: .controlChange(
                        channel: currentChannel,
                        controller: UInt8(ccNum),
                        value: value
                    )
                ))
                i += 1
                continue
            }

            // BAR / PHRASE markers — skip (structural, no MIDI event)
            if token == .bar || token == .phrase {
                i += 1
                continue
            }

            // Unknown token — skip
            i += 1
        }

        return events
    }
}
