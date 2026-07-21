import Foundation
import Observation

enum AppleTVControlPhase: Equatable {
    case idle
    case connecting
    case ready
    case sending(command: AppleTVRemoteCommand)
    case confirmed(command: AppleTVRemoteCommand)
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

    @discardableResult
    func send(_ command: AppleTVRemoteCommand) async -> Bool {
        guard canSendCommand else { return false }
        phase = .sending(command: command)
        do {
            let outcome = try await controller.send(command)
            guard outcome == .confirmed else {
                phase = .failed(message: "The Apple TV command outcome is unknown.")
                return false
            }
            phase = .confirmed(command: command)
            return true
        } catch is CancellationError {
            phase = .ready
            return false
        } catch {
            phase = .failed(message: controlMessage(for: error))
            return false
        }
    }

    func disconnect() async {
        await controller.disconnect()
        phase = .idle
    }

    private var isFailure: Bool {
        if case .failed = phase { true } else { false }
    }

    private var canSendCommand: Bool {
        switch phase {
        case .ready, .confirmed:
            true
        default:
            false
        }
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
