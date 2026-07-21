import Foundation

enum AuraCommandOrigin: String, Codable, Sendable {
    case userInterface
    case scene
    case automation
    case diagnostics
}

enum AuraCommandOperation: Codable, Equatable, Sendable {
    case setPower(Bool)
    case setBrightness(Double)
    case setVolume(Double)
    case setMuted(Bool)
    case selectInput(String)
    case activate
}

struct AuraCommand: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let deviceID: AuraDeviceID
    let capability: AuraCapability
    let operation: AuraCommandOperation
    let origin: AuraCommandOrigin
    let requestedAt: Date
}

enum AuraError: Error, Codable, Equatable, Sendable {
    case validation
    case authorizationDenied
    case unavailable
    case unsupportedCapability
    case timedOut
    case cancelled
    case transientFailure
    case partialFailure
    case unknown
}

enum AuraCommandResult: Codable, Equatable, Sendable {
    case confirmed(AuraDeviceState)
    case acceptedPending(commandID: UUID)
    case partialSuccess(confirmed: AuraDeviceState, failedCapabilities: Set<AuraCapability>)
    case rejected(AuraError)
}

