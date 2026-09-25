import Foundation

enum UserStoreError: Error, Equatable {
    case usernameTaken
    case invalidCredentials
}

actor UserStore {
    private var usersByUsername: [String: UserRecord] = [:]
    private let hasher: PasswordHasher
    private let clock: SessionClock
    private var dummyHash: String?

    init(hasher: PasswordHasher = NativeArgon2PasswordHasher(), clock: SessionClock = SystemClock()) {
        self.hasher = hasher
        self.clock = clock
    }

    private func dummyHashForTimingParity() async throws -> String {
        if let dummyHash { return dummyHash }
        let generated = try await hasher.hash(password: UUID().uuidString)
        dummyHash = generated
        return generated
    }

    func createUser(username: String, password: String) async throws -> UserRecord {
        guard usersByUsername[username] == nil else {
            throw UserStoreError.usernameTaken
        }
        let record = UserRecord(
            id: UUID(),
            username: username,
            passwordHash: try await hasher.hash(password: password),
            createdAt: clock.now()
        )
        usersByUsername[username] = record
        return record
    }

    func authenticate(username: String, password: String) async throws -> UserRecord {
        guard let record = usersByUsername[username] else {
            if let dummy = try? await dummyHashForTimingParity() {
                _ = try? await hasher.verify(password: password, against: dummy)
            }
            throw UserStoreError.invalidCredentials
        }
        guard try await hasher.verify(password: password, against: record.passwordHash) else {
            throw UserStoreError.invalidCredentials
        }
        return record
    }
}