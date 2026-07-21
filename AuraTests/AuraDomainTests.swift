import XCTest
@testable import Aura

final class AuraDomainTests: XCTestCase {
    func testDeviceIdentifierCodableRoundTripPreservesIdentity() throws {
        let identifier = AuraDeviceID(
            rawValue: try XCTUnwrap(UUID(uuidString: "10000000-0000-4000-8000-000000000001"))
        )

        let encoded = try JSONEncoder().encode(identifier)
        let decoded = try JSONDecoder().decode(AuraDeviceID.self, from: encoded)

        XCTAssertEqual(decoded, identifier)
    }

    func testDeviceStateClampsNormalizedValues() {
        let initial = AuraDeviceState(power: .off, brightness: 0.2, volume: 0.4)

        let brightened = initial.applying(.setBrightness(1.4))
        let quieted = brightened.applying(.setVolume(-0.2))

        XCTAssertEqual(brightened.brightness, 1)
        XCTAssertEqual(quieted.volume, 0)
        XCTAssertEqual(quieted.power, .off)
    }

    func testCommandStateTransformationChangesOnlyRequestedCapability() throws {
        let initial = AuraDeviceState(
            power: .on,
            brightness: 0.4,
            volume: 0.2,
            isMuted: false,
            selectedInput: "Apple TV"
        )

        let updated = initial.applying(.setMuted(true))

        XCTAssertTrue(try XCTUnwrap(updated.isMuted))
        XCTAssertEqual(updated.power, initial.power)
        XCTAssertEqual(updated.brightness, initial.brightness)
        XCTAssertEqual(updated.volume, initial.volume)
        XCTAssertEqual(updated.selectedInput, initial.selectedInput)
    }

    func testMockHomeIsDeterministicAndContainsRequiredFixtures() {
        let snapshot = AuraMockData.snapshot

        XCTAssertEqual(snapshot.rooms.map(\.displayName), ["Living Room"])
        XCTAssertEqual(snapshot.devices.count, 6)
        XCTAssertEqual(snapshot.devices.filter { $0.category == .light }.count, 2)
        XCTAssertTrue(snapshot.devices.contains { $0.displayName == "Philips TV" })
        XCTAssertTrue(snapshot.devices.contains { $0.displayName == "Apple TV" })
        XCTAssertTrue(snapshot.devices.contains { $0.displayName == "Hue Bridge" })
        XCTAssertTrue(snapshot.devices.contains { $0.category == .sensor })
        XCTAssertEqual(snapshot.featuredScene.displayName, "Movie Night")
        XCTAssertEqual(snapshot.generatedAt, AuraMockData.timestamp)
    }

    @MainActor
    func testNavigationStoreMaintainsIndependentTabPaths() {
        let store = NavigationStore()
        store.navigate(to: .room(AuraMockData.livingRoomID), in: .rooms)
        store.navigate(to: .device(AuraMockData.philipsTVID), in: .devices)

        XCTAssertEqual(store.binding(for: .rooms).wrappedValue.count, 1)
        XCTAssertEqual(store.binding(for: .devices).wrappedValue.count, 1)
        XCTAssertTrue(store.binding(for: .home).wrappedValue.isEmpty)
    }
}

