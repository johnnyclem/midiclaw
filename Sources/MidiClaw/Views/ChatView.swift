#if os(macOS)
import SwiftUI

/// Chat interface for interacting with Mindi.
struct ChatView: View {
    @ObservedObject var appState: AppState
    @State private var inputText = ""
    @State private var isProcessing = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.chatMessages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: appState.chatMessages.count) { _ in
                    if let last = appState.chatMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area
            inputArea
        }
    }

    private var chatHeader: some View {
        HStack {
            Image(systemName: "wand.and.stars")
                .font(.title2)
                .foregroundStyle(.accent)

            VStack(alignment: .leading) {
                Text("Chat with Mindi")
                    .font(.headline)
                Text("Ask about chords, patterns, music theory, or tell Mindi what to play")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Quick action buttons
            Menu {
                Button("Suggest chords for my melody") {
                    sendQuickMessage("Suggest some chords that would go well with what I'm playing")
                }
                Button("Create a drum pattern") {
                    sendQuickMessage("Create a drum pattern that fits the current mood")
                }
                Button("Change the style") {
                    sendQuickMessage("Can you switch to a different style? Something more jazzy")
                }
                Button("Simplify the accompaniment") {
                    sendQuickMessage("Make the accompaniment simpler and more sparse")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
        .padding()
    }

    private var inputArea: some View {
        HStack(spacing: 8) {
            TextField("Ask Mindi anything...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.isEmpty ? .secondary : .accent)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty || isProcessing)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }

        inputText = ""
        isProcessing = true

        Task {
            await appState.sendChatMessage(text)
            isProcessing = false
        }
    }

    private func sendQuickMessage(_ text: String) {
        isProcessing = true
        Task {
            await appState.sendChatMessage(text)
            isProcessing = false
        }
    }
}

/// A single chat message bubble.
struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user { Spacer(minLength: 60) }

            if message.role != .user {
                avatar
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(10)
                    .background(backgroundColor)
                    .foregroundStyle(foregroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .textSelection(.enabled)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role == .user {
                avatar
            }

            if message.role != .user { Spacer(minLength: 60) }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(avatarColor)
                .frame(width: 28, height: 28)
            Image(systemName: avatarIcon)
                .font(.caption)
                .foregroundStyle(.white)
        }
    }

    private var avatarIcon: String {
        switch message.role {
        case .user: return "person.fill"
        case .mindi: return "wand.and.stars"
        case .system: return "info.circle.fill"
        }
    }

    private var avatarColor: Color {
        switch message.role {
        case .user: return .blue
        case .mindi: return .purple
        case .system: return .gray
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return .accentColor
        case .mindi: return Color(.controlBackgroundColor)
        case .system: return Color(.controlBackgroundColor).opacity(0.5)
        }
    }

    private var foregroundColor: Color {
        switch message.role {
        case .user: return .white
        case .mindi, .system: return .primary
        }
    }
}
#endif
