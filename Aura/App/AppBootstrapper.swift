import Foundation

@MainActor
enum AppBootstrapper {
    static func makeEnvironment() -> AppEnvironment {
        let logger = SystemAuraLogger()
        let pairing = AppleTVPairingClient(logger: logger)

        return AppEnvironment(
            dashboardProvider: MockDashboardProvider(),
            settingsRepository: settingsRepository,
            navigationStore: NavigationStore(selectedTab: initialTab),
            haptics: SystemHapticService(),
            logger: logger,
            clock: SystemAuraClock(),
            appleTVPairingModel: AppleTVPairingModel(
                discovery: AppleTVDiscoveryClient(logger: logger),
                pairing: pairing,
                credentialStore: AppleTVKeychainCredentialStore()
            )
        )
    }

    private static var initialTab: AuraTab {
        debugInitialTab ?? .home
    }

    private static var settingsRepository: any SettingsRepository {
        debugInitialTab == nil ? UserDefaultsSettingsRepository() : InMemorySettingsRepository()
    }

    private static var debugInitialTab: AuraTab? {
#if DEBUG
        if let rawValue = ProcessInfo.processInfo.environment["AURA_START_TAB"],
           let tab = AuraTab(rawValue: rawValue) {
            return tab
        }
#endif
        return nil
    }
}
