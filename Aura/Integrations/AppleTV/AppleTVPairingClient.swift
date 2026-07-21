import Crypto
import Foundation
import Network
import SRP

actor AppleTVPairingClient: AppleTVPairing {
    private static let operationTimeout: Duration = .seconds(20)
    private static let pairingDataKey = "_pd"
    private static let pairingTypeKey = "_pwTy"

    private let logger: any AuraLogging
    private var pendingSession: PendingSession?

    init(logger: any AuraLogging) {
        self.logger = logger
    }

    func begin(endpoint: AppleTVBonjourEndpoint) async throws {
        guard endpoint.serviceType == .companion else {
            throw AppleTVPairingError.companionServiceUnavailable
        }
        guard pendingSession == nil else { throw AppleTVPairingError.invalidState }

        logger.log(.notice, event: "apple_tv_pairing_started")

        do {
            pendingSession = try await Self.withTimeout {
                try await Self.startSession(endpoint: endpoint)
            }
            logger.log(.notice, event: "apple_tv_pairing_pin_requested")
        } catch is CancellationError {
            logger.log(.notice, event: "apple_tv_pairing_cancelled")
            throw AppleTVPairingError.cancelled
        } catch let error as AppleTVPairingError {
            logger.log(.error, event: Self.startFailureEvent(for: error))
            throw error
        } catch {
            logger.log(.error, event: Self.unexpectedStartFailureEvent(for: error))
            throw AppleTVPairingError.connectionFailed
        }
    }

    func finish(pin: String) async throws -> AppleTVPairingCredentials {
        guard pin.count >= 4, pin.count <= 8, pin.allSatisfy(\.isNumber) else {
            throw AppleTVPairingError.invalidPIN
        }
        guard let session = pendingSession else { throw AppleTVPairingError.invalidState }
        pendingSession = nil

        do {
            let credentials = try await Self.withTimeout {
                try await Self.finishSession(session, pin: pin)
            }
            session.connection.cancel()
            logger.log(.notice, event: "apple_tv_pairing_completed")
            return credentials
        } catch is CancellationError {
            session.connection.cancel()
            logger.log(.notice, event: "apple_tv_pairing_cancelled")
            throw AppleTVPairingError.cancelled
        } catch let error as AppleTVPairingError {
            session.connection.cancel()
            logger.log(.error, event: "apple_tv_pairing_authentication_failed")
            throw error
        } catch {
            session.connection.cancel()
            logger.log(.error, event: "apple_tv_pairing_authentication_failed")
            throw AppleTVPairingError.authenticationFailed
        }
    }

    func cancel() {
        pendingSession?.connection.cancel()
        pendingSession = nil
        logger.log(.notice, event: "apple_tv_pairing_cancelled")
    }

    private nonisolated static func startSession(
        endpoint: AppleTVBonjourEndpoint
    ) async throws -> PendingSession {
        let parameters = NWParameters.tcp
        if let tcpOptions = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcpOptions.connectionTimeout = 10
        }

        let networkEndpoint = NWEndpoint.service(
            name: endpoint.serviceName,
            type: endpoint.serviceType.rawValue,
            domain: endpoint.domain,
            interface: nil
        )
        let connection = NWConnection(to: networkEndpoint, using: parameters)

        do {
            try await connect(connection)
            let setupData = try HAPTLV8.encode([
                HAPTLVEntry(tag: .method, value: Data([0x00])),
                HAPTLVEntry(tag: .sequence, value: Data([0x01]))
            ])
            let response = try await exchange(
                connection: connection,
                type: .pairSetupStart,
                dictionary: [
                    pairingDataKey: .data(setupData),
                    pairingTypeKey: .integer(1)
                ]
            )
            let fields = try pairingFields(from: response, expectedSequence: 0x02)
            guard let salt = fields[.salt], !salt.isEmpty,
                  let publicKey = fields[.publicKey], !publicKey.isEmpty else {
                throw AppleTVPairingError.protocolViolation
            }

            return PendingSession(
                endpoint: endpoint,
                connection: connection,
                salt: salt,
                serverPublicKey: publicKey
            )
        } catch {
            connection.cancel()
            throw error
        }
    }

    private nonisolated static func finishSession(
        _ session: PendingSession,
        pin: String
    ) async throws -> AppleTVPairingCredentials {
        let configuration = SRPConfiguration<SHA512>(.N3072)
        let client = SRPClient(configuration: configuration)
        let clientKeys = client.generateKeys()
        let serverKey = SRPKey(session.serverPublicKey, padding: configuration.sizeN)
        let sharedSecret: SRPKey

        do {
            sharedSecret = try client.calculateSharedSecret(
                username: "Pair-Setup",
                password: pin,
                salt: Array(session.salt),
                clientKeys: clientKeys,
                serverPublicKey: serverKey
            )
        } catch {
            throw AppleTVPairingError.authenticationFailed
        }

        let sessionKeyMaterial = AppleTVHAPSRP.sessionKey(sharedSecret: sharedSecret)
        let clientProof = AppleTVHAPSRP.clientProof(
            configuration: configuration,
            username: "Pair-Setup",
            salt: Array(session.salt),
            clientPublicKey: clientKeys.public,
            serverPublicKey: serverKey,
            sessionKey: sessionKeyMaterial
        )
        let proofResponse = try await exchange(
            connection: session.connection,
            type: .pairSetupNext,
            dictionary: [
                pairingDataKey: .data(try HAPTLV8.encode([
                    HAPTLVEntry(tag: .sequence, value: Data([0x03])),
                    HAPTLVEntry(tag: .publicKey, value: Data(clientKeys.public.bytes)),
                    HAPTLVEntry(tag: .proof, value: Data(clientProof))
                ])),
                pairingTypeKey: .integer(1)
            ]
        )
        let proofFields = try pairingFields(from: proofResponse, expectedSequence: 0x04)
        guard let serverProof = proofFields[.proof] else {
            throw AppleTVPairingError.protocolViolation
        }

        guard AppleTVHAPSRP.verifyServerProof(
            Array(serverProof),
            clientProof: clientProof,
            clientPublicKey: clientKeys.public,
            sessionKey: sessionKeyMaterial
        ) else {
            throw AppleTVPairingError.authenticationFailed
        }

        let encryptionKey = deriveKey(
            input: sessionKeyMaterial,
            salt: "Pair-Setup-Encrypt-Salt",
            info: "Pair-Setup-Encrypt-Info"
        )
        let controllerSignKey = deriveKey(
            input: sessionKeyMaterial,
            salt: "Pair-Setup-Controller-Sign-Salt",
            info: "Pair-Setup-Controller-Sign-Info"
        )

        let signingKey = Curve25519.Signing.PrivateKey()
        let controllerIdentifier = Data(UUID().uuidString.utf8)
        let controllerPublicKey = signingKey.publicKey.rawRepresentation
        let controllerInfo = controllerSignKey + controllerIdentifier + controllerPublicKey
        let controllerSignature = try signingKey.signature(for: controllerInfo)
        let subTLV = try HAPTLV8.encode([
            HAPTLVEntry(tag: .identifier, value: controllerIdentifier),
            HAPTLVEntry(tag: .publicKey, value: controllerPublicKey),
            HAPTLVEntry(tag: .signature, value: controllerSignature)
        ])
        let encryptedControllerData = try seal(
            subTLV,
            key: encryptionKey,
            nonceLabel: "PS-Msg05"
        )

        let credentialsResponse = try await exchange(
            connection: session.connection,
            type: .pairSetupNext,
            dictionary: [
                pairingDataKey: .data(try HAPTLV8.encode([
                    HAPTLVEntry(tag: .sequence, value: Data([0x05])),
                    HAPTLVEntry(tag: .encryptedData, value: encryptedControllerData)
                ])),
                pairingTypeKey: .integer(1)
            ]
        )
        let credentialFields = try pairingFields(
            from: credentialsResponse,
            expectedSequence: 0x06
        )
        guard let encryptedAccessoryData = credentialFields[.encryptedData] else {
            throw AppleTVPairingError.protocolViolation
        }

        let accessoryTLV = try open(
            encryptedAccessoryData,
            key: encryptionKey,
            nonceLabel: "PS-Msg06"
        )
        let accessoryFields = try HAPTLV8.decode(accessoryTLV)
        guard let accessoryIdentifier = accessoryFields[.identifier],
              let accessoryPublicKey = accessoryFields[.publicKey],
              let accessorySignature = accessoryFields[.signature] else {
            throw AppleTVPairingError.protocolViolation
        }

        let accessorySignKey = deriveKey(
            input: sessionKeyMaterial,
            salt: "Pair-Setup-Accessory-Sign-Salt",
            info: "Pair-Setup-Accessory-Sign-Info"
        )
        let accessoryInfo = accessorySignKey + accessoryIdentifier + accessoryPublicKey
        let verifier = try Curve25519.Signing.PublicKey(rawRepresentation: accessoryPublicKey)
        guard verifier.isValidSignature(accessorySignature, for: accessoryInfo) else {
            throw AppleTVPairingError.authenticationFailed
        }

        return AppleTVPairingCredentials(
            accessoryPublicKey: accessoryPublicKey,
            controllerPrivateKey: signingKey.rawRepresentation,
            accessoryIdentifier: accessoryIdentifier,
            controllerIdentifier: controllerIdentifier
        )
    }

    private nonisolated static func pairingFields(
        from value: OPACKValue,
        expectedSequence: UInt8
    ) throws -> [HAPTLVTag: Data] {
        guard case .dictionary(let dictionary) = value,
              case .data(let pairingData) = dictionary[pairingDataKey] else {
            throw AppleTVPairingError.protocolViolation
        }

        let fields = try HAPTLV8.decode(pairingData)
        if fields[.error] != nil {
            throw AppleTVPairingError.authenticationFailed
        }
        guard fields[.sequence] == Data([expectedSequence]) else {
            throw AppleTVPairingError.protocolViolation
        }
        return fields
    }

    private nonisolated static func startFailureEvent(
        for error: AppleTVPairingError
    ) -> String {
        switch error {
        case .invalidState: "apple_tv_pairing_start_failed_invalid_state"
        case .companionServiceUnavailable: "apple_tv_pairing_start_failed_service_unavailable"
        case .invalidPIN: "apple_tv_pairing_start_failed_invalid_pin"
        case .connectionFailed: "apple_tv_pairing_start_failed_connection"
        case .timedOut: "apple_tv_pairing_start_failed_timeout"
        case .protocolViolation: "apple_tv_pairing_start_failed_protocol"
        case .authenticationFailed: "apple_tv_pairing_start_failed_authentication"
        case .cancelled: "apple_tv_pairing_start_failed_cancelled"
        }
    }

    private nonisolated static func unexpectedStartFailureEvent(for error: Error) -> String {
        switch error {
        case is OPACKCodecError: "apple_tv_pairing_start_failed_opack"
        case is HAPTLV8Error: "apple_tv_pairing_start_failed_tlv"
        case is CompanionFrameCodecError: "apple_tv_pairing_start_failed_frame"
        case is NWError: "apple_tv_pairing_start_failed_network"
        default: "apple_tv_pairing_start_failed_unexpected"
        }
    }

    private nonisolated static func exchange(
        connection: NWConnection,
        type: CompanionFrameType,
        dictionary: [String: OPACKValue]
    ) async throws -> OPACKValue {
        try await withTaskCancellationHandler {
            let payload = try OPACKCodec.encode(.dictionary(dictionary))
            let frame = try CompanionFrameCodec.encode(CompanionFrame(type: type, payload: payload))
            try await send(frame, on: connection)

            let header = try await receiveExactly(CompanionFrame.headerLength, from: connection)
            let payloadLength = try CompanionFrameCodec.payloadLength(from: header)
            let responsePayload = try await receiveExactly(payloadLength, from: connection)
            let response = try CompanionFrameCodec.decode(header: header, payload: responsePayload)
            guard response.type == .pairSetupNext else {
                throw AppleTVPairingError.protocolViolation
            }
            return try OPACKCodec.decode(response.payload)
        } onCancel: {
            connection.cancel()
        }
    }

    private nonisolated static func connect(_ connection: NWConnection) async throws {
        let gate = NetworkContinuationGate()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        gate.resolve(.success(()))
                    case .failed:
                        gate.resolve(.failure(AppleTVPairingError.connectionFailed))
                    case .cancelled:
                        gate.resolve(.failure(AppleTVPairingError.cancelled))
                    case .setup, .waiting, .preparing:
                        break
                    @unknown default:
                        gate.resolve(.failure(AppleTVPairingError.connectionFailed))
                    }
                }
                connection.start(queue: DispatchQueue(label: "com.danielhagen.aura.apple-tv.pairing"))
            }
        } onCancel: {
            connection.cancel()
            gate.resolve(.failure(CancellationError()))
        }
    }

    private nonisolated static func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if error == nil {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AppleTVPairingError.connectionFailed)
                }
            })
        }
    }

    private nonisolated static func receiveExactly(
        _ byteCount: Int,
        from connection: NWConnection
    ) async throws -> Data {
        guard byteCount >= 0, byteCount <= CompanionFrame.maximumPayloadLength else {
            throw AppleTVPairingError.protocolViolation
        }
        if byteCount == 0 { return Data() }

        var result = Data()
        while result.count < byteCount {
            let remaining = byteCount - result.count
            let chunk = try await withCheckedThrowingContinuation { continuation in
                connection.receive(
                    minimumIncompleteLength: 1,
                    maximumLength: remaining
                ) { data, _, isComplete, error in
                    if let data, !data.isEmpty {
                        continuation.resume(returning: data)
                    } else if error != nil || isComplete {
                        continuation.resume(throwing: AppleTVPairingError.connectionFailed)
                    } else {
                        continuation.resume(throwing: AppleTVPairingError.protocolViolation)
                    }
                }
            }
            result.append(chunk)
        }
        return result
    }

    private nonisolated static func deriveKey(
        input: Data,
        salt: String,
        info: String
    ) -> Data {
        let key = HKDF<SHA512>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: input),
            salt: Data(salt.utf8),
            info: Data(info.utf8),
            outputByteCount: 32
        )
        return key.withUnsafeBytes { Data($0) }
    }

    private nonisolated static func seal(
        _ plaintext: Data,
        key: Data,
        nonceLabel: String
    ) throws -> Data {
        let nonce = try pairingNonce(label: nonceLabel)
        let box = try ChaChaPoly.seal(
            plaintext,
            using: SymmetricKey(data: key),
            nonce: nonce
        )
        return box.ciphertext + box.tag
    }

    private nonisolated static func open(
        _ sealedData: Data,
        key: Data,
        nonceLabel: String
    ) throws -> Data {
        guard sealedData.count >= 16 else { throw AppleTVPairingError.protocolViolation }
        let nonce = try pairingNonce(label: nonceLabel)
        let ciphertext = sealedData.dropLast(16)
        let tag = sealedData.suffix(16)
        let box = try ChaChaPoly.SealedBox(
            nonce: nonce,
            ciphertext: ciphertext,
            tag: tag
        )
        return try ChaChaPoly.open(box, using: SymmetricKey(data: key))
    }

    private nonisolated static func pairingNonce(label: String) throws -> ChaChaPoly.Nonce {
        let labelData = Data(label.utf8)
        guard labelData.count == 8 else { throw AppleTVPairingError.protocolViolation }
        return try ChaChaPoly.Nonce(data: Data(repeating: 0, count: 4) + labelData)
    }

    private nonisolated static func withTimeout<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: operationTimeout)
                throw AppleTVPairingError.timedOut
            }

            guard let result = try await group.next() else {
                throw AppleTVPairingError.connectionFailed
            }
            group.cancelAll()
            return result
        }
    }
}

