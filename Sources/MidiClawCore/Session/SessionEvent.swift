import Foundation
import GRDB

/// A single recorded event within a session.
/// Stores both the token ID (for the adapter pipeline) and raw MIDI bytes (for lossless replay).
public struct SessionEvent: Codable, Sendable {
    public var id: Int64?
    public var sessionId: UUID
    public var timestampNs: UInt64  // nanoseconds from session start
    public var tokenId: UInt16
    public var rawMIDIBytes: Data

    public init(
        id: Int64? = nil,
        sessionId: UUID,
        timestampNs: UInt64,
        tokenId: UInt16,
        rawMIDIBytes: Data = Data()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.timestampNs = timestampNs
        self.tokenId = tokenId
        self.rawMIDIBytes = rawMIDIBytes
    }

    // Custom coding to handle UInt64 as Int64 in SQLite
    enum CodingKeys: String, CodingKey {
        case id, sessionId, timestampNs, tokenId, rawMIDIBytes
    }
}

// MARK: - GRDB Conformance

extension SessionEvent: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "session_events"

    public static let session = belongsTo(Session.self)

    enum Columns: String, ColumnExpression {
        case id, sessionId, timestampNs, tokenId, rawMIDIBytes
    }
}
