import Foundation

enum UserStoreError: Error, Equatable {
    case usernameTaken
    case invalidCredentials
    case accountLocked
    case invalidUsername
    case invalidPassword
}

actor UserStore {

    private enum InputLimits {
        static let usernameLength = 1...64
        static let passwordLength = 8...256
    }

    private enum LockoutPolicy {
        static let maxFailedAttempts = 5
        static let lockoutDuration: TimeInterval = 15 * 60
    }

    private struct FailureState {
        var count = 0
        var lockedUntil: Date?
    }

    private var usersByUsername: [String: UserRecord] = [:]
    private var failedAttempts: [String: FailureState] = [:]
    private let hasher: PasswordHasher
    private let clock: SessionClock
    private var dummyHash: String?

    init(hasher: PasswordHasher = NativeArgon2PasswordHasher(), clock: SessionClock = SystemClock())
    {
        self.hasher = hasher
        self.clock = clock
    }

    private func dummyHashForTimingParity() async throws -> String {
        if let dummyHash { return dummyHash }
        let generated = try await hasher.hash(password: UUID().uuidString)
        dummyHash = generated
        return generated
    }

    private func normalize(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func validate(username: String, password: String) throws {
        guard InputLimits.usernameLength.contains(username.count) else {
            throw UserStoreError.invalidUsername
        }
        guard InputLimits.passwordLength.contains(password.count) else {
            throw UserStoreError.invalidPassword
        }
    }

    private func recordFailedAttempt(for username: String, now: Date) {
        var state = failedAttempts[username] ?? FailureState()
        state.count += 1
        if state.count >= LockoutPolicy.maxFailedAttempts {
            state.lockedUntil = now.addingTimeInterval(LockoutPolicy.lockoutDuration)
        }
        failedAttempts[username] = state
    }

    func createUser(username: String, password: String) async throws -> UserRecord {
        let normalizedUsername = normalize(username)
        try validate(username: normalizedUsername, password: password)

        guard usersByUsername[normalizedUsername] == nil else {
            throw UserStoreError.usernameTaken
        }
        let record = UserRecord(
            id: UUID(),
            username: normalizedUsername,
            passwordHash: try await hasher.hash(password: password),
            createdAt: clock.now()
        )
        usersByUsername[normalizedUsername] = record
        return record
    }

    func authenticate(username: String, password: String) async throws -> UserRecord {
        let normalizedUsername = normalize(username)
        let now = clock.now()

        guard let record = usersByUsername[normalizedUsername] else {
            if let dummy = try? await dummyHashForTimingParity() {
                _ = try? await hasher.verify(password: password, against: dummy)
            }
            throw UserStoreError.invalidCredentials
        }

        if let state = failedAttempts[normalizedUsername], let lockedUntil = state.lockedUntil {
            if now < lockedUntil {
                throw UserStoreError.accountLocked
            }
            failedAttempts.removeValue(forKey: normalizedUsername)
        }

        guard try await hasher.verify(password: password, against: record.passwordHash) else {
            recordFailedAttempt(for: normalizedUsername, now: now)
            throw UserStoreError.invalidCredentials
        }

        failedAttempts.removeValue(forKey: normalizedUsername)
        return record
    }
}
