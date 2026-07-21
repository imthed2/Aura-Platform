import Foundation

@MainActor
enum AppBootstrapper {
    static func makeEnvironment() -> AppEnvironment {
        let logger = SystemAuraLogger()
        let pairing = AppleTVPairingClient(logger: logger)
        let discovery = AppleTVDiscoveryClient(logger: logger)
        let credentialStore = AppleTVKeychainCredentialStore()

        return AppEnvironment(
            dashboardProvider: MockDashboardProvider(),
            settingsRepository: settingsRepository,
            navigationStore: NavigationStore(selectedTab: initialTab),
            haptics: SystemHapticService(),
            logger: logger,
            clock: SystemAuraClock(),
            appleTVPairingModel: AppleTVPairingModel(
                discovery: discovery,
                pairing: pairing,
                credentialStore: credentialStore
            ),
            appleTVControlModel: AppleTVControlModel(
                discovery: discovery,
                credentialStore: credentialStore,
                controller: AppleTVCompanionClient(logger: logger)
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
