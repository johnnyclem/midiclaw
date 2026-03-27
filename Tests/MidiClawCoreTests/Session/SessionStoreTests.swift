import XCTest
@testable import MidiClawCore

final class SessionStoreTests: XCTestCase {
    var store: SessionStore!
    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbPath = tempDir.appendingPathComponent("test.db").path
        store = try SessionStore(path: dbPath)
    }

    override func tearDown() async throws {
        store = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testCreateAndFetchSession() throws {
        let session = Session(name: "Test Session")
        try store.createSession(session)

        let sessions = try store.fetchSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].name, "Test Session")
        XCTAssertEqual(sessions[0].id, session.id)
    }

    func testFetchSessionById() throws {
        let session = Session(name: "Find Me")
        try store.createSession(session)

        let found = try store.fetchSession(id: session.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Find Me")
    }

    func testUpdateSession() throws {
        var session = Session(name: "Before")
        try store.createSession(session)

        session.name = "After"
        session.durationSeconds = 42.5
        session.eventCount = 100
        try store.updateSession(session)

        let updated = try store.fetchSession(id: session.id)
        XCTAssertEqual(updated?.name, "After")
        XCTAssertEqual(updated?.durationSeconds, 42.5)
        XCTAssertEqual(updated?.eventCount, 100)
    }

    func testDeleteSession() throws {
        let session = Session(name: "Delete Me")
        try store.createSession(session)

        try store.deleteSession(id: session.id)
        let sessions = try store.fetchSessions()
        XCTAssertTrue(sessions.isEmpty)
    }

    func testAppendAndFetchEvents() throws {
        let session = Session(name: "Events Test")
        try store.createSession(session)

        let events = [
            SessionEvent(sessionId: session.id, timestampNs: 0, tokenId: 60),
            SessionEvent(sessionId: session.id, timestampNs: 1000, tokenId: 256),
            SessionEvent(sessionId: session.id, timestampNs: 2000, tokenId: 188),
        ]
        try store.appendEvents(events)

        let fetched = try store.fetchEvents(forSession: session.id)
        XCTAssertEqual(fetched.count, 3)
        XCTAssertEqual(fetched[0].tokenId, 60)
        XCTAssertEqual(fetched[1].tokenId, 256)
        XCTAssertEqual(fetched[2].tokenId, 188)
    }

    func testEventCount() throws {
        let session = Session(name: "Count Test")
        try store.createSession(session)

        let events = (0..<50).map { i in
            SessionEvent(sessionId: session.id, timestampNs: UInt64(i * 1000), tokenId: UInt16(i))
        }
        try store.appendEvents(events)

        let count = try store.eventCount(forSession: session.id)
        XCTAssertEqual(count, 50)
    }

    func testCascadeDeleteRemovesEvents() throws {
        let session = Session(name: "Cascade Test")
        try store.createSession(session)

        let events = [
            SessionEvent(sessionId: session.id, timestampNs: 0, tokenId: 60),
        ]
        try store.appendEvents(events)

        try store.deleteSession(id: session.id)
        let count = try store.eventCount(forSession: session.id)
        XCTAssertEqual(count, 0)
    }

    func testSessionsOrderedByDateDescending() throws {
        let s1 = Session(name: "First", createdAt: Date(timeIntervalSince1970: 1000))
        let s2 = Session(name: "Second", createdAt: Date(timeIntervalSince1970: 2000))
        let s3 = Session(name: "Third", createdAt: Date(timeIntervalSince1970: 3000))

        try store.createSession(s1)
        try store.createSession(s2)
        try store.createSession(s3)

        let sessions = try store.fetchSessions()
        XCTAssertEqual(sessions[0].name, "Third")
        XCTAssertEqual(sessions[1].name, "Second")
        XCTAssertEqual(sessions[2].name, "First")
    }
}
