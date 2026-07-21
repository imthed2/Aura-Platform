import SwiftUI

@main
@MainActor
struct AuraApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var environment: AppEnvironment
    @State private var lifecycleCoordinator: AppLifecycleCoordinator

    init() {
        let environment = AppBootstrapper.makeEnvironment()
        _environment = State(initialValue: environment)
        _lifecycleCoordinator = State(
            initialValue: AppLifecycleCoordinator(logger: environment.logger)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase, initial: true) { _, newPhase in
                    lifecycleCoordinator.handle(newPhase)
                }
        }
    }
}

