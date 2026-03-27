#pragma once

#include "MidiToken.h"
#include "TokenVocabulary.h"
#include <vector>
#include <cstdint>

namespace MidiClaw {

/// A decoded MIDI event with raw bytes and timing.
struct DecodedMidiEvent {
    uint64_t timestampNs;
    uint8_t  bytes[3];
    int      byteCount;  // 1, 2, or 3
};

/// Decodes MidiToken sequences back into MIDI byte events.
/// Reconstructs timing from DELTA tokens and velocity from VEL tokens.
///
/// Ported from Swift MidiClawCore/Tokenizer/MidiDecoder.swift.
class MidiDecoder {
public:
    MidiDecoder() = default;

    /// Decode a token sequence into MIDI events.
    /// @param tokens         Array of tokens to decode
    /// @param count          Number of tokens
    /// @param baseTimestampNs Starting timestamp
    std::vector<DecodedMidiEvent> decode(
        const MidiToken* tokens,
        size_t count,
        uint64_t baseTimestampNs = 0
    ) const {
        std::vector<DecodedMidiEvent> events;
        uint64_t currentTimestampNs = baseTimestampNs;
        uint8_t currentChannel = 0;
        size_t i = 0;

        while (i < count) {
            const MidiToken& token = tokens[i];

            // Skip BOS/EOS/PAD
            if (token == MidiToken::bos() || token == MidiToken::eos() || token == MidiToken::pad()) {
                i++;
                continue;
            }

            // Delta: advance timestamp
            if (token.isDelta()) {
                int bucket = token.deltaBucket();
                if (bucket >= 0) {
                    double deltaMs = TokenVocabulary::bucketToDelta(bucket);
                    currentTimestampNs += TokenVocabulary::msToNs(deltaMs);
                }
                i++;
                continue;
            }

            // Channel change
            int ch = token.channelNumber();
            if (ch >= 0) {
                currentChannel = static_cast<uint8_t>(ch);
                i++;
                continue;
            }

            // Note On: expect next token to be VEL
            if (token.isNoteOn()) {
                int note = token.noteNumber();
                uint8_t velocity = 100; // default if VEL token missing
                if (i + 1 < count && tokens[i + 1].isVelocity()) {
                    int velBucket = tokens[i + 1].velocityBucket();
                    if (velBucket >= 0)
                        velocity = TokenVocabulary::bucketToVelocity(velBucket);
                    i++; // consume VEL token
                }
                DecodedMidiEvent evt;
                evt.timestampNs = currentTimestampNs;
                evt.bytes[0] = 0x90 | (currentChannel & 0x0F);
                evt.bytes[1] = static_cast<uint8_t>(note & 0x7F);
                evt.bytes[2] = velocity;
                evt.byteCount = 3;
                events.push_back(evt);
                i++;
                continue;
            }

            // Note Off
            if (token.isNoteOff()) {
                int note = token.noteNumber();
                DecodedMidiEvent evt;
                evt.timestampNs = currentTimestampNs;
                evt.bytes[0] = 0x80 | (currentChannel & 0x0F);
                evt.bytes[1] = static_cast<uint8_t>(note & 0x7F);
                evt.bytes[2] = 0;
                evt.byteCount = 3;
                events.push_back(evt);
                i++;
                continue;
            }

            // CC
            if (token.isCC()) {
                int ccNum = token.ccNumber();
                int valBucket = token.ccValueBucket();
                if (ccNum >= 0 && valBucket >= 0) {
                    uint8_t value = TokenVocabulary::bucketToCCValue(valBucket);
                    DecodedMidiEvent evt;
                    evt.timestampNs = currentTimestampNs;
                    evt.bytes[0] = 0xB0 | (currentChannel & 0x0F);
                    evt.bytes[1] = static_cast<uint8_t>(ccNum & 0x7F);
                    evt.bytes[2] = value;
                    evt.byteCount = 3;
                    events.push_back(evt);
                }
                i++;
                continue;
            }

            // BAR / PHRASE / unknown — skip
            i++;
        }

        return events;
    }

    /// Convenience: decode from a vector.
    std::vector<DecodedMidiEvent> decode(
        const std::vector<MidiToken>& tokens,
        uint64_t baseTimestampNs = 0
    ) const {
        return decode(tokens.data(), tokens.size(), baseTimestampNs);
    }
};

} // namespace MidiClaw
