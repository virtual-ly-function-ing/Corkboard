import Foundation
import Testing

@testable import corkboard_lib

@Suite("UserStore")
struct UserStoreTests {

    @Test("createUser stores the hashed password, not the plaintext")
    func createUserHashesPassword() async throws {
        let clock = TestClock()
        let store = UserStore(hasher: FakePasswordHasher(), clock: clock)
        let record = try await store.createUser(username: "ada", password: "s3cret-password")

        #expect(record.username == "ada")
        #expect(record.passwordHash != "s3cret-password")
        #expect(record.createdAt == clock.now())
    }

    @Test("A taken username throws usernameTaken")
    func duplicateUsernameThrows() async throws {
        let store = UserStore(hasher: FakePasswordHasher())
        _ = try await store.createUser(username: "ada", password: "first-password")
        await #expect(throws: UserStoreError.usernameTaken) {
            _ = try await store.createUser(username: "ada", password: "second-password")
        }
    }

    @Test("Authenticating with the correct password succeeds")
    func authenticateWithCorrectPassword() async throws {
        let store = UserStore(hasher: FakePasswordHasher())
        let created = try await store.createUser(username: "ada", password: "s3cret-password")
        let authenticated = try await store.authenticate(
            username: "ada", password: "s3cret-password")
        #expect(authenticated.id == created.id)
    }

    @Test("The wrong password throws invalidCredentials")
    func authenticateWithWrongPassword() async throws {
        let store = UserStore(hasher: FakePasswordHasher())
        _ = try await store.createUser(username: "ada", password: "s3cret-password")
        await #expect(throws: UserStoreError.invalidCredentials) {
            _ = try await store.authenticate(username: "ada", password: "wrong")
        }
    }

    @Test("A nonexistent username throws the identical error as a wrong password")
    func unknownUsernameMatchesWrongPasswordError() async throws {
        let store = UserStore(hasher: FakePasswordHasher())
        await #expect(throws: UserStoreError.invalidCredentials) {
            _ = try await store.authenticate(username: "nobody", password: "whatever")
        }
    }

    @Test("A nonexistent username with the real Argon2 hasher still throws invalidCredentials")
    func unknownUsernameWithRealHasherThrowsCorrectly() async throws {
        let store = UserStore(hasher: NativeArgon2PasswordHasher())
        await #expect(throws: UserStoreError.invalidCredentials) {
            _ = try await store.authenticate(username: "nobody", password: "whatever")
        }
    }

    @Test("An empty or whitespace-only username is rejected")
    func emptyUsernameIsRejected() async throws {
        let store = UserStore(hasher: FakePasswordHasher())
        await #expect(throws: UserStoreError.invalidUsername) {
            _ = try await store.createUser(username: "   ", password: "s3cret-password")
        }
    }

    @Test("A password shorter than the minimum length is rejected")
    func tooShortPasswordIsRejected() async throws {
        let store = UserStore(hasher: FakePasswordHasher())
        await #expect(throws: UserStoreError.invalidPassword) {
            _ = try await store.createUser(username: "ada", password: "short")
        }
    }

    @Test("A password longer than the maximum length is rejected")
    func tooLongPasswordIsRejected() async throws {
        let store = UserStore(hasher: FakePasswordHasher())
        let hugePassword = String(repeating: "a", count: 257)
        await #expect(throws: UserStoreError.invalidPassword) {
            _ = try await store.createUser(username: "ada", password: hugePassword)
        }
    }

    @Test("Leading/trailing whitespace is trimmed from usernames on both register and login")
    func usernameWhitespaceIsTrimmedConsistently() async throws {
        let store = UserStore(hasher: FakePasswordHasher())
        _ = try await store.createUser(username: "  ada  ", password: "s3cret-password")
        let authenticated = try await store.authenticate(
            username: "ada", password: "s3cret-password")
        #expect(authenticated.username == "ada")
    }

    @Test("An account is locked after the maximum number of consecutive failed logins")
    func accountLocksAfterRepeatedFailures() async throws {
        let clock = TestClock()
        let store = UserStore(hasher: FakePasswordHasher(), clock: clock)
        _ = try await store.createUser(username: "ada", password: "s3cret-password")

        for _ in 0..<5 {
            await #expect(throws: UserStoreError.invalidCredentials) {
                _ = try await store.authenticate(username: "ada", password: "wrong")
            }
        }

        // The 6th attempt is locked out even though the password is now correct.
        await #expect(throws: UserStoreError.accountLocked) {
            _ = try await store.authenticate(username: "ada", password: "s3cret-password")
        }
    }

    @Test("A successful login resets the failed-attempt counter")
    func successfulLoginResetsFailureCount() async throws {
        let clock = TestClock()
        let store = UserStore(hasher: FakePasswordHasher(), clock: clock)
        _ = try await store.createUser(username: "ada", password: "s3cret-password")

        for _ in 0..<4 {
            await #expect(throws: UserStoreError.invalidCredentials) {
                _ = try await store.authenticate(username: "ada", password: "wrong")
            }
        }
        _ = try await store.authenticate(username: "ada", password: "s3cret-password")

        // Counter should have reset, so 4 more failures shouldn't trigger the lockout yet.
        for _ in 0..<4 {
            await #expect(throws: UserStoreError.invalidCredentials) {
                _ = try await store.authenticate(username: "ada", password: "wrong")
            }
        }
        let stillWorks = try await store.authenticate(username: "ada", password: "s3cret-password")
        #expect(stillWorks.username == "ada")
    }

    @Test("A lockout expires after the lockout duration has passed")
    func lockoutExpiresAfterDuration() async throws {
        let clock = TestClock()
        let store = UserStore(hasher: FakePasswordHasher(), clock: clock)
        _ = try await store.createUser(username: "ada", password: "s3cret-password")

        for _ in 0..<5 {
            await #expect(throws: UserStoreError.invalidCredentials) {
                _ = try await store.authenticate(username: "ada", password: "wrong")
            }
        }
        await #expect(throws: UserStoreError.accountLocked) {
            _ = try await store.authenticate(username: "ada", password: "s3cret-password")
        }

        clock.advance(by: 15 * 60 + 1)

        let authenticated = try await store.authenticate(
            username: "ada", password: "s3cret-password")
        #expect(authenticated.username == "ada")
    }

    @Test("Usernames are case-insensitive: different casing collides and cross-case login works")
    func usernameCaseIsNormalized() async throws {
        let store = UserStore(hasher: FakePasswordHasher())
        _ = try await store.createUser(username: "Ada", password: "s3cret-password")

        await #expect(throws: UserStoreError.usernameTaken) {
            _ = try await store.createUser(username: "ADA", password: "another-password")
        }

        let authenticated = try await store.authenticate(username: "ada", password: "s3cret-password")
        #expect(authenticated.username == "ada")
    }

}
