import Foundation
@testable import corkboard_lib

struct FakePasswordHasher: PasswordHasher {
    func hash(password: String) async throws -> String {
        "hashed:\(password)"
    }

    func verify(password: String, against hash: String) async throws -> Bool {
        hash == "hashed:\(password)"
    }
}