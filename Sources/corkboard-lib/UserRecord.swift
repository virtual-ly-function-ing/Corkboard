import Foundation

struct UserRecord: Codable, Sendable, Equatable {
    let id: UUID
    let username: String
    let passwordHash: String
    let createdAt: Date
}

extension UserRecord: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String {
        "UserRecord(id: \(id), username: \(username), passwordHash: <redacted>, createdAt: \(createdAt))"
    }

    var debugDescription: String { description }
}
