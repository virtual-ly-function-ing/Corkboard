import Foundation
@testable import corkboard_lib

final class TestClock: SessionClock, @unchecked Sendable {
    private var current: Date

    func now() -> Date {
        return current
    }

    func advance(by interval: TimeInterval) {
        current = current.addingTimeInterval(interval)
    }

    init(_ date: Date = Date(timeIntervalSince1970: 1_000_000_000)) {
        current = date
    }
}