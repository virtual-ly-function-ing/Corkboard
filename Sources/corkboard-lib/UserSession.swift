import Foundation

struct UserSession: Codable {
    let id: String
    let userID: UUID
    let createdAt: Date
    var expiresAt: Date
    var lastActiveAt: Date
}