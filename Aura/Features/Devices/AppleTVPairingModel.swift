import Foundation
import Observation

@MainActor
@Observable
final class AppleTVPairingModel {
    private(set) var phase: AppleTVPairingPhase = .idle
    var pin = ""

    private let discovery: any AppleTVDiscovering
    private let pairing: any AppleTVPairing
    private let credentialStore: any AppleTVCredentialStoring
    private var selectedCandidate: AppleTVDiscoveryCandidate?

    init(
        discovery: any AppleTVDiscovering,
        pairing: any AppleTVPairing,
        credentialStore: any AppleTVCredentialStoring
    ) {
        self.discovery = discovery
        self.pairing = pairing
        self.credentialStore = credentialStore
    }

    func discover() async {
        await pairing.cancel()
        selectedCandidate = nil
        pin = ""
        phase = .discovering

        do {
            async let discoveredCandidates = discovery.discover(timeout: .seconds(5))
            async let storedCredentials = credentialStore.loadAll()
            let candidates = try await discoveredCandidates
                .filter { candidate in
                    candidate.endpoints.contains { $0.serviceType == .companion }
                }
            let credentials = try await storedCredentials
            if candidates.count == 1, credentials.count == 1,
               let candidate = candidates.first {
                selectedCandidate = candidate
                phase = .paired(deviceName: candidate.displayName)
            } else {
                phase = .selecting(candidates)
            }
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(message: "Aura could not scan the local network. Check Local Network access and try again.")
        }
    }

    func beginPairing(with candidate: AppleTVDiscoveryCandidate) async {
        guard let endpoint = candidate.endpoints.first(where: { $0.serviceType == .companion }) else {
            phase = .failed(message: "This device does not offer the required Companion pairing service.")
            return
        }

        selectedCandidate = candidate
        phase = .starting

        do {
            try await pairing.begin(endpoint: endpoint)
            phase = .awaitingPIN(deviceName: candidate.displayName)
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(message: pairingMessage(for: error))
        }
    }

    func submitPIN() async {
        guard let selectedCandidate else {
            phase = .failed(message: "The selected Apple TV is no longer available. Scan again.")
            return
        }

        phase = .authenticating(deviceName: selectedCandidate.displayName)
        do {
            let credentials = try await pairing.finish(pin: pin)
            try await credentialStore.save(credentials)
            pin = ""
            phase = .paired(deviceName: selectedCandidate.displayName)
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(message: pairingMessage(for: error))
        }
    }

    func cancel() async {
        await pairing.cancel()
        selectedCandidate = nil
        pin = ""
        phase = .idle
    }

    var canSubmitPIN: Bool {
        pin.count >= 4 && pin.count <= 8 && pin.allSatisfy(\.isNumber)
    }

    private func pairingMessage(for error: Error) -> String {
        switch error {
        case AppleTVPairingError.invalidPIN:
            "Enter the numeric code shown on the Apple TV."
        case AppleTVPairingError.timedOut:
            "The Apple TV did not respond in time. Keep it awake and try again."
        case AppleTVPairingError.authenticationFailed:
            "The code was rejected or the secure response could not be verified. Start pairing again."
        case is AppleTVCredentialStoreError:
            "Pairing completed, but Aura could not protect the credentials in Keychain. Remove Aura from Apple TV remotes and try again."
        default:
            "Aura could not complete secure Apple TV pairing. Keep the Apple TV awake and try again."
        }
    }
}
