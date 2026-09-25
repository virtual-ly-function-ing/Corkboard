import Foundation

protocol SessionClock: Sendable {
    func now() -> Date
}

struct SystemClock: SessionClock {
    func now() -> Date {
        return Date.now
    }
}