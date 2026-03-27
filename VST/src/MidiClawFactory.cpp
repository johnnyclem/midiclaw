#include "public.sdk/source/main/pluginfactory.h"
#include "MidiClawCIDs.h"
#include "MidiClawProcessor.h"
#include "MidiClawController.h"
#include "version.h"

#include "pluginterfaces/vst/ivstaudioprocessor.h"

#define stringPluginName "MidiClaw"

using namespace Steinberg::Vst;

BEGIN_FACTORY_DEF(
    MIDICLAW_VST_VENDOR,
    MIDICLAW_VST_URL,
    MIDICLAW_VST_EMAIL)

    // Register the Processor component
    DEF_CLASS2(
        INLINE_UID_FROM_FUID(MidiClaw::kProcessorUID),
        PClassInfo::kManyInstances,
        kVstAudioEffectClass,
        stringPluginName,
        Vst::kDistributable,
        Vst::PlugType::kInstrumentSynth,  // Hosts show this in instrument/MIDI effect slots
        MIDICLAW_VST_VERSION_STR,
        kVstVersionString,
        MidiClaw::MidiClawProcessor::createInstance)

    // Register the Controller component
    DEF_CLASS2(
        INLINE_UID_FROM_FUID(MidiClaw::kControllerUID),
        PClassInfo::kManyInstances,
        kVstComponentControllerClass,
        stringPluginName "Controller",
        0,  // not used for controllers
        "",
        MIDICLAW_VST_VERSION_STR,
        kVstVersionString,
        MidiClaw::MidiClawController::createInstance)

END_FACTORY
