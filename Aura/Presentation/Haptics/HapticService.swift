import UIKit

enum AuraHapticEvent: Sendable {
    case selection
    case primaryAction
    case success
    case warning
    case failure
}

@MainActor
protocol HapticProviding: AnyObject, Sendable {
    func play(_ event: AuraHapticEvent)
}

@MainActor
final class SystemHapticService: HapticProviding {
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    init() {
        selectionGenerator.prepare()
    }

    func play(_ event: AuraHapticEvent) {
        switch event {
        case .selection:
            selectionGenerator.selectionChanged()
        case .primaryAction:
            impactGenerator.impactOccurred()
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .failure:
            notificationGenerator.notificationOccurred(.error)
        }
    }
}

@MainActor
final class NoOpHapticService: HapticProviding {
    func play(_ event: AuraHapticEvent) {}
}

