import XCTest
import Crypto
import SRP
@testable import Aura

final class AppleTVPairingCodecTests: XCTestCase {
    func testHAPSRPProofMatchesCompanionReferenceVector() throws {
        let configuration = SRPConfiguration<SHA512>(.N3072)
        let sharedSecret = try XCTUnwrap(SRPKey(hex: "000102030405060708090a0b0c0d0e0f"))
        let clientPublicKey = try XCTUnwrap(SRPKey(hex: "00a1b2c3d4e5f6"))
        let serverPublicKey = try XCTUnwrap(SRPKey(hex: "00fedcba9876543210"))
        let sessionKey = AppleTVHAPSRP.sessionKey(sharedSecret: sharedSecret)

        XCTAssertEqual(
            sessionKey.hexString,
            "e013ac44f4a653a96cf3c120d9a741f9a2f2a56628e93a43e78907bc85c5ffb8" +
                "c2a7a29885880e31e541cafc956576089095f090fe721d8a3d5e0b1b07b6d36d"
        )

        let proof = AppleTVHAPSRP.clientProof(
            configuration: configuration,
            username: "Pair-Setup",
            salt: Array(Data(hex: "00112233445566778899aabbccddeeff")),
            clientPublicKey: clientPublicKey,
            serverPublicKey: serverPublicKey,
            sessionKey: sessionKey
        )
        XCTAssertEqual(
            Data(proof).hexString,
            "a0f50e1adecc998603091a5900fa541b352ef73968b77a1ce13f3f509f2f18f01" +
                "766d7c9830a6e9f30211dc9526d7c78d230851628b9b528598e3261a3a78e7f"
        )

        let serverProof = Data(
            hex: "bf2e3f300fc97a589bef861e725abda08dfcad0311314d1c6196b85b0bfe6648" +
                "4285d61f72a395373c5330fcb1317919c8345d6df9a97644d3926094f37a5370"
        )
        XCTAssertTrue(AppleTVHAPSRP.verifyServerProof(
            Array(serverProof),
            clientProof: proof,
            clientPublicKey: clientPublicKey,
            sessionKey: sessionKey
        ))
    }

    func testCompanionFrameRoundTrip() throws {
        let original = CompanionFrame(
            type: .pairSetupStart,
            payload: Data([0x01, 0x02, 0x03])
        )

        let encoded = try CompanionFrameCodec.encode(original)
        let header = encoded.prefix(CompanionFrame.headerLength)
        let payload = encoded.dropFirst(CompanionFrame.headerLength)

        XCTAssertEqual(try CompanionFrameCodec.payloadLength(from: header), 3)
        XCTAssertEqual(
            try CompanionFrameCodec.decode(header: header, payload: payload),
            original
        )
    }

    func testCompanionFrameRejectsOversizedPayload() {
        let frame = CompanionFrame(
            type: .pairSetupStart,
            payload: Data(repeating: 0, count: CompanionFrame.maximumPayloadLength + 1)
        )

        XCTAssertThrowsError(try CompanionFrameCodec.encode(frame)) { error in
            XCTAssertEqual(error as? CompanionFrameCodecError, .payloadTooLarge)
        }
    }

    func testTLV8SplitsAndReassemblesLongValues() throws {
        let value = Data((0..<600).map { UInt8($0 % 251) })
        let encoded = try HAPTLV8.encode([HAPTLVEntry(tag: .publicKey, value: value)])

        XCTAssertEqual(try HAPTLV8.decode(encoded)[.publicKey], value)
    }

    func testTLV8RejectsTruncatedValue() {
        XCTAssertThrowsError(try HAPTLV8.decode(Data([0x03, 0x02, 0x01]))) { error in
            XCTAssertEqual(error as? HAPTLV8Error, .malformed)
        }
    }

    func testTLV8AcceptsDataSliceWithNonzeroStartIndex() throws {
        let encoded = try HAPTLV8.encode([
            HAPTLVEntry(tag: .sequence, value: Data([0x02]))
        ])
        let wrapped = Data([0xFF]) + encoded
        let slice = wrapped.dropFirst()

        XCTAssertNotEqual(slice.startIndex, 0)
        XCTAssertEqual(try HAPTLV8.decode(slice)[.sequence], Data([0x02]))
    }

