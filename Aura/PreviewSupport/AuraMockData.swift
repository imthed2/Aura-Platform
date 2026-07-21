import Foundation

enum AuraMockData {
    static let timestamp = Date(timeIntervalSince1970: 1_767_225_600)

    static let livingRoomID = AuraRoomID(
        rawValue: deterministicUUID("00000000-0000-4000-8000-000000000001")
    )
    static let movieNightID = AuraSceneID(
        rawValue: deterministicUUID("00000000-0000-4000-8000-000000000002")
    )

    static let philipsTVID = deviceID("00000000-0000-4000-8000-000000000101")
    static let appleTVID = deviceID("00000000-0000-4000-8000-000000000102")
    static let hueBridgeID = deviceID("00000000-0000-4000-8000-000000000103")
    static let floorLampID = deviceID("00000000-0000-4000-8000-000000000104")
    static let lightStripID = deviceID("00000000-0000-4000-8000-000000000105")
    static let climateSensorID = deviceID("00000000-0000-4000-8000-000000000106")

    static let snapshot = AuraDashboardSnapshot(
        homeName: "Hagen Home",
        rooms: [livingRoom],
        devices: devices,
        featuredScene: movieNight,
        generatedAt: timestamp
    )

    static let emptySnapshot = AuraDashboardSnapshot(
        homeName: "My Home",
        rooms: [],
        devices: [],
        featuredScene: movieNight,
        generatedAt: timestamp
    )

    private static let livingRoom = AuraRoomSnapshot(
        id: livingRoomID,
        displayName: "Living Room",
        deviceIDs: [philipsTVID, appleTVID, hueBridgeID, floorLampID, lightStripID, climateSensorID],
        activeSceneID: nil
    )

    private static let movieNight = AuraSceneSnapshot(
        id: movieNightID,
        displayName: "Movie Night",
        summary: "Dim the lights and prepare the living room.",
        roomIDs: [livingRoomID],
        affectedDeviceIDs: [philipsTVID, appleTVID, floorLampID, lightStripID]
    )

    private static let devices: [AuraDeviceSnapshot] = [
        AuraDeviceSnapshot(
            id: philipsTVID,
            displayName: "Philips TV",
            category: .television,
            roomID: livingRoomID,
            pluginIdentifiers: [PluginIdentifier(rawValue: "mock.philips-tv")],
            availability: .available,
            capabilities: [.power, .volume, .mute, .inputSelection],
            state: AuraDeviceState(power: .on, volume: 0.24, isMuted: false, selectedInput: "Apple TV"),
            isFavorite: true,
            updatedAt: timestamp
        ),
        AuraDeviceSnapshot(
            id: appleTVID,
            displayName: "Apple TV",
            category: .mediaPlayer,
            roomID: livingRoomID,
            pluginIdentifiers: [PluginIdentifier(rawValue: "mock.apple-tv")],
            availability: .available,
            capabilities: [.power, .playback],
            state: AuraDeviceState(power: .on),
            isFavorite: true,
            updatedAt: timestamp
        ),
        AuraDeviceSnapshot(
            id: hueBridgeID,
            displayName: "Hue Bridge",
            category: .bridge,
            roomID: livingRoomID,
            pluginIdentifiers: [PluginIdentifier(rawValue: "mock.hue")],
            availability: .available,
            capabilities: [.bridgeManagement],
            state: AuraDeviceState(power: .on),
            isFavorite: false,
            updatedAt: timestamp
        ),
        AuraDeviceSnapshot(
            id: floorLampID,
            displayName: "Floor Lamp",
            category: .light,
            roomID: livingRoomID,
            pluginIdentifiers: [PluginIdentifier(rawValue: "mock.hue")],
            availability: .available,
            capabilities: [.power, .brightness, .colorTemperature],
            state: AuraDeviceState(power: .on, brightness: 0.42),
            isFavorite: true,
            updatedAt: timestamp
        ),
        AuraDeviceSnapshot(
            id: lightStripID,
            displayName: "TV Light Strip",
            category: .light,
            roomID: livingRoomID,
            pluginIdentifiers: [PluginIdentifier(rawValue: "mock.hue")],
            availability: .available,
            capabilities: [.power, .brightness, .color],
            state: AuraDeviceState(power: .on, brightness: 0.18),
            isFavorite: true,
            updatedAt: timestamp
        ),
        AuraDeviceSnapshot(
            id: climateSensorID,
            displayName: "Climate Sensor",
            category: .sensor,
            roomID: livingRoomID,
            pluginIdentifiers: [PluginIdentifier(rawValue: "mock.homekit")],
            availability: .available,
            capabilities: [.sensorValue],
            state: AuraDeviceState(sensorReading: "21° · 48% humidity"),
            isFavorite: false,
            updatedAt: timestamp
        ),
    ]

    private static func deviceID(_ value: String) -> AuraDeviceID {
        AuraDeviceID(rawValue: deterministicUUID(value))
    }

    private static func deterministicUUID(_ value: String) -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            preconditionFailure("Aura mock UUID fixtures must be valid")
        }
        return uuid
    }
}
