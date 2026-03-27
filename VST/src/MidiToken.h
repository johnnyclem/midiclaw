#pragma once

#include <cstdint>
#include <string>
#include <algorithm>

namespace MidiClaw {

/// A single token in the MidiClaw vocabulary.
/// Raw value is uint16_t in range 0-511 (~512 base tokens).
///
/// Token classes:
///   NOTE_ON_[0-127]:   0-127    (one per MIDI note)
///   NOTE_OFF_[0-127]:  128-255  (explicit note-off)
///   VEL_[bucket]:      256-287  (32 velocity buckets, 4-unit resolution)
///   DELTA_[bucket]:    288-351  (64 time-delta buckets, log-scaled 1ms-4s)
///   CC_[num]_[bucket]: 352-479  (CC 0-31, 4 value buckets each)
///   SPECIAL:           480-511  (PAD, BOS, EOS, BAR, PHRASE, CHANNEL_0-15, etc.)
///
/// Ported from Swift MidiClawCore/Tokenizer/MidiToken.swift.
struct MidiToken {
    uint16_t rawValue;

    explicit MidiToken(uint16_t raw = 0) : rawValue(raw) {}

    bool operator==(const MidiToken& other) const { return rawValue == other.rawValue; }
    bool operator!=(const MidiToken& other) const { return rawValue != other.rawValue; }

    // -- Token Class Identification --
    bool isNoteOn()   const { return rawValue <= 127; }
    bool isNoteOff()  const { return rawValue >= 128 && rawValue <= 255; }
    bool isVelocity() const { return rawValue >= 256 && rawValue <= 287; }
    bool isDelta()    const { return rawValue >= 288 && rawValue <= 351; }
    bool isCC()       const { return rawValue >= 352 && rawValue <= 479; }
    bool isSpecial()  const { return rawValue >= 480 && rawValue <= 511; }

    // -- Data Extraction --

    /// MIDI note number (0-127) for NOTE_ON and NOTE_OFF tokens. Returns -1 if not applicable.
    int noteNumber() const {
        if (isNoteOn())  return static_cast<int>(rawValue);
        if (isNoteOff()) return static_cast<int>(rawValue - 128);
        return -1;
    }

    /// Velocity bucket index (0-31) for VEL tokens. Returns -1 if not applicable.
    int velocityBucket() const {
        if (!isVelocity()) return -1;
        return static_cast<int>(rawValue - 256);
    }

    /// Time delta bucket index (0-63) for DELTA tokens. Returns -1 if not applicable.
    int deltaBucket() const {
        if (!isDelta()) return -1;
        return static_cast<int>(rawValue - 288);
    }

    /// CC number (0-31) for CC tokens. Returns -1 if not applicable.
    int ccNumber() const {
        if (!isCC()) return -1;
        return static_cast<int>((rawValue - 352) / 4);
    }

    /// CC value bucket (0-3) for CC tokens. Returns -1 if not applicable.
    int ccValueBucket() const {
        if (!isCC()) return -1;
        return static_cast<int>((rawValue - 352) % 4);
    }

    /// Channel number (0-15) for CHANNEL tokens. Returns -1 if not applicable.
    int channelNumber() const {
        if (rawValue >= 485 && rawValue <= 500)
            return static_cast<int>(rawValue - 485);
        return -1;
    }

    // -- Factory Methods --

    static MidiToken noteOn(uint8_t note) {
        return MidiToken(static_cast<uint16_t>(note & 0x7F));
    }

    static MidiToken noteOff(uint8_t note) {
        return MidiToken(static_cast<uint16_t>(128 + (note & 0x7F)));
    }

    static MidiToken velocity(int bucket) {
        return MidiToken(static_cast<uint16_t>(256 + std::clamp(bucket, 0, 31)));
    }

    static MidiToken delta(int bucket) {
        return MidiToken(static_cast<uint16_t>(288 + std::clamp(bucket, 0, 63)));
    }

    static MidiToken controlChange(int number, int valueBucket) {
        int num = std::clamp(number, 0, 31);
        int val = std::clamp(valueBucket, 0, 3);
        return MidiToken(static_cast<uint16_t>(352 + num * 4 + val));
    }

    static MidiToken channel(uint8_t ch) {
        return MidiToken(static_cast<uint16_t>(485 + (ch & 0x0F)));
    }

    // -- Special Tokens --
    static MidiToken pad()    { return MidiToken(480); }
    static MidiToken bos()    { return MidiToken(481); }
    static MidiToken eos()    { return MidiToken(482); }
    static MidiToken bar()    { return MidiToken(483); }
    static MidiToken phrase() { return MidiToken(484); }

    // -- Vocabulary Size --
    static constexpr int kVocabularySize = 512;
};

} // namespace MidiClaw