/// HAP uses the original SRP proof encoding, where integer values are encoded
/// without leading zero padding. RFC 5054 still requires padding for `u` and
/// `k`, which `swift-srp` handles while calculating the shared secret.
enum AppleTVHAPSRP {
    static func sessionKey(sharedSecret: SRPKey) -> Data {
        Data(SHA512.hash(data: sharedSecret.unpaddedBytes))
    }

    static func clientProof(
        configuration: SRPConfiguration<SHA512>,
        username: String,
        salt: [UInt8],
        clientPublicKey: SRPKey,
        serverPublicKey: SRPKey,
        sessionKey: Data
    ) -> [UInt8] {
        let primeHash = [UInt8](SHA512.hash(data: configuration.N.bytes))
        let generatorHash = [UInt8](SHA512.hash(data: configuration.g.bytes))
        let groupHash = zip(primeHash, generatorHash).map { pair in
            pair.0 ^ pair.1
        }
        let usernameHash = [UInt8](SHA512.hash(data: Data(username.utf8)))
        let proofInput = groupHash
            + usernameHash
            + canonicalUnsignedBytes(salt)
            + clientPublicKey.unpaddedBytes
            + serverPublicKey.unpaddedBytes
            + Array(sessionKey)
        return [UInt8](SHA512.hash(data: proofInput))
    }

