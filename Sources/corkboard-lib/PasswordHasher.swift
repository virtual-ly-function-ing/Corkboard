protocol PasswordHasher: Sendable {
    func hash(password: String) async throws -> String
    func verify(password: String, against hash: String) async throws -> Bool
}
