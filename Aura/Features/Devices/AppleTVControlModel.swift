import Foundation
import Observation

enum AppleTVControlPhase: Equatable {
    case idle
    case connecting
    case ready
    case sending
    case confirmed
    case failed(message: String)
}

@MainActor
@Observable
final class AppleTVControlModel {
    private(set) var phase: AppleTVControlPhase = .idle

    private let discovery: any AppleTVDiscovering
    private let credentialStore: any AppleTVCredentialStoring
    private let controller: any AppleTVControlling

    init(
        discovery: any AppleTVDiscovering,
        credentialStore: any AppleTVCredentialStoring,
        controller: any AppleTVControlling
    ) {
        self.discovery = discovery
        self.credentialStore = credentialStore
        self.controller = controller
    }

    func connect() async {
        guard phase == .idle || isFailure else { return }
        phase = .connecting

        do {
            async let discoveredCandidates = discovery.discover(timeout: .seconds(5))
            async let storedCredentials = credentialStore.loadAll()
            let candidates = try await discoveredCandidates.filter { candidate in
                candidate.endpoints.contains { $0.serviceType == .companion }
            }
            let credentials = try await storedCredentials
            guard candidates.count == 1,
                  credentials.count == 1,
                  let endpoint = candidates[0].endpoints.first(where: {
                      $0.serviceType == .companion
                  }) else {
                phase = .failed(message: "Aura could not match one paired Apple TV on this network.")
                return
            }

            try await controller.connect(endpoint: endpoint, credentials: credentials[0])
            phase = .ready
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(message: controlMessage(for: error))
        }
    }

    func sendUp() async {
        guard phase == .ready || phase == .confirmed else { return }
        phase = .sending
        do {
            let outcome = try await controller.send(.up)
            guard outcome == .confirmed else {
                phase = .failed(message: "The Apple TV command outcome is unknown.")
                return
            }
            phase = .confirmed
        } catch is CancellationError {
            phase = .ready
        } catch {
            phase = .failed(message: controlMessage(for: error))
        }
    }

    func disconnect() async {
        await controller.disconnect()
        phase = .idle
    }

    private var isFailure: Bool {
        if case .failed = phase { true } else { false }
    }

    private func controlMessage(for error: Error) -> String {
        switch error {
        case AppleTVControlError.authenticationFailed:
            "Apple TV rejected the saved credential. Pair it again."
        case AppleTVControlError.timedOut:
            "Apple TV did not respond in time. Keep it awake and retry."
        case AppleTVControlError.commandRejected:
            "Apple TV rejected the navigation command."
        default:
            "Aura could not open the encrypted Apple TV control session."
        }
    }
}
