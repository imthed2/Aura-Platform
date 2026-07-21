@MainActor
struct AppEnvironment {
    let dashboardProvider: any DashboardProviding
    let settingsRepository: any SettingsRepository
    let navigationStore: NavigationStore
    let haptics: any HapticProviding
    let logger: any AuraLogging
    let clock: any AuraClock
    let appleTVPairingModel: AppleTVPairingModel
    let appleTVControlModel: AppleTVControlModel
}
