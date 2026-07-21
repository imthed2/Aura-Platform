import Observation
import SwiftUI

enum AuraTab: String, CaseIterable, Codable, Identifiable, Sendable {
    case home
    case rooms
    case scenes
    case devices
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .rooms: "Rooms"
        case .scenes: "Scenes"
        case .devices: "Devices"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .rooms: "square.grid.2x2.fill"
        case .scenes: "sparkles"
        case .devices: "switch.2"
        case .settings: "gearshape.fill"
        }
    }
}

enum AuraSettingsRoute: String, Codable, Hashable, Sendable {
    case appearance
    case accessibility
    case privacy
    case about
}

enum AuraRoute: Codable, Hashable, Sendable {
    case room(AuraRoomID)
    case device(AuraDeviceID)
    case scene(AuraSceneID)
    case settings(AuraSettingsRoute)
}

@MainActor
@Observable
final class NavigationStore {
    var selectedTab: AuraTab
    private var paths: [AuraTab: [AuraRoute]]

    init(selectedTab: AuraTab = .home) {
        self.selectedTab = selectedTab
        paths = Dictionary(uniqueKeysWithValues: AuraTab.allCases.map { ($0, []) })
    }

    func binding(for tab: AuraTab) -> Binding<[AuraRoute]> {
        Binding(
            get: { self.paths[tab, default: []] },
            set: { self.paths[tab] = $0 }
        )
    }

    func navigate(to route: AuraRoute, in tab: AuraTab? = nil) {
        let destinationTab = tab ?? selectedTab
        paths[destinationTab, default: []].append(route)
    }

    func restore(using repository: any SettingsRepository) async {
        guard
            let rawValue = await repository.string(for: .selectedTab),
            let tab = AuraTab(rawValue: rawValue)
        else { return }

        selectedTab = tab
    }

    func persistSelection(using repository: any SettingsRepository) async {
        await repository.set(selectedTab.rawValue, for: .selectedTab)
    }
}

