actor AuthService {
    private let userStore: UserStore
    private let sessionManager: SessionManager

    init(userStore: UserStore = UserStore(), sessionManager: SessionManager = SessionManager()) {
        self.userStore = userStore
        self.sessionManager = sessionManager
    }

    func register(username: String, password: String) async throws -> UserSession {
        let user = try await userStore.createUser(username: username, password: password)
        return await sessionManager.createSession(for: user.id)
    }

    func login(username: String, password: String) async throws -> UserSession {
        let user = try await userStore.authenticate(username: username, password: password)
        return await sessionManager.createSession(for: user.id)
    }
}