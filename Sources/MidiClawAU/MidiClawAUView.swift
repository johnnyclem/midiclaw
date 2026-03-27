#if os(macOS)
import SwiftUI
import AudioToolbox
import MidiClawCore

/// SwiftUI view for the MidiClaw AudioUnit plugin interface.
/// Displays mode selector, parameters, and a live token stream monitor.
public struct MidiClawAUView: View {
    @ObservedObject private var viewModel: MidiClawAUViewModel

    public init(audioUnit: MidiClawAudioUnit) {
        self.viewModel = MidiClawAUViewModel(audioUnit: audioUnit)
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            Divider()
            modeSelector
            parameterControls
            Divider()
            tokenMonitor
        }
        .padding(16)
        .frame(minWidth: 320, idealWidth: 400, minHeight: 300, idealHeight: 440)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("MidiClaw")
                .font(.title2.bold())
            Spacer()
            Text("MIDI Effect")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mode")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Mode", selection: $viewModel.mode) {
                Text("Monitor").tag(0)
                Text("Passthrough").tag(1)
                Text("Transform").tag(2)
            }
            .pickerStyle(.segmented)
        }
    }

    private var parameterControls: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Channel Filter")
                    .font(.caption)
                Spacer()
                Picker("Channel", selection: $viewModel.channelFilter) {
                    Text("All").tag(0)
                    ForEach(1...16, id: \.self) { ch in
                        Text("\(ch)").tag(ch)
                    }
                }
                .frame(width: 80)
            }

            HStack {
                Text("Velocity Scale")
                    .font(.caption)
                Slider(value: $viewModel.velocityScale, in: 0...2, step: 0.01)
                Text(String(format: "%.0f%%", viewModel.velocityScale * 100))
                    .font(.caption.monospacedDigit())
                    .frame(width: 44, alignment: .trailing)
            }

            HStack {
                Text("Token Monitor")
                    .font(.caption)
                Spacer()
                Toggle("", isOn: $viewModel.tokenMonitorEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }

    private var tokenMonitor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Token Stream")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.tokens.count) tokens")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(viewModel.tokens.enumerated()), id: \.offset) { index, token in
                            Text(token.description)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(tokenColor(for: token))
                                .id(index)
                        }
                    }
                    .onChange(of: viewModel.tokens.count) { _, newCount in
                        if newCount > 0 {
                            proxy.scrollTo(newCount - 1, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func tokenColor(for token: MidiToken) -> Color {
        if token.isNoteOn { return .green }
        if token.isNoteOff { return .red }
        if token.isVelocity { return .orange }
        if token.isDelta { return .blue }
        if token.isCC { return .purple }
        if token.isSpecial { return .secondary }
        return .primary
    }
}

/// View model bridging the AudioUnit parameters to SwiftUI bindings.
@MainActor
final class MidiClawAUViewModel: ObservableObject {
    @Published var mode: Int = 1 {
        didSet { setParameter(.mode, value: Float(mode)) }
    }
    @Published var channelFilter: Int = 0 {
        didSet { setParameter(.channelFilter, value: Float(channelFilter)) }
    }
    @Published var velocityScale: Float = 1.0 {
        didSet { setParameter(.velocityScale, value: velocityScale) }
    }
    @Published var tokenMonitorEnabled: Bool = true {
        didSet { setParameter(.tokenMonitor, value: tokenMonitorEnabled ? 1.0 : 0.0) }
    }
    @Published var tokens: [MidiToken] = []

    private weak var audioUnit: MidiClawAudioUnit?
    private var refreshTimer: Timer?

    init(audioUnit: MidiClawAudioUnit) {
        self.audioUnit = audioUnit

        // Sync initial state from AU parameters
        if let tree = audioUnit.parameterTree {
            mode = Int(tree.parameter(withAddress: MidiClawAUParameterAddress.mode.rawValue)?.value ?? 1)
            channelFilter = Int(tree.parameter(withAddress: MidiClawAUParameterAddress.channelFilter.rawValue)?.value ?? 0)
            velocityScale = tree.parameter(withAddress: MidiClawAUParameterAddress.velocityScale.rawValue)?.value ?? 1.0
            let monVal = tree.parameter(withAddress: MidiClawAUParameterAddress.tokenMonitor.rawValue)?.value ?? 1.0
            tokenMonitorEnabled = monVal > 0.5
        }

        // Refresh token display periodically
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshTokens()
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func refreshTokens() {
        guard let au = audioUnit else { return }
        tokens = au.recentTokens
    }

    private func setParameter(_ address: MidiClawAUParameterAddress, value: Float) {
        audioUnit?.parameterTree?.parameter(
            withAddress: address.rawValue
        )?.value = AUValue(value)
    }
}
#endif
