#if os(macOS)
import AudioToolbox
import AVFoundation
import CoreMIDI
import Foundation
import MidiClawCore

/// AUv3 MIDI effect AudioUnit that processes MIDI through MidiClaw's tokenizer.
///
/// This plugin operates as a `kAudioUnitType_MIDIProcessor` (aumi), sitting inline
/// on a MIDI track in a DAW. It receives MIDI events, runs them through MidiClaw's
/// tokenizer pipeline, and outputs MIDI according to the selected mode.
///
/// Modes:
/// - **Monitor**: Observe and tokenize MIDI without producing output.
/// - **Passthrough**: Forward MIDI with optional velocity scaling.
/// - **Transform**: Round-trip through tokenizer (encode → decode) to demonstrate fidelity.
public final class MidiClawAudioUnit: AUAudioUnit {
    // MARK: - Properties

    private let processor = MidiClawAUProcessor()
    private var _parameterTree: AUParameterTree!
    private var _outputBusArray: AUAudioUnitBusArray!

    /// Block provided by the host to receive MIDI output events.
    private var midiOutputBlock: AUMIDIOutputEventBlock?

    /// Observable token stream for the AU view.
    public var recentTokens: [MidiToken] {
        processor.recentTokens()
    }

    /// Current operating mode.
    public var mode: MidiClawAUMode {
        get { processor.mode }
        set { processor.mode = newValue }
    }

    // MARK: - Initialization

    public override init(
        componentDescription: AudioComponentDescription,
        options: AudioComponentInstantiationOptions = []
    ) throws {
        try super.init(componentDescription: componentDescription, options: options)

        _parameterTree = MidiClawAUParameterDefinitions.createParameterTree()

        // Observe parameter changes from the host / UI
        _parameterTree.implementorValueObserver = { [weak self] param, value in
            self?.handleParameterChange(address: param.address, value: value)
        }

        _parameterTree.implementorValueProvider = { [weak self] param -> AUValue in
            self?.currentParameterValue(address: param.address) ?? 0
        }

        // Create a silent output bus (required even for MIDI-only AUs)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let outputBus = try AUAudioUnitBus(format: format)
        _outputBusArray = AUAudioUnitBusArray(
            audioUnit: self,
            busType: .output,
            busses: [outputBus]
        )

        Log.midi.info("MidiClaw AudioUnit initialized")
    }

    // MARK: - AUAudioUnit Overrides

    public override var parameterTree: AUParameterTree? {
        get { _parameterTree }
        set { /* ignored — tree is immutable after init */ }
    }

    public override var outputBusses: AUAudioUnitBusArray {
        _outputBusArray
    }

    public override var channelCapabilities: [NSNumber]? {
        // Stereo output (even though we only process MIDI)
        [2, 2]
    }

    public override var isMusicDeviceOrEffect: Bool { true }

    public override var midiOutputNames: [String] {
        ["MidiClaw MIDI Out"]
    }

    public override var midiOutputEventBlock: AUMIDIOutputEventBlock? {
        get { midiOutputBlock }
        set { midiOutputBlock = newValue }
    }

    public override var supportsUserPresets: Bool { true }

    public override var fullState: [String: Any]? {
        get {
            var state = super.fullState ?? [:]
            state["mode"] = processor.mode.rawValue
            state["channelFilter"] = processor.channelFilter
            state["velocityScale"] = processor.velocityScale
            state["tokenMonitor"] = processor.tokenMonitorEnabled
            return state
        }
        set {
            super.fullState = newValue
            if let dict = newValue {
                if let mode = dict["mode"] as? Int {
                    processor.mode = MidiClawAUMode(rawValue: mode) ?? .passthrough
                }
                if let ch = dict["channelFilter"] as? Int {
                    processor.channelFilter = ch
                }
                if let vel = dict["velocityScale"] as? Float {
                    processor.velocityScale = vel
                }
                if let mon = dict["tokenMonitor"] as? Bool {
                    processor.tokenMonitorEnabled = mon
                }
            }
        }
    }

    // MARK: - Rendering