    func testTLV8SkipsBoundedUnknownTags() throws {
        let encoded = Data([0x7F, 0x02, 0xAA, 0xBB, 0x06, 0x01, 0x02])

        XCTAssertEqual(try HAPTLV8.decode(encoded)[.sequence], Data([0x02]))
    }

    func testPairSetupStartOPACKMatchesObservedCompanionShape() throws {
        let pairingData = try HAPTLV8.encode([
            HAPTLVEntry(tag: .method, value: Data([0x00])),
            HAPTLVEntry(tag: .sequence, value: Data([0x01]))
        ])
        let value = OPACKValue.dictionary([
            "_pd": .data(pairingData),
            "_pwTy": .integer(1)
        ])

        let encoded = try OPACKCodec.encode(value)

        XCTAssertEqual(
            encoded,
            Data([0xE2, 0x43, 0x5F, 0x70, 0x64, 0x76, 0x00, 0x01, 0x00, 0x06, 0x01, 0x01,
                  0x45, 0x5F, 0x70, 0x77, 0x54, 0x79, 0x09])
        )
        XCTAssertEqual(try OPACKCodec.decode(encoded), value)
    }

    func testOPACKRejectsTrailingData() throws {
        let valid = try OPACKCodec.encode(.integer(1))
        XCTAssertThrowsError(try OPACKCodec.decode(valid + Data([0x04]))) { error in
            XCTAssertEqual(error as? OPACKCodecError, .trailingData)
        }
    }

    func testEncryptedSessionNonceUsesLittleEndianCounterAndTwelveBytes() {
        XCTAssertEqual(
            AppleTVSessionCrypto.nonceData(counter: 0x0102_0304_0506_0708),
            Data([0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0, 0, 0, 0])
        )
    }
}

