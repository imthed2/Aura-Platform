import OSLog

enum AuraLogLevel: Sendable {
    case debug
    case notice
    case error
}

protocol AuraLogging: Sendable {
    func log(_ level: AuraLogLevel, event: String)
}

struct SystemAuraLogger: AuraLogging {
    private let logger = Logger(subsystem: "com.danielhagen.aura", category: "application")

    func log(_ level: AuraLogLevel, event: String) {
        switch level {
        case .debug:
            logger.debug("\(event, privacy: .public)")
        case .notice:
            logger.notice("\(event, privacy: .public)")
        case .error:
            logger.error("\(event, privacy: .public)")
        }
    }
}

struct NoOpAuraLogger: AuraLogging {
    func log(_ level: AuraLogLevel, event: String) {}
}

