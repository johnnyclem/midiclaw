#pragma once

#include <cstdint>
#include <cmath>
#include <algorithm>

namespace MidiClaw {

/// Centralizes all bucket quantization math for the MidiToken vocabulary.
/// Ported from Swift MidiClawCore/Tokenizer/TokenVocabulary.swift.
class TokenVocabulary {
public:
    // -- Velocity Buckets (32 buckets, 4-unit resolution) --

    /// Map MIDI velocity (0-127) to bucket index (0-31).
    static int velocityToBucket(uint8_t velocity) {
        return static_cast<int>(velocity) / 4;
    }

    /// Map velocity bucket (0-31) to representative MIDI velocity.
    static uint8_t bucketToVelocity(int bucket) {
        int clamped = std::clamp(bucket, 0, 31);
        return static_cast<uint8_t>(clamped * 4 + 2);
    }

    // -- Time Delta Buckets (64 buckets, log-scaled 1ms-4000ms) --

    /// Map a time delta in milliseconds to bucket index (0-63).
    static int deltaToBucket(double deltaMs) {
        if (deltaMs <= 0.0) return 0;
        double clamped = std::clamp(deltaMs, 1.0, 4000.0);
        double bucket = 63.0 * std::log(clamped) / kDeltaLogBase;
        return std::clamp(static_cast<int>(std::round(bucket)), 0, 63);
    }

    /// Map delta bucket (0-63) to representative time delta in milliseconds.
    static double bucketToDelta(int bucket) {
        double clamped = static_cast<double>(std::clamp(bucket, 0, 63));
        return std::exp(clamped / 63.0 * kDeltaLogBase);
    }

    // -- CC Value Buckets (4 buckets per CC number) --

    /// Map CC value (0-127) to bucket index (0-3).
    static int ccValueToBucket(uint8_t value) {
        return static_cast<int>(value) / 32;
    }

    /// Map CC value bucket (0-3) to representative CC value.
    static uint8_t bucketToCCValue(int bucket) {
        int clamped = std::clamp(bucket, 0, 3);
        return static_cast<uint8_t>(clamped * 32 + 16);
    }

    // -- Timing Conversion --

    /// Convert nanoseconds to milliseconds.
    static double nsToMs(uint64_t ns) {
        return static_cast<double>(ns) / 1000000.0;
    }

    /// Convert milliseconds to nanoseconds.
    static uint64_t msToNs(double ms) {
        return static_cast<uint64_t>(ms * 1000000.0);
    }

private:
    static constexpr double kDeltaLogBase = 8.29404964; // log(4000.0)
};

} // namespace MidiClaw