private extension Data {
    init(hex: String) {
        self.init(stride(from: 0, to: hex.count, by: 2).compactMap { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let end = hex.index(start, offsetBy: 2)
            return UInt8(hex[start..<end], radix: 16)
        })
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class AppleTVPairingModelTests: XCTestCase {
    func testDiscoveryFiltersCandidatesWithoutCompanionService() async {
        let companion = candidate(name: "Apple TV", service: .companion)
        let mediaRemote = candidate(name: "Legacy", service: .mediaRemote)
        let model = AppleTVPairingModel(
            discovery: StubAppleTVDiscovery(candidates: [mediaRemote, companion]),
            pairing: StubAppleTVPairing(),
            credentialStore: StubAppleTVCredentialStore()
        )

        await model.discover()

        XCTAssertEqual(model.phase, .selecting([companion]))
    }

    func testSuccessfulFlowStoresVerifiedCredentials() async {
        let candidate = candidate(name: "Apple TV", service: .companion)
        let store = StubAppleTVCredentialStore()
        let model = AppleTVPairingModel(
            discovery: StubAppleTVDiscovery(candidates: [candidate]),
            pairing: StubAppleTVPairing(),
            credentialStore: store
        )

        await model.discover()
        await model.beginPairing(with: candidate)
        model.pin = "1234"
        await model.submitPIN()

        XCTAssertEqual(model.phase, .paired(deviceName: "Apple TV"))
        let savedCount = await store.savedCountValue()
        XCTAssertEqual(savedCount, 1)
    }

    func testDiscoveryRestoresSinglePairedDevice() async {
        let candidate = candidate(name: "Apple TV", service: .companion)
        let store = StubAppleTVCredentialStore(credentials: [.fixture])
        let model = AppleTVPairingModel(
            discovery: StubAppleTVDiscovery(candidates: [candidate]),
            pairing: StubAppleTVPairing(),
            credentialStore: store
        )

        await model.discover()

        XCTAssertEqual(model.phase, .paired(deviceName: "Apple TV"))
    }

    func testPINValidationIsLocalAndDeterministic() {
        let model = AppleTVPairingModel(
            discovery: StubAppleTVDiscovery(candidates: []),
            pairing: StubAppleTVPairing(),
            credentialStore: StubAppleTVCredentialStore()
        )

        model.pin = "12ab"
        XCTAssertFalse(model.canSubmitPIN)
        model.pin = "1234"
        XCTAssertTrue(model.canSubmitPIN)
    }

    private func candidate(
        name: String,
        service: AppleTVBonjourService
    ) -> AppleTVDiscoveryCandidate {
        AppleTVDiscoveryCandidate(
            displayName: name,
            endpoints: [AppleTVBonjourEndpoint(
                serviceName: name,
                serviceType: service,
                domain: "local."
            )]
        )
    }
}

@MainActor
final class AppleTVControlModelTests: XCTestCase {
    func testVerifiedSessionConfirmsUpCommand() async {
        let candidate = AppleTVDiscoveryCandidate(
            displayName: "Apple TV",
            endpoints: [AppleTVBonjourEndpoint(
                serviceName: "Apple TV",
                serviceType: .companion,
                domain: "local."
            )]
        )
        let controller = StubAppleTVController()
        let model = AppleTVControlModel(
            discovery: StubAppleTVDiscovery(candidates: [candidate]),
            credentialStore: StubAppleTVCredentialStore(credentials: [.fixture]),
            controller: controller
        )

        await model.connect()
        XCTAssertEqual(model.phase, .ready)

        await model.sendUp()
        XCTAssertEqual(model.phase, .confirmed)
        let lastCommand = await controller.lastCommandValue()
        XCTAssertEqual(lastCommand, .up)
    }

    func testConnectFailsClosedWhenCredentialCannotBeMatchedUniquely() async {
        let model = AppleTVControlModel(
            discovery: StubAppleTVDiscovery(candidates: []),
            credentialStore: StubAppleTVCredentialStore(credentials: [.fixture]),
            controller: StubAppleTVController()
        )

        await model.connect()

        guard case .failed = model.phase else {
            return XCTFail("Expected a failed control state")
        }
    }
}

private struct StubAppleTVDiscovery: AppleTVDiscovering {
    let candidates: [AppleTVDiscoveryCandidate]

    func discover(timeout: Duration) async throws -> [AppleTVDiscoveryCandidate] {
        candidates
    }
}

private actor StubAppleTVPairing: AppleTVPairing {
    func begin(endpoint: AppleTVBonjourEndpoint) {}

    func finish(pin: String) -> AppleTVPairingCredentials {
        AppleTVPairingCredentials(
            accessoryPublicKey: Data(repeating: 1, count: 32),
            controllerPrivateKey: Data(repeating: 2, count: 32),
            accessoryIdentifier: Data("accessory".utf8),
            controllerIdentifier: Data("controller".utf8)
        )
    }

    func cancel() {}
}

private actor StubAppleTVCredentialStore: AppleTVCredentialStoring {
    private(set) var savedCount = 0
    private var credentials: [AppleTVPairingCredentials]

    init(credentials: [AppleTVPairingCredentials] = []) {
        self.credentials = credentials
    }

    func save(_ credentials: AppleTVPairingCredentials) {
        savedCount += 1
        self.credentials.append(credentials)
    }

    func loadAll() -> [AppleTVPairingCredentials] { credentials }

    func remove(_ credentials: AppleTVPairingCredentials) {}

    func savedCountValue() -> Int {
        savedCount
    }
}

private actor StubAppleTVController: AppleTVControlling {
    private var lastCommand: AppleTVRemoteCommand?

    func connect(
        endpoint: AppleTVBonjourEndpoint,
        credentials: AppleTVPairingCredentials
    ) {}

    func send(_ command: AppleTVRemoteCommand) -> AppleTVCommandOutcome {
        lastCommand = command
        return .confirmed
    }

    func disconnect() {}

    func lastCommandValue() -> AppleTVRemoteCommand? { lastCommand }
}

private extension AppleTVPairingCredentials {
    static let fixture = AppleTVPairingCredentials(
        accessoryPublicKey: Data(repeating: 1, count: 32),
        controllerPrivateKey: Data(repeating: 2, count: 32),
        accessoryIdentifier: Data("accessory".utf8),
        controllerIdentifier: Data("controller".utf8)
    )
}
