import Foundation
import Testing

@testable import corkboard_lib

@Suite("UserStore")
struct UserStoreTests {

    @Test("createUser stores the hashed password, not the plaintext")
    func createUserHashesPassword() async throws {
        let clock = TestClock()
        let store = UserStore(hasher: FakePasswordHasher(), clock: clock)
        let record = try await store.createUser(username: "ada", password: "s3cret")

        #expect(record.username == "ada")
        #expect(record.passwordHash != "s3cret")
        #expect(record.createdAt == clock.now())
    }

    @Test("A taken username throws usernameTaken")
    func duplicateUsernameThrows() async throws {
        let store = UserStore(hasher: FakePasswordHasher())
        _ = try await store.createUser(username: "ada", password: "first")
        await #expect(throws: UserStoreError.usernameTaken) {
            _ = try await store.createUser(username: "ada", password: "second")
        }
    }

    @Test("Authenticating with the correct password succeeds")
    func authenticateWithCorrectPassword() async throws {
        let store = UserStore(hasher: FakePasswordHasher())
        let created = try await store.createUser(username: "ada", password: "s3cret")
        let authenticated = try await store.authenticate(username: "ada", password: "s3cret")
        #expect(authenticated.id == created.id)
    }

    @Test("The wrong password throws invalidCredentials")
    func authenticateWithWrongPassword() async throws {
        let store = UserStore(hasher: FakePasswordHasher())
        _ = try await store.createUser(username: "ada", password: "s3cret")
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
}
