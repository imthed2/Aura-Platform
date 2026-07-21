@MainActor
enum AppBootstrapper {
    static func makeEnvironment() -> AppEnvironment {
        AppEnvironment(
            dashboardProvider: MockDashboardProvider(),
            settingsRepository: UserDefaultsSettingsRepository(),
            navigationStore: NavigationStore(),
            haptics: SystemHapticService(),
            logger: SystemAuraLogger(),
            clock: SystemAuraClock()
        )
    }
}

