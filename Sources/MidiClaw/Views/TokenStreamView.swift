#if os(macOS)
import SwiftUI
import MidiClawCore

/// Debug view showing the live token stream with color-coding by token class.
struct TokenStreamView: View {
    let tokens: [MidiToken]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "number.circle")
                Text("Token Stream")
                    .font(.headline)
                Spacer()
                Text("\(tokens.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)

            if tokens.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Token stream will appear here")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(Array(tokens.enumerated()), id: \.offset) { index, token in
                        TokenRow(token: token, index: index)
                            .id(index)
                    }
                    .listStyle(.plain)
                    .onChange(of: tokens.count) { _, _ in
                        if let last = tokens.indices.last {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

/// A single row in the token stream display.
struct TokenRow: View {
    let token: MidiToken
    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 30, alignment: .trailing)

            RoundedRectangle(cornerRadius: 2)
                .fill(tokenColor)
                .frame(width: 4)

            Text("[\(token.rawValue)]")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            Text(token.description)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(tokenColor)
        }
        .padding(.vertical, 1)
    }

    private var tokenColor: Color {
        if token.isNoteOn { return .green }
        if token.isNoteOff { return .gray }
        if token.isVelocity { return .cyan }
        if token.isDelta { return .yellow }
        if token.isCC { return .blue }
        if token.isSpecial { return .purple }
        return .secondary
    }
}
#endif
