import SwiftUI

struct DevicesView: View {
    @Bindable var pairingModel: AppleTVPairingModel
    @Bindable var controlModel: AppleTVControlModel

    var body: some View {
        AuraSurface {
            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.lg) {
                    AuraBanner(
                        kind: .warning,
                        title: "Experimental Apple TV control",
                        message: "Pairing stays on your local network. Compatibility can change with tvOS updates."
                    )

                    content
                }
                .padding(AuraSpacing.screen)
            }
        }
        .navigationTitle("Devices")
        .task {
            if pairingModel.phase == .idle {
                await pairingModel.discover()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch pairingModel.phase {
        case .idle:
            AuraButton(title: "Scan for Apple TV", systemImage: "dot.radiowaves.left.and.right") {
                Task { await pairingModel.discover() }
            }

        case .discovering:
            statusCard(
                title: "Scanning your network",
                message: "Looking only for Apple TV Companion services.",
                showsProgress: true
            )

        case .selecting(let candidates):
            if candidates.isEmpty {
                AuraCard {
                    VStack(alignment: .leading, spacing: AuraSpacing.md) {
                        AuraEmptyState(
                            symbol: "appletv",
                            title: "No Apple TV found",
                            message: "Keep the Apple TV awake and confirm this iPhone is on the same Wi-Fi network."
                        )
                        .frame(minHeight: AuraSize.heroMinimumHeight)

                        AuraButton(title: "Scan again", systemImage: "arrow.clockwise") {
                            Task { await pairingModel.discover() }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: AuraSpacing.md) {
                    Text("Choose a device")
                        .font(AuraTypography.title)

                    ForEach(candidates, id: \.self) { candidate in
                        AuraCard(accessibilityLabel: "Pair with \(candidate.displayName)") {
                            VStack(alignment: .leading, spacing: AuraSpacing.md) {
                                Label(candidate.displayName, systemImage: "appletv.fill")
                                    .font(AuraTypography.headline)
                                Text("Companion service available")
                                    .font(AuraTypography.subheadline)
                                    .foregroundStyle(AuraColor.fog)
                                AuraButton(title: "Pair", systemImage: "link") {
                                    Task { await pairingModel.beginPairing(with: candidate) }
                                }
                            }
                        }
                    }

                    AuraButton(
                        title: "Scan again",
                        systemImage: "arrow.clockwise",
                        variant: .tertiary
                    ) {
                        Task { await pairingModel.discover() }
                    }
                }
            }

        case .starting:
            statusCard(
                title: "Starting secure pairing",
                message: "A code should appear on the Apple TV in a moment.",
                showsProgress: true
            )

        case .awaitingPIN(let deviceName):
            AuraCard {
                VStack(alignment: .leading, spacing: AuraSpacing.md) {
                    Text("Enter the code from \(deviceName)")
                        .font(AuraTypography.title)
                    Text("Aura will verify the encrypted response before saving credentials.")
                        .font(AuraTypography.body)
                        .foregroundStyle(AuraColor.fog)

                    TextField("Pairing code", text: $pairingModel.pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(AuraTypography.display.monospacedDigit())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AuraColor.midnight)
                        .padding(AuraSpacing.md)
                        .background(AuraColor.mist)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium, style: .continuous))
                        .accessibilityIdentifier("appleTVPairingCode")

                    AuraButton(
                        title: "Verify and pair",
                        systemImage: "lock.shield",
                        isDisabled: !pairingModel.canSubmitPIN
                    ) {
                        Task { await pairingModel.submitPIN() }
                    }

                    AuraButton(title: "Cancel", systemImage: "xmark", variant: .tertiary) {
                        Task { await pairingModel.cancel() }
                    }
                }
            }

        case .authenticating(let deviceName):
            statusCard(
                title: "Verifying \(deviceName)",
                message: "Checking the server proof and device identity signature.",
                showsProgress: true
            )

        case .paired(let deviceName):
            VStack(spacing: AuraSpacing.md) {
                AuraBanner(
                    kind: .success,
                    title: "Apple TV paired",
                    message: "Credentials for \(deviceName) are protected in this iPhone's Keychain."
                )
                remoteTestCard
                AuraButton(title: "Done", systemImage: "checkmark", variant: .secondary) {
                    Task {
                        await controlModel.disconnect()
                        await pairingModel.cancel()
                    }
                }
            }

        case .failed(let message):
            VStack(spacing: AuraSpacing.md) {
                AuraBanner(kind: .error, title: "Pairing did not finish", message: message)
                AuraButton(title: "Start again", systemImage: "arrow.clockwise") {
                    Task { await pairingModel.discover() }
                }
            }
        }
    }

    @ViewBuilder
    private var remoteTestCard: some View {
        AuraCard(accessibilityLabel: "Experimental Apple TV remote") {
            VStack(alignment: .leading, spacing: AuraSpacing.md) {
                Text("Encrypted remote test")
                    .font(AuraTypography.title)

                switch controlModel.phase {
                case .idle, .connecting:
                    HStack(spacing: AuraSpacing.md) {
                        ProgressView()
                            .tint(AuraColor.cyan)
                        Text("Opening a verified Companion session…")
                            .font(AuraTypography.body)
                            .foregroundStyle(AuraColor.fog)
                    }
                    .task { await controlModel.connect() }

                case .ready:
                    Text("Connected securely. Keep the Apple TV interface visible, then send one test command.")
                        .font(AuraTypography.body)
                        .foregroundStyle(AuraColor.fog)
                    AuraButton(title: "Move focus up", systemImage: "arrow.up") {
                        Task { await controlModel.sendUp() }
                    }
                    .accessibilityIdentifier("appleTVMoveFocusUp")

                case .sending:
                    HStack(spacing: AuraSpacing.md) {
                        ProgressView()
                            .tint(AuraColor.cyan)
                        Text("Waiting for Apple TV confirmation…")
                            .font(AuraTypography.body)
                            .foregroundStyle(AuraColor.fog)
                    }

                case .confirmed:
                    AuraBanner(
                        kind: .success,
                        title: "Command confirmed",
                        message: "Apple TV acknowledged both the button-down and button-up messages."
                    )
                    AuraButton(title: "Move focus up again", systemImage: "arrow.up") {
                        Task { await controlModel.sendUp() }
                    }

                case .failed(let message):
                    AuraBanner(kind: .error, title: "Remote unavailable", message: message)
                    AuraButton(title: "Reconnect", systemImage: "arrow.clockwise") {
                        Task { await controlModel.connect() }
                    }
                }
            }
        }
    }

    private func statusCard(
        title: String,
        message: String,
        showsProgress: Bool
    ) -> some View {
        AuraCard(accessibilityLabel: "\(title). \(message)") {
            HStack(spacing: AuraSpacing.md) {
                if showsProgress {
                    ProgressView()
                        .tint(AuraColor.cyan)
                }
                VStack(alignment: .leading, spacing: AuraSpacing.xs) {
                    Text(title)
                        .font(AuraTypography.headline)
                    Text(message)
                        .font(AuraTypography.subheadline)
                        .foregroundStyle(AuraColor.fog)
                }
            }
        }
    }
}
