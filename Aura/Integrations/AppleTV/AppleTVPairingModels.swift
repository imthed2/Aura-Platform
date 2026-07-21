import Foundation

struct AppleTVPairingCredentials: Codable, Equatable, Sendable {
    let accessoryPublicKey: Data
    let controllerPrivateKey: Data
    let accessoryIdentifier: Data
    let controllerIdentifier: Data

    var isStructurallyValid: Bool {
        accessoryPublicKey.count == 32
            && controllerPrivateKey.count == 32
            && (1...256).contains(accessoryIdentifier.count)
            && (1...256).contains(controllerIdentifier.count)
    }
}

enum AppleTVPairingPhase: Equatable, Sendable {
    case idle
    case discovering
    case selecting([AppleTVDiscoveryCandidate])
    case starting
    case awaitingPIN(deviceName: String)
    case authenticating(deviceName: String)
    case paired(deviceName: String)
    case failed(message: String)
}

enum AppleTVPairingError: Error, Equatable, Sendable {
    case invalidState
    case companionServiceUnavailable
    case invalidPIN
    case connectionFailed
    case timedOut
    case protocolViolation
    case authenticationFailed
    case cancelled
}

protocol AppleTVPairing: Sendable {
    func begin(endpoint: AppleTVBonjourEndpoint) async throws
    func finish(pin: String) async throws -> AppleTVPairingCredentials
    func cancel() async
}
