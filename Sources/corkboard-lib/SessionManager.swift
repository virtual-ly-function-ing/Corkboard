import Foundation

actor SessionManager {

    private let idleTimeout: TimeInterval
    private let absoluteLifetime: TimeInterval
    private let clock: SessionClock

    private var sessionStorage: [String: UserSession] = [:]

    private func generateSessionID() -> String {

        var generator = SystemRandomNumberGenerator()

        let words = (0..<4).map { _ in generator.next() }
        return words.map { String(format: "%016x", $0) }.joined()
    }

    private func isIdleExpired(_ session: UserSession, now: Date) -> Bool {
        return now > session.expiresAt
    }

    private func isAbsolutelyExpired(_ session: UserSession, now: Date) -> Bool {
        return now.timeIntervalSince(session.createdAt) > absoluteLifetime
    }

    private func renewSession(_ session: UserSession, now: Date) -> UserSession {
        var renewed = session
        renewed.lastActiveAt = now
        renewed.expiresAt = now.addingTimeInterval(idleTimeout)
        renewed.renewalCount += 1
        sessionStorage[renewed.id] = renewed
        return renewed
    }

    func destroySession(_ sessionID: String) {
        sessionStorage.removeValue(forKey: sessionID)
    }

    func destroyAllSessions(for userID: UUID) {
        sessionStorage = sessionStorage.filter { $0.value.userID != userID }
    }

    func activeSessionCount(for userID: UUID) -> Int {
        sessionStorage.values.filter { $0.userID == userID }.count
    }

    func createSession(for userID: UUID) -> UserSession {
        let now = clock.now()
        let session = UserSession(
            id: generateSessionID(),
            userID: userID,
            createdAt: now,
            expiresAt: now.addingTimeInterval(idleTimeout),
            lastActiveAt: now,
            renewalCount: 0
        )
        sessionStorage[session.id] = session
        return session
    }

    func validateSession(id: String) -> UserSession? {
        guard let session = sessionStorage[id] else { return nil }
        let now = clock.now()

        if isAbsolutelyExpired(session, now: now) {
            destroySession(session.id)
            return nil
        }

        if isIdleExpired(session, now: now) {
            destroySession(session.id)
            return nil
        }
        return renewSession(session, now: now)
    }

    init(
        idleTimeout: TimeInterval = 60 * 60 * 24,
        absoluteLifetime: TimeInterval = 60 * 60 * 24 * 30,
        clock: SessionClock = SystemClock()
    ) {
        self.idleTimeout = idleTimeout
        self.absoluteLifetime = absoluteLifetime
        self.clock = clock
    }

}
