import Foundation

struct AuraDeviceID: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    let rawValue: UUID

    var id: UUID { rawValue }

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

struct AuraRoomID: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    let rawValue: UUID

    var id: UUID { rawValue }

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

struct AuraSceneID: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    let rawValue: UUID

    var id: UUID { rawValue }

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

struct PluginIdentifier: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    let rawValue: String

    var id: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

