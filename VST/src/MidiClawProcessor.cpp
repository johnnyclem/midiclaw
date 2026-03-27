#include "MidiClawProcessor.h"
#include "MidiClawCIDs.h"
#include "version.h"

#include "pluginterfaces/vst/ivstevents.h"
#include "pluginterfaces/vst/ivstparameterchanges.h"
#include "pluginterfaces/base/ibstream.h"

#include <cstring>
#include <algorithm>

using namespace Steinberg;
using namespace Steinberg::Vst;

namespace MidiClaw {

MidiClawProcessor::MidiClawProcessor() {
    setControllerClass(kControllerUID);
    tokenRing_.resize(kMaxTokenRingSize);
}

MidiClawProcessor::~MidiClawProcessor() = default;

tresult PLUGIN_API MidiClawProcessor::initialize(FUnknown* context) {
    tresult result = AudioEffect::initialize(context);
    if (result != kResultOk)
        return result;

    // Add MIDI event input bus
    addEventInput(STR16("MIDI In"), 1);

    // Add MIDI event output bus
    addEventOutput(STR16("MIDI Out"), 1);

    // No audio buses — this is a pure MIDI effect
    // Add a silent stereo audio bus so hosts that require audio buses still load us
    addAudioInput(STR16("Audio In"), SpeakerArr::kStereo);
    addAudioOutput(STR16("Audio Out"), SpeakerArr::kStereo);

    return kResultOk;
}

tresult PLUGIN_API MidiClawProcessor::terminate() {
    return AudioEffect::terminate();
}

tresult PLUGIN_API MidiClawProcessor::setActive(TBool state) {
    if (state) {
        // Reset encoder state on activation
        encoder_.reset();
        totalEventsProcessed_ = 0;
        totalTokensGenerated_ = 0;
        tokenRingHead_ = 0;
        tokenRingCount_ = 0;
    }
    return AudioEffect::setActive(state);
}

tresult PLUGIN_API MidiClawProcessor::setupProcessing(ProcessSetup& newSetup) {
    return AudioEffect::setupProcessing(newSetup);
}

tresult PLUGIN_API MidiClawProcessor::setBusArrangements(
    SpeakerArrangement* inputs, int32 numIns,
    SpeakerArrangement* outputs, int32 numOuts)
{
    // Accept stereo or mono for the passthrough audio bus
    if (numIns == 1 && numOuts == 1) {
        if (inputs[0] == SpeakerArr::kStereo && outputs[0] == SpeakerArr::kStereo)
            return AudioEffect::setBusArrangements(inputs, numIns, outputs, numOuts);
        if (inputs[0] == SpeakerArr::kMono && outputs[0] == SpeakerArr::kMono)
            return AudioEffect::setBusArrangements(inputs, numIns, outputs, numOuts);
    }
    return kResultFalse;
}

tresult PLUGIN_API MidiClawProcessor::canProcessSampleSize(int32 symbolicSampleSize) {
    // Support both 32-bit and 64-bit audio (even though we don't process audio)
    if (symbolicSampleSize == kSample32 || symbolicSampleSize == kSample64)
        return kResultTrue;
    return kResultFalse;
}

tresult PLUGIN_API MidiClawProcessor::process(ProcessData& data) {
    // --- Handle parameter changes ---
    if (data.inputParameterChanges) {
        int32 numParamsChanged = data.inputParameterChanges->getParameterCount();
        for (int32 i = 0; i < numParamsChanged; i++) {
            IParamValueQueue* paramQueue = data.inputParameterChanges->getParameterData(i);
            if (!paramQueue) continue;

            ParamValue value;
            int32 sampleOffset;
            int32 numPoints = paramQueue->getPointCount();

            // Use the last point value
            if (paramQueue->getPoint(numPoints - 1, sampleOffset, value) == kResultTrue) {
                switch (paramQueue->getParameterId()) {
                    case kBypass:
                        bypass_ = (value >= 0.5);
                        break;
                    case kMode:
                        mode_ = static_cast<int>(value * 2.0 + 0.5);  // 0, 1, or 2
                        break;
                    case kChannelFilter:
                        channelFilter_ = static_cast<int>(value * 16.0 + 0.5);  // 0-16
                        break;
                    case kVelocityScale:
                        velocityScale_ = static_cast<float>(value * 2.0);  // 0.0-2.0
                        break;
                    default:
                        break;
                }
            }
        }
    }

    // --- Pass through audio silently ---
    if (data.numOutputs > 0 && data.outputs[0].numChannels > 0) {
        for (int32 ch = 0; ch < data.outputs[0].numChannels; ch++) {
            if (data.numInputs > 0 && data.inputs[0].numChannels > ch) {
                // Copy input to output
                if (data.symbolicSampleSize == kSample32) {
                    memcpy(data.outputs[0].channelBuffers32[ch],
                           data.inputs[0].channelBuffers32[ch],
                           sizeof(float) * data.numSamples);
                } else {
                    memcpy(data.outputs[0].channelBuffers64[ch],
                           data.inputs[0].channelBuffers64[ch],
                           sizeof(double) * data.numSamples);
                }
            } else {
                // Silence output
                if (data.symbolicSampleSize == kSample32) {
                    memset(data.outputs[0].channelBuffers32[ch], 0,
                           sizeof(float) * data.numSamples);
                } else {
                    memset(data.outputs[0].channelBuffers64[ch], 0,
                           sizeof(double) * data.numSamples);
                }
            }
        }
    }

    // --- Process MIDI events ---
    IEventList* inputEvents = data.inputEvents;
    IEventList* outputEvents = data.outputEvents;

    if (inputEvents && outputEvents) {
        processMidiEvents(inputEvents, outputEvents, data.numSamples);
    }

    return kResultOk;
}

void MidiClawProcessor::processMidiEvents(
    IEventList* inputEvents,
    IEventList* outputEvents,
    int32_t numSamples)
{
    int32 eventCount = inputEvents->getEventCount();
    if (eventCount == 0) return;

    bool isBypassed = bypass_.load();
    Mode currentMode = static_cast<Mode>(mode_.load());
    int chFilter = channelFilter_.load();
    float velScale = velocityScale_.load();

    for (int32 i = 0; i < eventCount; i++) {
        Event event;
        if (inputEvents->getEvent(i, event) != kResultOk)
            continue;

        // Only process note and MIDI CC events
        bool isMidiEvent = (event.type == Event::kNoteOnEvent ||
                            event.type == Event::kNoteOffEvent ||
                            event.type == Event::kLegacyMIDICCOutEvent);

        if (!isMidiEvent) {
            // Pass through non-MIDI events unchanged
            outputEvents->addEvent(event);
            continue;
        }

        // Apply channel filter
        if (chFilter > 0) {
            int16 eventChannel = -1;
            if (event.type == Event::kNoteOnEvent)
                eventChannel = event.noteOn.channel;
            else if (event.type == Event::kNoteOffEvent)
                eventChannel = event.noteOff.channel;

            if (eventChannel >= 0 && eventChannel != (chFilter - 1))
                continue;  // Filter out this event
        }

        // --- Bypass mode: pass through unchanged ---
        if (isBypassed) {
            outputEvents->addEvent(event);
            continue;
        }

        // --- Tokenize the event ---
        uint8_t statusByte = 0;
        uint8_t data1 = 0;
        uint8_t data2 = 0;

        if (event.type == Event::kNoteOnEvent) {
            statusByte = 0x90 | (event.noteOn.channel & 0x0F);
            data1 = static_cast<uint8_t>(event.noteOn.pitch & 0x7F);
            data2 = static_cast<uint8_t>(event.noteOn.velocity * 127.0f);
        } else if (event.type == Event::kNoteOffEvent) {
            statusByte = 0x80 | (event.noteOff.channel & 0x0F);
            data1 = static_cast<uint8_t>(event.noteOff.pitch & 0x7F);
            data2 = static_cast<uint8_t>(event.noteOff.velocity * 127.0f);
        } else if (event.type == Event::kLegacyMIDICCOutEvent) {
            statusByte = event.midiCCOut.controlNumber < 128
                ? (0xB0 | (event.midiCCOut.channel & 0x0F))
                : event.midiCCOut.controlNumber;
            data1 = event.midiCCOut.value;
            data2 = event.midiCCOut.value2;
        }

        // Calculate timestamp in nanoseconds from sample offset
        uint64_t timestampNs = 0;
        if (processSetup.sampleRate > 0) {
            double sampleTimeMs = (static_cast<double>(event.sampleOffset) /
                                   processSetup.sampleRate) * 1000.0;
            timestampNs = encoder_.previousTimestampNs() +
                          TokenVocabulary::msToNs(sampleTimeMs);
        }

        // Encode to tokens
        auto tokens = encoder_.encodeEvent(statusByte, data1, data2, timestampNs);

        // Store tokens in ring buffer
        if (!tokens.empty()) {
            std::lock_guard<std::mutex> lock(tokenRingMutex_);
            for (const auto& token : tokens) {
                tokenRing_[tokenRingHead_] = token;
                tokenRingHead_ = (tokenRingHead_ + 1) % kMaxTokenRingSize;
                if (tokenRingCount_ < kMaxTokenRingSize)
                    tokenRingCount_++;
            }
            totalTokensGenerated_ += tokens.size();
        }

        totalEventsProcessed_++;

        // --- Output based on mode ---
        switch (currentMode) {
            case Mode::Monitor:
            case Mode::Passthrough: {
                // Pass through the original event, with optional velocity scaling
                Event outEvent = event;

                if (currentMode == Mode::Passthrough) {
                    if (outEvent.type == Event::kNoteOnEvent) {
                        float scaled = outEvent.noteOn.velocity * velScale;
                        outEvent.noteOn.velocity = std::clamp(scaled, 0.0f, 1.0f);
                    }
                }

                outputEvents->addEvent(outEvent);
                break;
            }

            case Mode::TokenRoundTrip: {
                // Encode to tokens, then decode back to MIDI.
                // This is a lossy round-trip (velocity/timing quantization).
                auto decoded = decoder_.decode(tokens);
                for (const auto& dec : decoded) {
                    Event outEvent = {};
                    outEvent.busIndex = 0;
                    outEvent.sampleOffset = event.sampleOffset;
                    outEvent.ppqPosition = event.ppqPosition;
                    outEvent.flags = Event::kIsLive;

                    uint8_t msgType = dec.bytes[0] & 0xF0;
                    uint8_t channel = dec.bytes[0] & 0x0F;

                    if (msgType == 0x90 && dec.bytes[2] > 0) {
                        outEvent.type = Event::kNoteOnEvent;
                        outEvent.noteOn.channel = channel;
                        outEvent.noteOn.pitch = dec.bytes[1];
                        outEvent.noteOn.velocity = static_cast<float>(
                            scaleVelocity(dec.bytes[2])) / 127.0f;
                        outEvent.noteOn.noteId = -1;
                        outEvent.noteOn.length = 0;
                        outEvent.noteOn.tuning = 0.0f;
                        outputEvents->addEvent(outEvent);
                    } else if (msgType == 0x80 || (msgType == 0x90 && dec.bytes[2] == 0)) {
                        outEvent.type = Event::kNoteOffEvent;
                        outEvent.noteOff.channel = channel;
                        outEvent.noteOff.pitch = dec.bytes[1];
                        outEvent.noteOff.velocity = 0.0f;
                        outEvent.noteOff.noteId = -1;
                        outEvent.noteOff.tuning = 0.0f;
                        outputEvents->addEvent(outEvent);
                    } else if (msgType == 0xB0) {
                        outEvent.type = Event::kLegacyMIDICCOutEvent;
                        outEvent.midiCCOut.channel = channel;
                        outEvent.midiCCOut.controlNumber = dec.bytes[1];
                        outEvent.midiCCOut.value = dec.bytes[2];
                        outEvent.midiCCOut.value2 = 0;
                        outputEvents->addEvent(outEvent);
                    }
                }
                break;
            }
        }
    }
}

uint8_t MidiClawProcessor::scaleVelocity(uint8_t velocity) const {
    float velScale = velocityScale_.load();
    float scaled = static_cast<float>(velocity) * velScale;
    return static_cast<uint8_t>(std::clamp(static_cast<int>(scaled + 0.5f), 0, 127));
}

// --- State persistence ---

tresult PLUGIN_API MidiClawProcessor::setState(IBStream* state) {
    if (!state) return kResultFalse;

    // Read bypass
    int32 bypassVal = 0;
    if (state->read(&bypassVal, sizeof(int32)) != kResultOk)
        return kResultFalse;
    bypass_ = (bypassVal != 0);

    // Read mode
    int32 modeVal = 0;
    if (state->read(&modeVal, sizeof(int32)) != kResultOk)
        return kResultFalse;
    mode_ = modeVal;

    // Read channel filter
    int32 chFilterVal = 0;
    if (state->read(&chFilterVal, sizeof(int32)) != kResultOk)
        return kResultFalse;
    channelFilter_ = chFilterVal;

    // Read velocity scale
    float velScaleVal = 1.0f;
    if (state->read(&velScaleVal, sizeof(float)) != kResultOk)
        return kResultFalse;
    velocityScale_ = velScaleVal;

    return kResultOk;
}

tresult PLUGIN_API MidiClawProcessor::getState(IBStream* state) {
    if (!state) return kResultFalse;

    int32 bypassVal = bypass_.load() ? 1 : 0;
    state->write(&bypassVal, sizeof(int32));

    int32 modeVal = mode_.load();
    state->write(&modeVal, sizeof(int32));

    int32 chFilterVal = channelFilter_.load();
    state->write(&chFilterVal, sizeof(int32));

    float velScaleVal = velocityScale_.load();
    state->write(&velScaleVal, sizeof(float));

    return kResultOk;
}

} // namespace MidiClaw
