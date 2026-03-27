#if os(macOS)
import Foundation

/// A message in the Mindi chat interface.
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    enum Role: String {
        case user
        case mindi
        case system
    }

    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}
#endif
