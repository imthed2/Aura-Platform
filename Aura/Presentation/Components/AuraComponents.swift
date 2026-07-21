import SwiftUI

struct AuraSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AuraColor.midnight, AuraColor.ocean],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
        .foregroundStyle(AuraColor.mist)
    }
}

struct AuraCard<Content: View>: View {
    let accessibilityLabel: String?
    @ViewBuilder let content: Content

    init(
        accessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.content = content()
    }

    var body: some View {
        content
            .padding(AuraSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AuraColor.slate.opacity(AuraOpacity.secondary))
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AuraRadius.large, style: .continuous)
                    .stroke(AuraColor.mist.opacity(AuraOpacity.faint), lineWidth: AuraSize.border)
            }
            .shadow(
                color: AuraColor.midnight.opacity(AuraOpacity.shadow),
                radius: AuraRadius.small,
                y: AuraSpacing.xxs
            )
            .accessibilityElement(children: accessibilityLabel == nil ? .contain : .combine)
            .modifier(OptionalAccessibilityLabel(label: accessibilityLabel))
    }
}

enum AuraButtonVariant {
    case primary
    case secondary
    case tertiary
    case destructive
}

struct AuraButton: View {
    let title: String
    let systemImage: String?
    var variant: AuraButtonVariant = .primary
    var isLoading = false
    var isDisabled = false
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }

                Text(title)
                    .font(AuraTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: AuraSize.buttonLarge)
            .contentShape(Rectangle())
        }
        .buttonStyle(AuraButtonPressStyle())
        .foregroundStyle(foregroundColor)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AuraRadius.medium, style: .continuous)
                .stroke(borderColor, lineWidth: AuraSize.border)
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? AuraOpacity.disabled : 1)
        .accessibilityLabel(title)
        .accessibilityValue(isLoading ? "In progress" : "")
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary: AuraColor.interactive
        case .secondary: AuraColor.mist.opacity(AuraOpacity.faint)
        case .tertiary: .clear
        case .destructive: AuraColor.error
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .destructive: AuraColor.mist
        case .secondary, .tertiary: AuraColor.cyan
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary: AuraColor.mist.opacity(AuraOpacity.subtle)
        case .primary, .tertiary, .destructive: .clear
        }
    }
}

private struct AuraButtonPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? AuraScale.pressed : 1)
            .opacity(configuration.isPressed && reduceMotion ? AuraOpacity.pressed : 1)
            .animation(reduceMotion ? AuraMotion.instant : AuraMotion.fast, value: configuration.isPressed)
    }
}

enum AuraStatus: String {
    case online = "Online"
    case offline = "Offline"
    case busy = "Busy"
    case updating = "Updating"
    case unknown = "Unknown"
    case error = "Error"

    var color: Color {
        switch self {
        case .online: AuraColor.success
        case .offline, .unknown: AuraColor.steel
        case .busy, .updating: AuraColor.warning
        case .error: AuraColor.error
        }
    }
}

struct AuraStatusBadge: View {
    let status: AuraStatus

    var body: some View {
        HStack(spacing: AuraSpacing.xs) {
            Circle()
                .fill(status.color)
                .frame(width: AuraSize.statusDot, height: AuraSize.statusDot)
            Text(status.rawValue)
                .font(AuraTypography.caption.weight(.semibold))
        }
        .padding(.horizontal, AuraSpacing.sm)
        .padding(.vertical, AuraSpacing.xs)
        .background(status.color.opacity(AuraOpacity.subtle))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status")
        .accessibilityValue(status.rawValue)
    }
}

enum AuraBannerKind {
    case information
    case success
    case warning
    case error

    var color: Color {
        switch self {
        case .information: AuraColor.cyan
        case .success: AuraColor.success
        case .warning: AuraColor.warning
        case .error: AuraColor.error
        }
    }

