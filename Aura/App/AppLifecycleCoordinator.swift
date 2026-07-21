import Observation
import SwiftUI

@MainActor
@Observable
final class AppLifecycleCoordinator {
    private(set) var phase: ScenePhase = .inactive
    private let logger: any AuraLogging

    init(logger: any AuraLogging) {
        self.logger = logger
    }

    func handle(_ newPhase: ScenePhase) {
        guard phase != newPhase else { return }
        phase = newPhase

        switch newPhase {
        case .active:
            logger.log(.notice, event: "application_became_active")
        case .inactive:
            logger.log(.debug, event: "application_became_inactive")
        case .background:
            logger.log(.notice, event: "application_entered_background")
        @unknown default:
            logger.log(.error, event: "application_entered_unknown_phase")
        }
    }
}

