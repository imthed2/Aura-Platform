import SwiftUI

struct HomeDashboardView: View {
    let provider: any DashboardProviding
    let haptics: any HapticProviding

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state: DashboardViewState = .loading
    @State private var showsMockNotice = false

    var body: some View {
        AuraSurface {
            Group {
                switch state {
                case .loading:
                    AuraLoadingState()
                        .padding(AuraSpacing.screen)
                case .empty:
                    AuraEmptyState(
                        symbol: "house",
                        title: "Your home is ready",
                        message: "Devices and rooms will appear here when a provider has something to show."
                    )
                    .padding(AuraSpacing.screen)
                case .failed:
                    failureContent
                case .ready(let snapshot):
                    dashboard(snapshot)
                }
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDashboard()
        }
    }

    private func dashboard(_ snapshot: AuraDashboardSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.section) {
                header(snapshot)

                if showsMockNotice {
                    AuraBanner(
                        kind: .information,
                        title: "Preview only",
                        message: "Scene execution and real device control are intentionally deferred."
                    )
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }

                featuredScene(snapshot.featuredScene)
                roomSummary(snapshot)
                favoriteDevices(snapshot.favoriteDevices)
                privacyBanner
            }
            .padding(.horizontal, AuraSpacing.screen)
            .padding(.bottom, AuraSpacing.section)
        }
        .accessibilityIdentifier("aura.home.dashboard")
        .animation(reduceMotion ? AuraMotion.instant : AuraMotion.standard, value: showsMockNotice)
    }

    private func header(_ snapshot: AuraDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AuraSpacing.xs) {
            Text("Home")
                .font(AuraTypography.display)
                .accessibilityIdentifier("aura.home.title")
            HStack(spacing: AuraSpacing.xs) {
                Text(snapshot.homeName)
                Text("•")
                    .accessibilityHidden(true)
                Text("\(snapshot.availableDeviceCount) devices available")
            }
            .font(AuraTypography.subheadline)
            .foregroundStyle(AuraColor.fog)
            .accessibilityElement(children: .combine)
        }
    }

    private func featuredScene(_ scene: AuraSceneSnapshot) -> some View {
        AuraCard(accessibilityLabel: "Featured scene, \(scene.displayName). \(scene.summary)") {
            VStack(alignment: .leading, spacing: AuraSpacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: AuraSpacing.xs) {
                        Text("SUGGESTED EXPERIENCE")
                            .font(AuraTypography.caption.weight(.semibold))
                            .foregroundStyle(AuraColor.cyan)
                        Text(scene.displayName)
                            .font(AuraTypography.largeTitle)
                        Text(scene.summary)
                            .font(AuraTypography.body)
                            .foregroundStyle(AuraColor.fog)
                    }
                    Spacer()
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: AuraSize.iconExtraLarge, weight: .light))
                        .foregroundStyle(AuraColor.warning)
                        .accessibilityHidden(true)
                }

                Spacer(minLength: AuraSpacing.sm)

                AuraButton(
                    title: "Preview Movie Night",
                    systemImage: "play.fill"
                ) {
                    haptics.play(.primaryAction)
                    showsMockNotice = true
                }
            }
            .frame(minHeight: AuraSize.heroMinimumHeight)
        }
    }

    private func roomSummary(_ snapshot: AuraDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AuraSpacing.md) {
            sectionTitle("Current room")

            ForEach(snapshot.rooms) { room in
                NavigationLink(value: AuraRoute.room(room.id)) {
                    AuraCard(accessibilityLabel: "\(room.displayName), \(room.deviceIDs.count) devices") {
                        HStack(spacing: AuraSpacing.md) {
                            Image(systemName: "sofa.fill")
                                .font(.system(size: AuraSize.iconLarge))
                                .foregroundStyle(AuraColor.cyan)
                                .frame(minWidth: AuraSize.minimumTouchTarget)

                            VStack(alignment: .leading, spacing: AuraSpacing.xxs) {
                                Text(room.displayName)
                                    .font(AuraTypography.title)
                                Text("\(room.deviceIDs.count) devices · Lights on · TV active")
                                    .font(AuraTypography.subheadline)
                                    .foregroundStyle(AuraColor.fog)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AuraColor.steel)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func favoriteDevices(_ devices: [AuraDeviceSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: AuraSpacing.md) {
            sectionTitle("Favorites")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: AuraSize.cardMinimumWidth), spacing: AuraSpacing.md)],
                spacing: AuraSpacing.md
            ) {
                ForEach(devices) { device in
                    NavigationLink(value: AuraRoute.device(device.id)) {
                        AuraDeviceCard(device: device)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var privacyBanner: some View {
        AuraBanner(
            kind: .success,
            title: "Local by design",
            message: "This dashboard is powered by deterministic mock data stored entirely in Aura."
        )
    }

    private var failureContent: some View {
        VStack(spacing: AuraSpacing.md) {
            AuraEmptyState(
                symbol: "exclamationmark.triangle",
                title: "Home could not be loaded",
                message: "Try again. No real devices or network services are involved in this milestone."
            )
            AuraButton(title: "Try Again", systemImage: "arrow.clockwise") {
                Task { await loadDashboard() }
            }
        }
        .padding(AuraSpacing.screen)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AuraTypography.title)
            .foregroundStyle(AuraColor.mist)
    }

    private func loadDashboard() async {
        state = .loading
        do {
            let snapshot = try await provider.dashboardSnapshot()
            state = snapshot.rooms.isEmpty ? .empty : .ready(snapshot)
        } catch is CancellationError {
            return
        } catch {
            state = .failed
        }
    }
}

private enum DashboardViewState: Equatable {
    case loading
    case empty
    case ready(AuraDashboardSnapshot)
    case failed
}

private struct FailingDashboardProvider: DashboardProviding {
    func dashboardSnapshot() async throws -> AuraDashboardSnapshot {
        throw AuraError.unknown
    }
}

#Preview("Home — Ready") {
    NavigationStack {
        HomeDashboardView(
            provider: MockDashboardProvider(),
            haptics: NoOpHapticService()
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Home — Empty") {
    NavigationStack {
        HomeDashboardView(
            provider: MockDashboardProvider(snapshot: AuraMockData.emptySnapshot),
            haptics: NoOpHapticService()
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Home — Error") {
    NavigationStack {
        HomeDashboardView(
            provider: FailingDashboardProvider(),
            haptics: NoOpHapticService()
        )
    }
    .preferredColorScheme(.dark)
}