    var symbol: String {
        switch self {
        case .information: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }
}

struct AuraBanner: View {
    let kind: AuraBannerKind
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: AuraSpacing.sm) {
            Image(systemName: kind.symbol)
                .font(AuraTypography.title)
                .foregroundStyle(kind.color)
                .frame(width: AuraSize.bannerIconFrame)

            VStack(alignment: .leading, spacing: AuraSpacing.xxs) {
                Text(title)
                    .font(AuraTypography.headline)
                Text(message)
                    .font(AuraTypography.subheadline)
                    .foregroundStyle(AuraColor.fog)
            }
        }
        .padding(AuraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.color.opacity(AuraOpacity.faint))
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct AuraLoadingState: View {
    var body: some View {
        VStack(spacing: AuraSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                AuraCard {
                    VStack(alignment: .leading, spacing: AuraSpacing.sm) {
                        Capsule()
                            .frame(width: AuraSize.loadingLineLarge, height: AuraSize.loadingLineHeight)
                        Capsule()
                            .frame(width: AuraSize.loadingLineSmall, height: AuraSize.loadingLineHeight)
                    }
                    .foregroundStyle(AuraColor.fog.opacity(AuraOpacity.loading))
                    .redacted(reason: .placeholder)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading home")
    }
}

struct AuraEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: AuraSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: AuraSize.iconExtraLarge, weight: .light))
                .foregroundStyle(AuraColor.cyan)
            Text(title)
                .font(AuraTypography.title)
            Text(message)
                .font(AuraTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(AuraColor.fog)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct AuraDeviceCard: View {
    let device: AuraDeviceSnapshot

    var body: some View {
        AuraCard(accessibilityLabel: accessibilitySummary) {
            VStack(alignment: .leading, spacing: AuraSpacing.sm) {
                HStack {
                    Image(systemName: symbol)
                        .font(AuraTypography.title)
                        .foregroundStyle(AuraColor.cyan)
                    Spacer()
                    AuraStatusBadge(status: status)
                }

                Spacer(minLength: AuraSpacing.sm)

                Text(device.displayName)
                    .font(AuraTypography.headline)
                Text(stateSummary)
                    .font(AuraTypography.subheadline)
                    .foregroundStyle(AuraColor.fog)
            }
            .frame(minHeight: AuraSize.cardMinimumHeight)
        }
    }

    private var symbol: String {
        switch device.category {
        case .television: "tv.fill"
        case .mediaPlayer: "appletv.fill"
        case .bridge: "point.3.connected.trianglepath.dotted"
        case .light: "lightbulb.fill"
        case .sensor: "sensor.fill"
        }
    }

    private var status: AuraStatus {
        switch device.availability {
        case .available: .online
        case .unavailable: .offline
        case .updating: .updating
        case .stale, .unknown: .unknown
        }
    }

    private var stateSummary: String {
        if let sensorReading = device.state.sensorReading {
            return sensorReading
        }
        if let brightness = device.state.brightness {
            return "\(Int(brightness * 100))% brightness"
        }
        if let selectedInput = device.state.selectedInput {
            return selectedInput
        }
        switch device.state.power {
        case .on: return "On"
        case .off: return "Off"
        case .standby: return "Standby"
        case .unknown: return "State unavailable"
        }
    }

    private var accessibilitySummary: String {
        "\(device.displayName), \(status.rawValue), \(stateSummary)"
    }
}

private struct OptionalAccessibilityLabel: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}

#Preview("Components") {
    AuraSurface {
        ScrollView {
            VStack(spacing: AuraSpacing.md) {
                AuraBanner(
                    kind: .information,
                    title: "Local by design",
                    message: "Mock data stays on this iPhone."
                )
                AuraDeviceCard(device: AuraMockData.snapshot.favoriteDevices[0])
                AuraButton(title: "Primary action", systemImage: "sparkles") {}
            }
            .padding(AuraSpacing.screen)
        }
    }
    .preferredColorScheme(.dark)
}
