import Foundation
import Testing
@testable import corkboard_lib

@Suite("AuthService")
struct AuthServiceTests {

    @Test("Registering creates a session tied to the new user's id")
    func registerCreatesSessionForNewUser() async throws {
        let userStore = UserStore(hasher: FakePasswordHasher())
        let sessionManager = SessionManager()
        let auth = AuthService(userStore: userStore, sessionManager: sessionManager)

        let session = try await auth.register(username: "ada", password: "s3cret-password")
        let user = try await userStore.authenticate(username: "ada", password: "s3cret-password")

        #expect(session.userID == user.id)
    }

    @Test("Login creates a session for an existing user")
    func loginCreatesSessionForExistingUser() async throws {
        let userStore = UserStore(hasher: FakePasswordHasher())
        let sessionManager = SessionManager()
        let auth = AuthService(userStore: userStore, sessionManager: sessionManager)

        _ = try await auth.register(username: "ada", password: "s3cret-password")
        let session = try await auth.login(username: "ada", password: "s3cret-password")
        let user = try await userStore.authenticate(username: "ada", password: "s3cret-password")

        #expect(session.userID == user.id)
    }

    @Test("A wrong password throws and creates no session")
    func loginWithWrongPasswordCreatesNoSession() async throws {
        let userStore = UserStore(hasher: FakePasswordHasher())
        let sessionManager = SessionManager()
        let auth = AuthService(userStore: userStore, sessionManager: sessionManager)
        _ = try await auth.register(username: "ada", password: "s3cret-password")
        let user = try await userStore.authenticate(username: "ada", password: "s3cret-password")

        await #expect(throws: UserStoreError.invalidCredentials) {
            _ = try await auth.login(username: "ada", password: "wrong")
        }
        #expect(await sessionManager.activeSessionCount(for: user.id) == 1)
    }

    @Test("A duplicate registration throws and creates no extra session")
    func duplicateRegisterCreatesNoExtraSession() async throws {
        let userStore = UserStore(hasher: FakePasswordHasher())
        let sessionManager = SessionManager()
        let auth = AuthService(userStore: userStore, sessionManager: sessionManager)
        _ = try await auth.register(username: "ada", password: "first-password")
        let user = try await userStore.authenticate(username: "ada", password: "first-password")

        await #expect(throws: UserStoreError.usernameTaken) {
            _ = try await auth.register(username: "ada", password: "second-password")
        }
        #expect(await sessionManager.activeSessionCount(for: user.id) == 1)
    }
}