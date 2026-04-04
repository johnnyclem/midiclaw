#if os(macOS)
import SwiftUI
import AVFoundation
import AudioToolbox
import MidiClawCore

/// View for hosting and testing the MidiClaw AUv3 plugin.
struct AUHostView: View {
    @ObservedObject var appState: AppState
    @State private var discoveredAUs: [AVAudioUnitComponent] = []
    @State private var selectedAU: AVAudioUnitComponent?
    @State private var loadedAU: AVAudioUnit?
    @State private var statusMessage = "Ready to scan for Audio Units"
    @State private var isScanning = false
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            auHeader

            Divider()

            HSplitView {
                // Left: AU Browser
                auBrowserPanel
                    .frame(minWidth: 250, maxWidth: 350)

                // Right: AU Details & Testing
                auDetailPanel
                    .frame(minWidth: 400)
            }
        }
    }

    private var auHeader: some View {
        HStack {
            Image(systemName: "puzzlepiece.extension")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading) {
                Text("Audio Unit Host")
                    .font(.headline)
                Text("Register, discover, and test AUv3 plugins")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Button {
                registerAU()
            } label: {
                Label("Register AU", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)

            Button {
                scanForAUs()
            } label: {
                Label("Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScanning)
        }
        .padding()
    }

    // MARK: - AU Browser

    private var auBrowserPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Discovered Audio Units")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            if discoveredAUs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No Audio Units found")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("Click 'Scan' to discover installed AUv3 plugins")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(discoveredAUs, id: \.audioComponentDescription.componentSubType, selection: $selectedAU) { component in
                    AUComponentRow(component: component)
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - AU Detail Panel

    private var auDetailPanel: some View {
        VStack(spacing: 16) {
            if let selected = selectedAU {
                auDetailView(for: selected)
            } else {
                placeholderDetail
            }
        }
        .padding()
    }

    private var placeholderDetail: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Select an Audio Unit")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Choose an AU from the list to view details and test it")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    private func auDetailView(for component: AVAudioUnitComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // AU Info
            GroupBox("Audio Unit Info") {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Name", value: component.name)
                    InfoRow(label: "Manufacturer", value: component.manufacturerName)
                    InfoRow(label: "Type", value: auTypeName(component.audioComponentDescription.componentType))
                    InfoRow(label: "SubType", value: fourCharCode(component.audioComponentDescription.componentSubType))
                    InfoRow(label: "Version", value: "\(component.version)")
                    InfoRow(label: "Sandboxed", value: component.isSandboxSafe ? "Yes" : "No")
                }
                .padding(4)
            }

            // Load & Test
            GroupBox("Testing") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button {
                            loadAudioUnit(component)
                        } label: {
                            Label("Load Audio Unit", systemImage: "play.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading)

                        if loadedAU != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Loaded")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    if loadedAU != nil {
                        Button {
                            sendTestMIDI()
                        } label: {
                            Label("Send Test Note (C4)", systemImage: "music.note")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            sendTestScale()
                        } label: {
                            Label("Send C Major Scale", systemImage: "music.note.list")
                        }
                        .buttonStyle(.bordered)
                    }

                    // Status
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(4)
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private func registerAU() {
        statusMessage = "To register the MidiClaw AU, build the AUv3 app extension target in Xcode and run it once. macOS will register it automatically."
    }

    private func scanForAUs() {
        isScanning = true
        statusMessage = "Scanning for Audio Units..."

        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_MIDIProcessor,
            componentSubType: 0,
            componentManufacturer: 0,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        AVAudioUnitComponentManager.shared().components(matching: desc).forEach { _ in }

        // Also scan for all music effects and instruments
        let allDesc = AudioComponentDescription(
            componentType: 0,
            componentSubType: 0,
            componentManufacturer: 0,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        let all = AVAudioUnitComponentManager.shared().components(matching: allDesc)

        // Filter to MIDI processors, music effects, and instruments
        discoveredAUs = all.filter { comp in
            let type = comp.audioComponentDescription.componentType
            return type == kAudioUnitType_MIDIProcessor
                || type == kAudioUnitType_MusicEffect
                || type == kAudioUnitType_MusicDevice
        }

        statusMessage = "Found \(discoveredAUs.count) Audio Units"
        isScanning = false
    }

    private func loadAudioUnit(_ component: AVAudioUnitComponent) {
        isLoading = true
        statusMessage = "Loading \(component.name)..."

        let desc = component.audioComponentDescription
        AVAudioUnit.instantiate(with: desc, options: .loadOutOfProcess) { [self] audioUnit, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let audioUnit = audioUnit {
                    self.loadedAU = audioUnit
                    self.statusMessage = "Successfully loaded \(component.name)"
                } else {
                    self.statusMessage = "Failed to load: \(error?.localizedDescription ?? "Unknown error")"
                }
            }
        }
    }

    private func sendTestMIDI() {
        statusMessage = "Sending test note C4..."
        let now = mach_absolute_time()
        let events = [
            MIDIEvent(timestampNs: UInt64(now), message: .noteOn(channel: 0, note: 60, velocity: 100)),
            MIDIEvent(timestampNs: UInt64(now) + 500_000_000, message: .noteOff(channel: 0, note: 60, velocity: 0))
        ]
        appState.sendMIDI(events)
        statusMessage = "Test note C4 sent"
    }

    private func sendTestScale() {
        statusMessage = "Sending C major scale..."
        let now = mach_absolute_time()
        let scaleNotes: [UInt8] = [60, 62, 64, 65, 67, 69, 71, 72]
        var events: [MIDIEvent] = []

        for (i, note) in scaleNotes.enumerated() {
            let offset = UInt64(i) * 250_000_000 // 250ms apart
            events.append(MIDIEvent(
                timestampNs: UInt64(now) + offset,
                message: .noteOn(channel: 0, note: note, velocity: 80)
            ))
            events.append(MIDIEvent(
                timestampNs: UInt64(now) + offset + 200_000_000,
                message: .noteOff(channel: 0, note: note, velocity: 0)
            ))
        }

        appState.sendMIDI(events)
        statusMessage = "C major scale sent (\(scaleNotes.count) notes)"
    }

    // MARK: - Helpers

    private var statusColor: Color {
        if statusMessage.contains("Success") || statusMessage.contains("Loaded") || statusMessage.contains("sent") {
            return .green
        } else if statusMessage.contains("Failed") || statusMessage.contains("error") {
            return .red
        } else {
            return .orange
        }
    }

    private func auTypeName(_ type: OSType) -> String {
        switch type {
        case kAudioUnitType_MIDIProcessor: return "MIDI Processor"
        case kAudioUnitType_MusicEffect: return "Music Effect"
        case kAudioUnitType_MusicDevice: return "Music Device"
        default: return fourCharCode(type)
        }
    }

    private func fourCharCode(_ value: OSType) -> String {
        let chars = [
            Character(UnicodeScalar((value >> 24) & 0xFF)!),
            Character(UnicodeScalar((value >> 16) & 0xFF)!),
            Character(UnicodeScalar((value >> 8) & 0xFF)!),
            Character(UnicodeScalar(value & 0xFF)!)
        ]
        return String(chars)
    }
}

struct AUComponentRow: View {
    let component: AVAudioUnitComponent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(component.name)
                .font(.body.bold())
            Text(component.manufacturerName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}
#endif
