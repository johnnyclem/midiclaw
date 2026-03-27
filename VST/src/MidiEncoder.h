#pragma once

#include "MidiToken.h"
#include "TokenVocabulary.h"
#include <vector>
#include <cstdint>

namespace MidiClaw {

/// Encodes incoming MIDI bytes into MidiToken sequences.
/// Designed for real-time streaming use in a VST plugin context.
///
/// Ported from Swift MidiClawCore/Tokenizer/MidiEncoder.swift.
class MidiEncoder {
public:
    MidiEncoder() = default;

    /// Reset encoder state (call when transport restarts).
    void reset() {
        previousTimestampNs_ = 0;
        previousChannel_ = -1;
    }

    /// Encode a single MIDI event in streaming mode.
    /// Returns tokens without BOS/EOS wrappers.
    /// @param statusByte  MIDI status byte (e.g., 0x90 for Note On channel 0)
    /// @param data1       First data byte (note number, CC number, etc.)
    /// @param data2       Second data byte (velocity, CC value, etc.)
    /// @param timestampNs Timestamp in nanoseconds
    std::vector<MidiToken> encodeEvent(
        uint8_t statusByte,
        uint8_t data1,
        uint8_t data2,
        uint64_t timestampNs
    ) {
        std::vector<MidiToken> tokens;

        uint8_t msgType = statusByte & 0xF0;
        uint8_t channel = statusByte & 0x0F;

        // Emit delta token
        if (previousTimestampNs_ > 0 && timestampNs > previousTimestampNs_) {
            uint64_t deltaNs = timestampNs - previousTimestampNs_;
            double deltaMs = TokenVocabulary::nsToMs(deltaNs);
            if (deltaMs > 0.0) {
                int bucket = TokenVocabulary::deltaToBucket(deltaMs);
                tokens.push_back(MidiToken::delta(bucket));
            }
        }
        previousTimestampNs_ = timestampNs;

        // Emit channel token if changed
        if (static_cast<int>(channel) != previousChannel_) {
            tokens.push_back(MidiToken::channel(channel));
            previousChannel_ = static_cast<int>(channel);
        }

        // Emit event-specific tokens
        switch (msgType) {
            case 0x90: // Note On
                if (data2 == 0) {
                    // Note On with velocity 0 = Note Off
                    tokens.push_back(MidiToken::noteOff(data1));
                } else {
                    tokens.push_back(MidiToken::noteOn(data1));
                    int velBucket = TokenVocabulary::velocityToBucket(data2);
                    tokens.push_back(MidiToken::velocity(velBucket));
                }
                break;

            case 0x80: // Note Off
                tokens.push_back(MidiToken::noteOff(data1));
                break;

            case 0xB0: // Control Change
                if (data1 < 32) {
                    int valBucket = TokenVocabulary::ccValueToBucket(data2);
                    tokens.push_back(MidiToken::controlChange(
                        static_cast<int>(data1), valBucket));
                }
                // CC >= 32 silently dropped in v1
                break;

            default:
                // Other message types not in v1 vocabulary
                break;
        }

        return tokens;
    }

    /// Get the last timestamp used for delta calculation.
    uint64_t previousTimestampNs() const { return previousTimestampNs_; }

private:
    uint64_t previousTimestampNs_ = 0;
    int previousChannel_ = -1;
};

} // namespace MidiClaw
