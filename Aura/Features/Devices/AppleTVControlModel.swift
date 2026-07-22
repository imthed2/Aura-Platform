import Foundation
import Observation

enum AppleTVControlPhase: Equatable {
    case idle
    case connecting
    case ready
    case sending(command: AppleTVRemoteCommand)
    case confirmed(command: AppleTVRemoteCommand)
    case failed(AppleTVControlFailure)
}

enum AppleTVControlFailureReason: Equatable, Sendable {
    case deviceUnavailable
    case timedOut
    case authenticationExpired
    case commandRejected
    case commandOutcomeUnknown
    case protocolFailure
}

enum AppleTVControlRecoveryAction: Equatable, Sendable {
    case reconnect
    case pairAgain
}

struct AppleTVControlFailure: Equatable, Sendable {
    let reason: AppleTVControlFailureReason
    let title: String
    let message: String
    let recoveryAction: AppleTVControlRecoveryAction
}

@MainActor
@Observable
final class AppleTVControlModel {
    private(set) var phase: AppleTVControlPhase = .idle

    private let discovery: any AppleTVDiscovering
    private let credentialStore: any AppleTVCredentialStoring
    private let controller: any AppleTVControlling
    private let logger: any AuraLogging

    init(
        discovery: any AppleTVDiscovering,
        credentialStore: any AppleTVCredentialStoring,
        controller: any AppleTVControlling,
        logger: any AuraLogging
    ) {
        self.discovery = discovery
        self.credentialStore = credentialStore
        self.controller = controller
        self.logger = logger
    }

    @discardableResult
    func connect() async -> Bool {
        guard phase == .idle || isFailure else { return false }
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
                phase = .failed(Self.deviceUnavailableFailure)
                return false
            }

            try await controller.connect(endpoint: endpoint, credentials: credentials[0])
            phase = .ready
            return true
        } catch is CancellationError {
            phase = .idle
            return false
        } catch AppleTVControlError.cancelled {
            phase = .idle
            return false
        } catch {
            phase = .failed(failure(for: error, duringCommand: false))
            return false
        }
    }

    @discardableResult
    func send(_ command: AppleTVRemoteCommand) async -> Bool {
        guard canSendCommand else { return false }
        phase = .sending(command: command)
        do {
            let outcome = try await controller.send(command)
            guard outcome == .confirmed else {
                phase = .failed(Self.unknownCommandFailure)
                return false
            }
            phase = .confirmed(command: command)
            return true
        } catch is CancellationError {
            phase = .ready
            return false
        } catch AppleTVControlError.cancelled {
            phase = .ready
            return false
        } catch {
            phase = .failed(failure(for: error, duringCommand: true))
            return false
        }
    }

    func recover() async {
        guard case .failed(let failure) = phase,
              failure.recoveryAction == .reconnect else { return }

        logger.log(.notice, event: "apple_tv_recovery_started")
        await controller.disconnect()
        phase = .idle
        let recovered = await connect()
        if recovered {
            logger.log(.notice, event: "apple_tv_recovery_completed")
        } else if phase == .idle {
            logger.log(.notice, event: "apple_tv_recovery_cancelled")
        } else {
            logger.log(.error, event: "apple_tv_recovery_failed")
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

    private func failure(
        for error: Error,
        duringCommand: Bool
    ) -> AppleTVControlFailure {
        if duringCommand {
            switch error {
            case AppleTVControlError.authenticationFailed,
                 AppleTVControlError.invalidCredential,
                 AppleTVCredentialStoreError.invalidCredential:
                return Self.authenticationFailure
            case AppleTVControlError.commandRejected:
                return Self.commandRejectedFailure
            default:
                return Self.unknownCommandFailure
            }
        }

        return switch error {
        case AppleTVControlError.authenticationFailed,
             AppleTVControlError.invalidCredential,
             AppleTVCredentialStoreError.invalidCredential:
            Self.authenticationFailure
        case AppleTVControlError.timedOut:
            Self.timedOutFailure
        case AppleTVControlError.connectionFailed:
            Self.deviceUnavailableFailure
        default:
            Self.protocolFailure
        }
    }

    private static let deviceUnavailableFailure = AppleTVControlFailure(
        reason: .deviceUnavailable,
        title: "Apple TV unavailable",
        message: "Keep Apple TV awake and on the same Wi-Fi network, then reconnect.",
        recoveryAction: .reconnect
    )

    private static let timedOutFailure = AppleTVControlFailure(
        reason: .timedOut,
        title: "Connection timed out",
        message: "Apple TV did not respond before Aura's safety timeout.",
        recoveryAction: .reconnect
    )

    private static let authenticationFailure = AppleTVControlFailure(
        reason: .authenticationExpired,
        title: "Pairing expired",
        message: "Apple TV rejected Aura's saved credential. Pair again to replace it.",
        recoveryAction: .pairAgain
    )

    private static let commandRejectedFailure = AppleTVControlFailure(
        reason: .commandRejected,
        title: "Command rejected",
        message: "Apple TV rejected the command. Reconnect before trying another action.",
        recoveryAction: .reconnect
    )

    private static let unknownCommandFailure = AppleTVControlFailure(
        reason: .commandOutcomeUnknown,
        title: "Command outcome unknown",
        message: "Aura did not receive confirmation and will not send the command again. Reconnect before your next action.",
        recoveryAction: .reconnect
    )

    private static let protocolFailure = AppleTVControlFailure(
        reason: .protocolFailure,
        title: "Secure connection failed",
        message: "Aura could not verify the encrypted Apple TV session. Reconnect to try a fresh session.",
        recoveryAction: .reconnect
    )
}