    public override var internalRenderBlock: AUInternalRenderBlock {
        // Capture processor and midi output block for the render closure.
        // This closure runs on the real-time audio thread.
        let processor = self.processor

        return { [weak self] actionFlags, timestamp, frameCount, outputBusNumber,
                  outputData, renderEvent, pullInputBlock in

            // Silence audio output buffers (we're MIDI-only)
            let ablPointer = UnsafeMutableAudioBufferListPointer(outputData)
            for buffer in ablPointer {
                if let data = buffer.mData {
                    memset(data, 0, Int(buffer.mDataByteSize))
                }
            }

            // Process any incoming MIDI events from the render event list
            guard let self = self else { return noErr }
            self.processMIDIRenderEvents(renderEvent, processor: processor)

            return noErr
        }
    }

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        processor.reset()
        Log.midi.info("MidiClaw AU render resources allocated")
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        processor.reset()
        Log.midi.info("MidiClaw AU render resources deallocated")
    }

    // MARK: - MIDI Event Handling

    /// Handle MIDI events received directly (not through render cycle).
    /// Called by the host for real-time MIDI input.
    public func handle(
        _ event: AUMIDIEvent,
        eventSampleTime: AUEventSampleTime,
        cable: UInt8
    ) {
        let bytes = extractBytes(from: event)
        let timestampNs = MachTime.nowNanoseconds
        let outputEvents = processor.process(bytes: bytes, timestampNs: timestampNs)

        // Send processed events to MIDI output
        if let outputBlock = midiOutputBlock {
            for outputEvent in outputEvents {
                let rawBytes = outputEvent.message.rawBytes
                sendMIDIOutput(bytes: rawBytes, sampleTime: eventSampleTime,
                               cable: cable, outputBlock: outputBlock)
            }
        }
    }

    // MARK: - Private Helpers

    private func processMIDIRenderEvents(
        _ renderEvent: UnsafePointer<AURenderEvent>?,
        processor: MidiClawAUProcessor
    ) {
        var event: UnsafePointer<AURenderEvent>? = renderEvent
        while let currentEvent = event {
            if currentEvent.pointee.head.eventType == .MIDI {
                let midiEvent = currentEvent.pointee.MIDI
                let bytes = withUnsafeBytes(of: midiEvent.data) { bufPtr in
                    Array(bufPtr.prefix(Int(midiEvent.length)))
                }
                let timestampNs = MachTime.nowNanoseconds
                let outputEvents = processor.process(bytes: bytes, timestampNs: timestampNs)

                if let outputBlock = midiOutputBlock {
                    for outputEvent in outputEvents {
                        let rawBytes = outputEvent.message.rawBytes
                        sendMIDIOutput(
                            bytes: rawBytes,
                            sampleTime: midiEvent.eventSampleTime,
                            cable: midiEvent.cable,
                            outputBlock: outputBlock
                        )
                    }
                }
            }
            event = UnsafePointer(currentEvent.pointee.head.next)
        }
    }

    private func extractBytes(from event: AUMIDIEvent) -> [UInt8] {
        withUnsafeBytes(of: event.data) { bufPtr in
            Array(bufPtr.prefix(Int(event.length)))
        }
    }

    private func sendMIDIOutput(
        bytes: [UInt8],
        sampleTime: AUEventSampleTime,
        cable: UInt8,
        outputBlock: AUMIDIOutputEventBlock
    ) {
        guard !bytes.isEmpty else { return }
        bytes.withUnsafeBufferPointer { bufPtr in
            guard let baseAddress = bufPtr.baseAddress else { return }
            _ = outputBlock(sampleTime, cable, bytes.count, baseAddress)
        }
    }

    private func handleParameterChange(address: AUParameterAddress, value: AUValue) {
        guard let param = MidiClawAUParameterAddress(rawValue: address) else { return }
        switch param {
        case .mode:
            processor.mode = MidiClawAUMode(rawValue: Int(value)) ?? .passthrough
        case .channelFilter:
            processor.channelFilter = Int(value)
        case .velocityScale:
            processor.velocityScale = value
        case .tokenMonitor:
            processor.tokenMonitorEnabled = value > 0.5
        }
    }

    private func currentParameterValue(address: AUParameterAddress) -> AUValue {
        guard let param = MidiClawAUParameterAddress(rawValue: address) else { return 0 }
        switch param {
        case .mode:
            return AUValue(processor.mode.rawValue)
        case .channelFilter:
            return AUValue(processor.channelFilter)
        case .velocityScale:
            return AUValue(processor.velocityScale)
        case .tokenMonitor:
            return processor.tokenMonitorEnabled ? 1.0 : 0.0
        }
    }
}

// MARK: - Registration

extension MidiClawAudioUnit {
    /// Register the AudioUnit component with the system.
    /// Call this once at app launch (from the host app containing the AU extension).
    public static func registerAU() {
        AUAudioUnit.registerSubclass(
            MidiClawAudioUnit.self,
            as: AudioComponentDescription.midiClaw,
            name: "MidiClaw",
            version: 1
        )
        Log.midi.info("MidiClaw AudioUnit registered")
    }
}
#endif
