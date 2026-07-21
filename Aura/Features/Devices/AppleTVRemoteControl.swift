import SwiftUI

struct AppleTVRemoteControl: View {
    let isEnabled: Bool
    let onCommand: (AppleTVRemoteCommand) -> Void

    var body: some View {
        VStack(spacing: AuraSpacing.lg) {
            directionalPad
            actionRow
        }
        .frame(maxWidth: .infinity)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : AuraOpacity.disabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Apple TV remote controls")
    }

    private var directionalPad: some View {
        VStack(spacing: AuraSpacing.xs) {
            remoteButton(for: .up)
            HStack(spacing: AuraSpacing.xs) {
                remoteButton(for: .left)
                remoteButton(for: .select, prominence: .primary)
                remoteButton(for: .right)
            }
            remoteButton(for: .down)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Directional pad")
    }

    private var actionRow: some View {
        HStack(spacing: AuraSpacing.sm) {
            remoteActionButton(for: .menu)
            remoteActionButton(for: .home)
            remoteActionButton(for: .playPause)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Remote actions")
    }

    private func remoteButton(
        for command: AppleTVRemoteCommand,
        prominence: AppleTVRemoteButtonProminence = .secondary
    ) -> some View {
        Button {
            onCommand(command)
        } label: {
            Image(systemName: command.systemImage)
                .font(AuraTypography.title)
                .frame(width: AuraSize.buttonLarge, height: AuraSize.buttonLarge)
                .foregroundStyle(prominence.foregroundColor)
                .background(prominence.backgroundColor)
                .clipShape(Circle())
        }
        .buttonStyle(AuraRemoteButtonStyle())
        .accessibilityLabel(command.accessibilityLabel)
        .accessibilityIdentifier(command.accessibilityIdentifier)
    }

    private func remoteActionButton(for command: AppleTVRemoteCommand) -> some View {
        Button {
            onCommand(command)
        } label: {
            VStack(spacing: AuraSpacing.xxs) {
                Image(systemName: command.systemImage)
                    .font(AuraTypography.headline)
                Text(command.shortLabel)
                    .font(AuraTypography.caption)
            }
            .frame(maxWidth: .infinity, minHeight: AuraSize.buttonLarge)
            .foregroundStyle(AuraColor.mist)
            .background(AuraColor.slate)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium, style: .continuous))
        }
        .buttonStyle(AuraRemoteButtonStyle())
        .accessibilityLabel(command.accessibilityLabel)
        .accessibilityIdentifier(command.accessibilityIdentifier)
    }
}

private enum AppleTVRemoteButtonProminence {
    case primary
    case secondary

    var foregroundColor: Color {
        switch self {
        case .primary: AuraColor.midnight
        case .secondary: AuraColor.mist
        }
    }

    var backgroundColor: Color {
        switch self {
        case .primary: AuraColor.cyan
        case .secondary: AuraColor.slate
        }
    }
}

private struct AuraRemoteButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AuraScale.pressed : 1)
            .opacity(configuration.isPressed ? AuraOpacity.pressed : 1)
            .animation(reduceMotion ? nil : AuraMotion.instant, value: configuration.isPressed)
    }
}

extension AppleTVRemoteCommand {
    var accessibilityLabel: String {
        switch self {
        case .up: "Move up"
        case .down: "Move down"
        case .left: "Move left"
        case .right: "Move right"
        case .menu: "Back"
        case .select: "Select"
        case .home: "Home"
        case .playPause: "Play or pause"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .up: "appleTVRemote.up"
        case .down: "appleTVRemote.down"
        case .left: "appleTVRemote.left"
        case .right: "appleTVRemote.right"
        case .menu: "appleTVRemote.back"
        case .select: "appleTVRemote.select"
        case .home: "appleTVRemote.home"
        case .playPause: "appleTVRemote.playPause"
        }
    }

    fileprivate var shortLabel: String {
        switch self {
        case .menu: "Back"
        case .home: "Home"
        case .playPause: "Play/Pause"
        default: accessibilityLabel
        }
    }

    fileprivate var systemImage: String {
        switch self {
        case .up: "chevron.up"
        case .down: "chevron.down"
        case .left: "chevron.left"
        case .right: "chevron.right"
        case .menu: "chevron.backward"
        case .select: "circle.fill"
        case .home: "house.fill"
        case .playPause: "playpause.fill"
        }
    }

    var hapticEvent: AuraHapticEvent {
        switch self {
        case .select, .home, .playPause:
            .primaryAction
        case .up, .down, .left, .right, .menu:
            .selection
        }
    }
}

#Preview("Apple TV Remote") {
    AuraSurface {
        AppleTVRemoteControl(isEnabled: true) { _ in }
            .padding(AuraSpacing.screen)
    }
    .preferredColorScheme(.dark)
}
