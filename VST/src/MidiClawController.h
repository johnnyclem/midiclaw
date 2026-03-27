#pragma once

#include "public.sdk/source/vst/vsteditcontroller.h"

namespace MidiClaw {

/// VST3 Edit Controller component for MidiClaw.
/// Manages plugin parameters and their mapping to the UI.
class MidiClawController : public Steinberg::Vst::EditController {
public:
    MidiClawController() = default;
    ~MidiClawController() override = default;

    // -- IPluginBase --
    Steinberg::tresult PLUGIN_API initialize(FUnknown* context) override;
    Steinberg::tresult PLUGIN_API terminate() override;

    // -- EditController --
    Steinberg::tresult PLUGIN_API setComponentState(Steinberg::IBStream* state) override;

    static FUnknown* createInstance(void*) {
        return static_cast<Steinberg::Vst::IEditController*>(new MidiClawController());
    }
};

} // namespace MidiClaw
