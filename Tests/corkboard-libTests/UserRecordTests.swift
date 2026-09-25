import Foundation
import Testing
@testable import corkboard_lib

@Suite("UserRecord")
struct UserRecordTests {

    @Test("description redacts the password hash")
    func descriptionRedactsPasswordHash() {
        let record = UserRecord(
            id: UUID(),
            username: "ada",
            passwordHash: "$argon2id$v=19$m=65536,t=3,p=4$somesalt$somehash",
            createdAt: Date()
        )

        #expect(!record.description.contains(record.passwordHash))
        #expect(record.description.contains("<redacted>"))
        #expect(!"\(record)".contains(record.passwordHash))
    }
}