    static func verifyServerProof(
        _ serverProof: [UInt8],
        clientProof: [UInt8],
        clientPublicKey: SRPKey,
        sessionKey: Data
    ) -> Bool {
        let expected = [UInt8](SHA512.hash(
            data: clientPublicKey.unpaddedBytes + clientProof + Array(sessionKey)
        ))
        guard serverProof.count == expected.count else { return false }

        var difference: UInt8 = 0
        for index in serverProof.indices {
            difference |= serverProof[index] ^ expected[index]
        }
        return difference == 0
    }

    private static func canonicalUnsignedBytes(_ bytes: [UInt8]) -> [UInt8] {
        let firstNonzero = bytes.firstIndex(where: { $0 != 0 })
        return firstNonzero.map { Array(bytes[$0...]) } ?? [0]
    }
}

private final class PendingSession: @unchecked Sendable {
    let endpoint: AppleTVBonjourEndpoint
    let connection: NWConnection
    let salt: Data
    let serverPublicKey: Data

    init(
        endpoint: AppleTVBonjourEndpoint,
        connection: NWConnection,
        salt: Data,
        serverPublicKey: Data
    ) {
        self.endpoint = endpoint
        self.connection = connection
        self.salt = salt
        self.serverPublicKey = serverPublicKey
    }
}

private final class NetworkContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var result: Result<Void, Error>?

    func install(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        defer { lock.unlock() }

        if let result {
            continuation.resume(with: result)
        } else {
            self.continuation = continuation
        }
    }

    func resolve(_ result: Result<Void, Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
