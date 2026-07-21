import SwiftUI

struct FoundationTabView: View {
    let title: String
    let symbol: String
    let message: String

    var body: some View {
        AuraSurface {
            AuraEmptyState(
                symbol: symbol,
                title: title,
                message: message
            )
            .padding(AuraSpacing.screen)
        }
        .navigationTitle(title)
    }
}

struct AuraRouteDestinationView: View {
    let route: AuraRoute

    var body: some View {
        AuraSurface {
            AuraEmptyState(
                symbol: symbol,
                title: title,
                message: "This typed destination is ready for its next vertical slice."
            )
            .padding(AuraSpacing.screen)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        switch route {
        case .room: "Room"
        case .device: "Device"
        case .scene: "Scene"
        case .settings(let route):
            switch route {
            case .appearance: "Appearance"
            case .accessibility: "Accessibility"
            case .privacy: "Privacy"
            case .about: "About"
            }
        }
    }

    private var symbol: String {
        switch route {
        case .room: "square.grid.2x2"
        case .device: "switch.2"
        case .scene: "sparkles"
        case .settings: "gearshape"
        }
    }
}

