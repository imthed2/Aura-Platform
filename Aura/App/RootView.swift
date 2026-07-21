import SwiftUI

@MainActor
struct RootView: View {
    let environment: AppEnvironment
    @State private var didRestoreNavigation = false

    var body: some View {
        @Bindable var navigationStore = environment.navigationStore

        TabView(selection: $navigationStore.selectedTab) {
            ForEach(AuraTab.allCases) { tab in
                NavigationStack(path: navigationStore.binding(for: tab)) {
                    tabContent(tab)
                        .navigationDestination(for: AuraRoute.self) { route in
                            AuraRouteDestinationView(route: route)
                        }
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .tint(AuraColor.interactive)
        .task {
            await navigationStore.restore(using: environment.settingsRepository)
            didRestoreNavigation = true
        }
        .onChange(of: navigationStore.selectedTab) { _, _ in
            guard didRestoreNavigation else { return }
            Task {
                await navigationStore.persistSelection(using: environment.settingsRepository)
            }
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: AuraTab) -> some View {
        switch tab {
        case .home:
            HomeDashboardView(
                provider: environment.dashboardProvider,
                haptics: environment.haptics
            )
        case .rooms:
            FoundationTabView(
                title: "Rooms",
                symbol: "square.grid.2x2",
                message: "Your rooms will become calm dashboards for devices, scenes, and sensors."
            )
        case .scenes:
            FoundationTabView(
                title: "Scenes",
                symbol: "sparkles",
                message: "Create experiences that coordinate your home with one action."
            )
        case .devices:
            DevicesView(
                pairingModel: environment.appleTVPairingModel,
                controlModel: environment.appleTVControlModel,
                haptics: environment.haptics
            )
        case .settings:
            FoundationTabView(
                title: "Settings",
                symbol: "gearshape",
                message: "Appearance, privacy, accessibility, and integrations will live here."
            )
        }
    }
}

#Preview("Application shell") {
    RootView(environment: AppBootstrapper.makeEnvironment())
        .preferredColorScheme(.dark)
}
