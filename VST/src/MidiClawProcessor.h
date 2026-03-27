#pragma once

#include "public.sdk/source/vst/vstaudioeffect.h"
#include "MidiEncoder.h"
#include "MidiDecoder.h"
#include "MidiToken.h"

#include <vector>
#include <mutex>
#include <atomic>

namespace MidiClaw {

/// Parameter IDs exposed by the MidiClaw VST3 plugin.
enum ParamID : Steinberg::Vst::ParamID {
    kBypass = 0,          // Bypass toggle
    kMode,                // Operating mode: 0=Monitor, 1=Passthrough, 2=TokenRoundTrip
    kChannelFilter,       // Channel filter: 0=All, 1-16=specific channel
    kVelocityScale,       // Velocity scaling factor (0.0 - 2.0, default 1.0)
    kTokenStreamSize,     // Number of recent tokens to keep in the ring buffer
    kNumParams
};

/// Operating modes for the MIDI effect.
enum class Mode {
    Monitor = 0,        // Observe and tokenize, pass MIDI through unchanged
    Passthrough,        // Pass through with velocity/channel transformations
    TokenRoundTrip      // Encode to tokens then decode back (lossy test mode)
};

/// VST3 Audio Processor component for MidiClaw.
/// Processes MIDI input through the MidiClaw tokenizer and outputs MIDI.
class MidiClawProcessor : public Steinberg::Vst::AudioEffect {
public:
    MidiClawProcessor();
    ~MidiClawProcessor() override;

    // -- IPluginBase --
    Steinberg::tresult PLUGIN_API initialize(FUnknown* context) override;
    Steinberg::tresult PLUGIN_API terminate() override;

    // -- IAudioProcessor --
    Steinberg::tresult PLUGIN_API setActive(Steinberg::TBool state) override;
    Steinberg::tresult PLUGIN_API setupProcessing(
        Steinberg::Vst::ProcessSetup& newSetup) override;
    Steinberg::tresult PLUGIN_API setBusArrangements(
        Steinberg::Vst::SpeakerArrangement* inputs, Steinberg::int32 numIns,
        Steinberg::Vst::SpeakerArrangement* outputs, Steinberg::int32 numOuts) override;
    Steinberg::tresult PLUGIN_API process(
        Steinberg::Vst::ProcessData& data) override;
    Steinberg::tresult PLUGIN_API canProcessSampleSize(
        Steinberg::int32 symbolicSampleSize) override;

    // -- IComponent --
    Steinberg::tresult PLUGIN_API setState(Steinberg::IBStream* state) override;
    Steinberg::tresult PLUGIN_API getState(Steinberg::IBStream* state) override;

    static FUnknown* createInstance(void*) {
        return static_cast<Steinberg::Vst::IAudioProcessor*>(new MidiClawProcessor());
    }

private:
    // Process MIDI events from input event list, tokenize, and write to output
    void processMidiEvents(Steinberg::Vst::IEventList* inputEvents,
                           Steinberg::Vst::IEventList* outputEvents,
                           int32_t numSamples);

    // Apply velocity scaling to a MIDI note event
    uint8_t scaleVelocity(uint8_t velocity) const;

    // Parameters (atomic for thread-safe access from process thread)
    std::atomic<bool>  bypass_{false};
    std::atomic<int>   mode_{0};
    std::atomic<int>   channelFilter_{0};    // 0 = all channels
    std::atomic<float> velocityScale_{1.0f};

    // Tokenizer state
    MidiEncoder encoder_;
    MidiDecoder decoder_;

    // Token ring buffer for monitoring (recent tokens)
    static constexpr size_t kMaxTokenRingSize = 256;
    std::vector<MidiToken> tokenRing_;
    size_t tokenRingHead_ = 0;
    size_t tokenRingCount_ = 0;
    std::mutex tokenRingMutex_;

    // Statistics
    std::atomic<uint64_t> totalEventsProcessed_{0};
    std::atomic<uint64_t> totalTokensGenerated_{0};
};

} // namespace MidiClaw
