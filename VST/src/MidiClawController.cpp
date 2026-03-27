#include "MidiClawController.h"
#include "MidiClawCIDs.h"
#include "MidiClawProcessor.h"

#include "pluginterfaces/base/ibstream.h"

using namespace Steinberg;
using namespace Steinberg::Vst;

namespace MidiClaw {

tresult PLUGIN_API MidiClawController::initialize(FUnknown* context) {
    tresult result = EditController::initialize(context);
    if (result != kResultOk)
        return result;

    // --- Register parameters ---

    // Bypass
    parameters.addParameter(
        STR16("Bypass"), nullptr, 1, 0.0,
        ParameterInfo::kCanAutomate | ParameterInfo::kIsBypass,
        kBypass);

    // Mode: Monitor (0), Passthrough (1), Token Round-Trip (2)
    auto* modeParam = new StringListParameter(
        STR16("Mode"), kMode, nullptr,
        ParameterInfo::kCanAutomate | ParameterInfo::kIsList);
    modeParam->appendString(STR16("Monitor"));
    modeParam->appendString(STR16("Passthrough"));
    modeParam->appendString(STR16("Token Round-Trip"));
    parameters.addParameter(modeParam);

    // Channel Filter: All (0), Ch 1-16
    auto* chParam = new StringListParameter(
        STR16("Channel Filter"), kChannelFilter, nullptr,
        ParameterInfo::kCanAutomate | ParameterInfo::kIsList);
    chParam->appendString(STR16("All Channels"));
    chParam->appendString(STR16("Channel 1"));
    chParam->appendString(STR16("Channel 2"));
    chParam->appendString(STR16("Channel 3"));
    chParam->appendString(STR16("Channel 4"));
    chParam->appendString(STR16("Channel 5"));
    chParam->appendString(STR16("Channel 6"));
    chParam->appendString(STR16("Channel 7"));
    chParam->appendString(STR16("Channel 8"));
    chParam->appendString(STR16("Channel 9"));
    chParam->appendString(STR16("Channel 10"));
    chParam->appendString(STR16("Channel 11"));
    chParam->appendString(STR16("Channel 12"));
    chParam->appendString(STR16("Channel 13"));
    chParam->appendString(STR16("Channel 14"));
    chParam->appendString(STR16("Channel 15"));
    chParam->appendString(STR16("Channel 16"));
    parameters.addParameter(chParam);

    // Velocity Scale (0.0 to 2.0, default 1.0 = normalized 0.5)
    parameters.addParameter(
        STR16("Velocity Scale"), STR16("%"), 0, 0.5,
        ParameterInfo::kCanAutomate,
        kVelocityScale);

    return kResultOk;
}

tresult PLUGIN_API MidiClawController::terminate() {
    return EditController::terminate();
}

tresult PLUGIN_API MidiClawController::setComponentState(IBStream* state) {
    if (!state) return kResultFalse;

    // Read the processor's state and set parameter values accordingly
    int32 bypassVal = 0;
    if (state->read(&bypassVal, sizeof(int32)) != kResultOk)
        return kResultFalse;
    setParamNormalized(kBypass, bypassVal ? 1.0 : 0.0);

    int32 modeVal = 0;
    if (state->read(&modeVal, sizeof(int32)) != kResultOk)
        return kResultFalse;
    setParamNormalized(kMode, static_cast<ParamValue>(modeVal) / 2.0);

    int32 chFilterVal = 0;
    if (state->read(&chFilterVal, sizeof(int32)) != kResultOk)
        return kResultFalse;
    setParamNormalized(kChannelFilter, static_cast<ParamValue>(chFilterVal) / 16.0);

    float velScaleVal = 1.0f;
    if (state->read(&velScaleVal, sizeof(float)) != kResultOk)
        return kResultFalse;
    setParamNormalized(kVelocityScale, static_cast<ParamValue>(velScaleVal) / 2.0);

    return kResultOk;
}

} // namespace MidiClaw
