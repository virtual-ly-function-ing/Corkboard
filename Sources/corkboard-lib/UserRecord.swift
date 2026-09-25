import Foundation

struct UserRecord: Codable, Sendable, Equatable {
    let id: UUID
    let username: String
    let passwordHash: String
    let createdAt: Date
}