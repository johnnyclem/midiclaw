import Foundation
import GRDB

/// Represents a recorded MIDI session.
public struct Session: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var durationSeconds: Double?
    public var eventCount: Int

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        durationSeconds: Double? = nil,
        eventCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.eventCount = eventCount
    }
}

// MARK: - GRDB Conformance

extension Session: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "sessions"

    enum Columns: String, ColumnExpression {
        case id, name, createdAt, durationSeconds, eventCount
    }
}
