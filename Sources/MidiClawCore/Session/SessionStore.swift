import Foundation
import GRDB

/// SQLite-backed persistence for MIDI sessions and their events.
/// Database is stored at ~/Library/Application Support/MidiClaw/sessions.db
public final class SessionStore: @unchecked Sendable {
    private let dbQueue: DatabaseQueue

    /// Initialize with a specific database path (useful for testing).
    public init(path: String) throws {
        var config = Configuration()
        config.prepareDatabase { db in
            db.trace { Log.session.debug("\($0)") }
        }
        // Remove trace in production by using a release flag
        #if !DEBUG
        config = Configuration()
        #endif

        dbQueue = try DatabaseQueue(path: path, configuration: config)
        try migrator.migrate(dbQueue)
    }

    /// Initialize with the default application support directory.
    public convenience init() throws {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("MidiClaw", isDirectory: true)

        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let dbPath = appSupport.appendingPathComponent("sessions.db").path
        try self.init(path: dbPath)
    }

    // MARK: - Schema Migration

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "sessions") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("durationSeconds", .double)
                t.column("eventCount", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "session_events") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sessionId", .text).notNull()
                    .indexed()
                    .references("sessions", onDelete: .cascade)
                t.column("timestampNs", .integer).notNull()
                t.column("tokenId", .integer).notNull()
                t.column("rawMIDIBytes", .blob).notNull().defaults(to: Data())
            }
        }

        return migrator
    }

    // MARK: - Session CRUD

    /// Create a new session.
    public func createSession(_ session: Session) throws {
        try dbQueue.write { db in
            var s = session
            try s.insert(db)
        }
    }

    /// Fetch all sessions, ordered by creation date descending.
    public func fetchSessions() throws -> [Session] {
        try dbQueue.read { db in
            try Session
                .order(Session.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    /// Fetch a single session by ID.
    public func fetchSession(id: UUID) throws -> Session? {
        try dbQueue.read { db in
            try Session.fetchOne(db, key: id)
        }
    }

    /// Update a session (e.g., set duration and event count after recording stops).
    public func updateSession(_ session: Session) throws {
        try dbQueue.write { db in
            try session.update(db)
        }
    }

    /// Delete a session and all its events (cascade).
    public func deleteSession(id: UUID) throws {
        try dbQueue.write { db in
            _ = try Session.deleteOne(db, key: id)
        }
    }

    // MARK: - Event CRUD

    /// Append a batch of events to a session.
    public func appendEvents(_ events: [SessionEvent]) throws {
        try dbQueue.write { db in
            for var event in events {
                try event.insert(db)
            }
        }
    }

    /// Fetch all events for a session, ordered by timestamp.
    public func fetchEvents(forSession sessionId: UUID) throws -> [SessionEvent] {
        try dbQueue.read { db in
            try SessionEvent
                .filter(SessionEvent.Columns.sessionId == sessionId.uuidString)
                .order(SessionEvent.Columns.timestampNs)
                .fetchAll(db)
        }
    }

    /// Count events in a session.
    public func eventCount(forSession sessionId: UUID) throws -> Int {
        try dbQueue.read { db in
            try SessionEvent
                .filter(SessionEvent.Columns.sessionId == sessionId.uuidString)
                .fetchCount(db)
        }
    }
}
