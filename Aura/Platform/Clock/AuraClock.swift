import Foundation

protocol AuraClock: Sendable {
    func now() -> Date
}

struct SystemAuraClock: AuraClock {
    func now() -> Date {
        Date()
    }
}

struct FixedAuraClock: AuraClock {
    let date: Date

    func now() -> Date {
        date
    }
}

