import Foundation

struct AppleTVPairingCredentials: Codable, Equatable, Sendable {
    let accessoryPublicKey: Data
    let controllerPrivateKey: Data
    let accessoryIdentifier: Data
    let controllerIdentifier: Data
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
