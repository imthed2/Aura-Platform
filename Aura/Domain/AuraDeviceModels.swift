import Foundation

enum AuraDeviceCategory: String, Codable, CaseIterable, Sendable {
    case television
    case mediaPlayer
    case bridge
    case light
    case sensor
}

enum AuraCapability: String, Codable, CaseIterable, Hashable, Sendable {
    case power
    case volume
    case mute
    case inputSelection
    case playback
    case brightness
    case colorTemperature
    case color
    case bridgeManagement
    case sensorValue
}

enum AuraAvailability: Codable, Equatable, Sendable {
    case available
    case unavailable
    case updating
    case stale(since: Date)
    case unknown
}

enum AuraPowerState: String, Codable, Sendable {
    case on
    case off
    case standby
    case unknown
}

struct AuraDeviceState: Codable, Equatable, Sendable {
    var power: AuraPowerState
    var brightness: Double?
    var volume: Double?
    var isMuted: Bool?
    var selectedInput: String?
    var sensorReading: String?

    init(
        power: AuraPowerState = .unknown,
        brightness: Double? = nil,
        volume: Double? = nil,
        isMuted: Bool? = nil,
        selectedInput: String? = nil,
        sensorReading: String? = nil
    ) {
        self.power = power
        self.brightness = brightness.map(Self.normalized)
        self.volume = volume.map(Self.normalized)
        self.isMuted = isMuted
        self.selectedInput = selectedInput
        self.sensorReading = sensorReading
    }

    func applying(_ operation: AuraCommandOperation) -> Self {
        var updated = self

        switch operation {
        case .setPower(let isOn):
            updated.power = isOn ? .on : .off
        case .setBrightness(let value):
            updated.brightness = Self.normalized(value)
        case .setVolume(let value):
            updated.volume = Self.normalized(value)
        case .setMuted(let isMuted):
            updated.isMuted = isMuted
        case .selectInput(let input):
            updated.selectedInput = input
        case .activate:
            break
        }

        return updated
    }

    private static func normalized(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

struct AuraDeviceSnapshot: Identifiable, Codable, Equatable, Sendable {
    let id: AuraDeviceID
    let displayName: String
    let category: AuraDeviceCategory
    let roomID: AuraRoomID?
    let pluginIdentifiers: Set<PluginIdentifier>
    let availability: AuraAvailability
    let capabilities: Set<AuraCapability>
    let state: AuraDeviceState
    let isFavorite: Bool
    let updatedAt: Date
}

struct AuraRoomSnapshot: Identifiable, Codable, Equatable, Sendable {
    let id: AuraRoomID
    let displayName: String
    let deviceIDs: [AuraDeviceID]
    let activeSceneID: AuraSceneID?
}

struct AuraSceneSnapshot: Identifiable, Codable, Equatable, Sendable {
    let id: AuraSceneID
    let displayName: String
    let summary: String
    let roomIDs: Set<AuraRoomID>
    let affectedDeviceIDs: Set<AuraDeviceID>
}

struct AuraDashboardSnapshot: Codable, Equatable, Sendable {
    let homeName: String
    let rooms: [AuraRoomSnapshot]
    let devices: [AuraDeviceSnapshot]
    let featuredScene: AuraSceneSnapshot
    let generatedAt: Date

    var favoriteDevices: [AuraDeviceSnapshot] {
        devices.filter(\.isFavorite)
    }

    var availableDeviceCount: Int {
        devices.filter { $0.availability == .available }.count
    }
}

