import Foundation

actor SessionManager {

    private var sessionStorage: [String: UserSession] = [:]

    private func generateSessionID() -> String {

        var generator = SystemRandomNumberGenerator()

        let words = (0..<4).map { _ in generator.next() }
        return words.map { String(format: "%016x", $0) }.joined()
    }

    private func isSessionExpired(_ session: UserSession) -> Bool {
        return Date.now > session.expiresAt
    }

    private func updateLastActiveAtDate(for session: UserSession) -> UserSession {
        var updatedSession = session
        let now = Date.now
        updatedSession.lastActiveAt = now
        updatedSession.expiresAt = now.addingTimeInterval(86400)

        sessionStorage[updatedSession.id] = updatedSession
        return updatedSession
    }

    private func destroySession(id: String) {
        sessionStorage.removeValue(forKey: id)
    }

    func createSession(for userID: String) -> UserSession? {

        guard let uuid = UUID(uuidString: userID) else { return nil }
        let sessionID = generateSessionID()

        let session = UserSession(
            id: sessionID, userID: uuid, createdAt: Date.now,
            expiresAt: Date.now.addingTimeInterval(86400), lastActiveAt: Date.now)

        sessionStorage[sessionID] = session

        return session
    }

    func validateSession(id: String) -> UserSession? {
        guard var session = sessionStorage[id] else { return nil }

        if isSessionExpired(session) {
            destroySession(id: session.id)
            return nil
        }

        let updatedSession = updateLastActiveAtDate(for: session)

        return updatedSession
    }

}
