import Foundation
import Testing

@testable import corkboard_lib

@Suite("SessionManager")
struct SessionManagerTests {
    @Test("createSession sets createdAt from the clock and starts renewalCount at 0")
    func createSessionSetsInitialFields() async {
        let clock = TestClock()
        let manager = SessionManager(idleTimeout: 3600, absoluteLifetime: 86400, clock: clock)
        let userID = UUID()

        let session = await manager.createSession(for: userID)

        #expect(session.userID == userID)
        #expect(session.createdAt == clock.now())
        #expect(session.expiresAt == clock.now().addingTimeInterval(3600))
        #expect(session.renewalCount == 0)
    }

    @Test("Validating a session within its idle window renews it and preserves createdAt")
    func validateRenewsIdleSession() async {
        let clock = TestClock()
        let manager = SessionManager(idleTimeout: 3600, absoluteLifetime: 86400, clock: clock)
        let session = await manager.createSession(for: UUID())

        clock.advance(by: 1800)

        let renewed = await manager.validateSession(id: session.id)

        #expect(renewed != nil)
        #expect(renewed?.renewalCount == 1)
        #expect(renewed?.createdAt == session.createdAt)
        #expect(renewed?.expiresAt == clock.now().addingTimeInterval(3600))
    }

    @Test("A session past its idle window fails validation")
    func validateFailsAfterIdleTimeout() async {
        let clock = TestClock()
        let manager = SessionManager(idleTimeout: 3600, absoluteLifetime: 86400, clock: clock)
        let session = await manager.createSession(for: UUID())

        clock.advance(by: 3601)

        let result = await manager.validateSession(id: session.id)
        #expect(result == nil)
    }

    @Test("An idle-expired session is evicted from storage, not just rejected")
    func idleExpiryEvictsSession() async {
        let clock = TestClock()
        let manager = SessionManager(idleTimeout: 3600, absoluteLifetime: 86400, clock: clock)
        let userID = UUID()
        let session = await manager.createSession(for: userID)

        clock.advance(by: 3601)
        _ = await manager.validateSession(id: session.id)

        #expect(await manager.activeSessionCount(for: userID) == 0)
    }

    @Test("Repeated activity within the idle window keeps extending it indefinitely")
    func repeatedActivityKeepsSessionAlive() async {
        let clock = TestClock()
        let manager = SessionManager(
            idleTimeout: 3600, absoluteLifetime: .greatestFiniteMagnitude, clock: clock)
        var current = await manager.createSession(for: UUID())

        for _ in 0..<10 {
            clock.advance(by: 1800)
            guard let renewed = await manager.validateSession(id: current.id) else {
                Issue.record("session unexpectedly expired during regular activity")
                return
            }
            current = renewed
        }

        #expect(current.renewalCount == 10)
    }

    @Test("A session hits the absolute cap even with constant activity that never goes idle")
    func absoluteCapOverridesConstantActivity() async {
        let clock = TestClock()
        let manager = SessionManager(idleTimeout: 3600, absoluteLifetime: 7200, clock: clock)
        var current = await manager.createSession(for: UUID())

        for _ in 0..<5 {
            clock.advance(by: 1800)
            if let renewed = await manager.validateSession(id: current.id) {
                current = renewed
            }
        }

        let result = await manager.validateSession(id: current.id)
        #expect(result == nil, "constant renewal must not bypass the absolute lifetime")
    }

    @Test("A session well inside both windows still validates normally")
    func validSessionWithinBothWindows() async {
        let clock = TestClock()
        let manager = SessionManager(idleTimeout: 3600, absoluteLifetime: 86400, clock: clock)
        let session = await manager.createSession(for: UUID())

        clock.advance(by: 60)

        let result = await manager.validateSession(id: session.id)
        #expect(result != nil)
    }

    @Test("destroySession removes only the targeted session")
    func destroySessionRemovesOnlyThatSession() async {
        let manager = SessionManager()
        let userID = UUID()
        let sessionA = await manager.createSession(for: userID)
        let sessionB = await manager.createSession(for: userID)

        await manager.destroySession(sessionA.id)

        let resultA = await manager.validateSession(id: sessionA.id)
        let resultB = await manager.validateSession(id: sessionB.id)
        #expect(resultA == nil)
        #expect(resultB != nil)
    }

    @Test("destroyAllSessions logs a user out everywhere without touching other users")
    func destroyAllSessionsForUser() async {
        let manager = SessionManager()
        let userID = UUID()
        let otherUserID = UUID()
        _ = await manager.createSession(for: userID)
        _ = await manager.createSession(for: userID)
        let otherSession = await manager.createSession(for: otherUserID)

        await manager.destroyAllSessions(for: userID)

        #expect(await manager.activeSessionCount(for: userID) == 0)
        #expect(await manager.validateSession(id: otherSession.id) != nil)
    }

    @Test("Validating an unknown session id returns nil rather than crashing")
    func validateUnknownSessionReturnsNil() async {
        let manager = SessionManager()
        let result = await manager.validateSession(id: "not-a-real-session-id")
        #expect(result == nil)
    }

    @Test("A session validated at exactly its expiry instant is still valid")
    func validateAtExactExpiryBoundary() async {
        let clock = TestClock()
        let manager = SessionManager(idleTimeout: 3600, absoluteLifetime: 86400, clock: clock)
        let session = await manager.createSession(for: UUID())

        clock.advance(by: 3600)

        let result = await manager.validateSession(id: session.id)
        #expect(
            result != nil,
            "isIdleExpired uses now > expiresAt, so the exact boundary instant should still be valid"
        )
    }

    @Test("Session IDs are 64 hex characters and don't collide across many generations")
    func sessionIDsAreWellFormedAndUnique() async {
        let manager = SessionManager()
        let userID = UUID()

        var ids = Set<String>()
        for _ in 0..<1000 {
            let session = await manager.createSession(for: userID)
            ids.insert(session.id)
        }

        #expect(ids.count == 1000, "1000 generations should produce 1000 distinct ids")
        for id in ids {
            #expect(id.count == 64, "expected 4 words × 16 hex chars each")
            #expect(id.allSatisfy { $0.isHexDigit }, "id should contain only hex characters")
        }
    }

    @Test(
        "activeSessionCount reflects exactly the sessions belonging to each user among a mixed population"
    )
    func activeSessionCountWithMixedUsers() async {
        let manager = SessionManager()
        let userA = UUID()
        let userB = UUID()

        _ = await manager.createSession(for: userA)
        _ = await manager.createSession(for: userA)
        _ = await manager.createSession(for: userA)
        _ = await manager.createSession(for: userB)

        #expect(await manager.activeSessionCount(for: userA) == 3)
        #expect(await manager.activeSessionCount(for: userB) == 1)
    }
}
