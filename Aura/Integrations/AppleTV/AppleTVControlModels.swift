import Foundation

enum AppleTVRemoteCommand: UInt64, CaseIterable, Sendable {
    case up = 1
    case down = 2
    case left = 3
    case right = 4
    case menu = 5
    case select = 6
    case home = 7
    case playPause = 14
}

enum AppleTVControlError: Error, Equatable, Sendable {
    case invalidCredential
    case invalidState
    case connectionFailed
    case authenticationFailed
    case protocolViolation
    case commandRejected
    case timedOut
    case cancelled
}

enum AppleTVCommandOutcome: Equatable, Sendable {
    case confirmed
}

protocol AppleTVControlling: Sendable {
    func connect(
        endpoint: AppleTVBonjourEndpoint,
        credentials: AppleTVPairingCredentials
    ) async throws
    func send(_ command: AppleTVRemoteCommand) async throws -> AppleTVCommandOutcome
    func disconnect() async
}
