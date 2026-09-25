import Foundation

struct UserSession: Codable, Sendable, Equatable {
    let id: String
    let userID: UUID
    let createdAt: Date
    var expiresAt: Date
    var lastActiveAt: Date
    var renewalCount: Int
}