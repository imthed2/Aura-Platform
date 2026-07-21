import Crypto
import Foundation
import Network

actor AppleTVCompanionClient: AppleTVControlling {
    private static let operationTimeout: Duration = .seconds(8)
    private static let pairingDataKey = "_pd"
    private static let authenticationTypeKey = "_auTy"
    fileprivate static let maximumIgnoredFrames = 16

    private let logger: any AuraLogging
    private var session: EncryptedCompanionSession?
    private var connectionContext: AppleTVControlConnectionContext?

    init(logger: any AuraLogging) {
        self.logger = logger
    }

    func connect(
        endpoint: AppleTVBonjourEndpoint,
        credentials: AppleTVPairingCredentials
    ) async throws {
        guard endpoint.serviceType == .companion else {
            throw AppleTVControlError.protocolViolation
        }
        guard credentials.isStructurallyValid else {
            throw AppleTVControlError.invalidCredential
        }

        session?.connection.cancel()
        session = nil
        connectionContext = nil
        logger.log(.notice, event: "apple_tv_control_connect_started")

        do {
            session = try await Self.withTimeout {
                try await Self.makeVerifiedSession(
                    endpoint: endpoint,
                    credentials: credentials
                )
            }
            connectionContext = AppleTVControlConnectionContext(
                endpoint: endpoint,
                credentials: credentials
            )
            logger.log(.notice, event: "apple_tv_control_connect_completed")
        } catch is CancellationError {
            logger.log(.notice, event: "apple_tv_control_connect_cancelled")
            throw AppleTVControlError.cancelled
        } catch let error as AppleTVControlError {
            logger.log(.error, event: "apple_tv_control_connect_failed")
            throw error
        } catch {
            logger.log(.error, event: "apple_tv_control_connect_failed")
            throw AppleTVControlError.connectionFailed
        }
    }

    func send(_ command: AppleTVRemoteCommand) async throws -> AppleTVCommandOutcome {
        guard let connectionContext else { throw AppleTVControlError.invalidState }
        logger.log(.notice, event: "apple_tv_command_started")

        session?.connection.cancel()
        session = nil
        do {
            let freshSession = try await Self.withTimeout {
                try await Self.makeVerifiedSession(
                    endpoint: connectionContext.endpoint,
                    credentials: connectionContext.credentials
                )
            }
            session?.connection.cancel()
            session = freshSession
            try await Self.withTimeout {
                try await freshSession.exchangeCommand(
                    identifier: "_hidC",
                    content: [
                        "_hBtS": .integer(1),
                        "_hidC": .integer(command.rawValue)
                    ]
                )
                try await Task.sleep(for: .milliseconds(20))
                try await freshSession.exchangeCommand(
                    identifier: "_hidC",
                    content: [
                        "_hBtS": .integer(2),
                        "_hidC": .integer(command.rawValue)
                    ]
                )
            }
            logger.log(.notice, event: "apple_tv_command_confirmed")
            return .confirmed
        } catch is CancellationError {
            logger.log(.notice, event: "apple_tv_command_cancelled")
            throw AppleTVControlError.cancelled
        } catch let error as AppleTVControlError {
            logger.log(.error, event: "apple_tv_command_failed")
            throw error
        } catch {
            logger.log(.error, event: "apple_tv_command_failed")
            throw AppleTVControlError.connectionFailed
        }
    }

    func disconnect() {
        session?.connection.cancel()
        session = nil
        connectionContext = nil
        logger.log(.notice, event: "apple_tv_control_disconnected")
    }

    private nonisolated static func makeVerifiedSession(
        endpoint: AppleTVBonjourEndpoint,
        credentials: AppleTVPairingCredentials
    ) async throws -> EncryptedCompanionSession {
        let connection = NWConnection(
            to: .service(
                name: endpoint.serviceName,
                type: endpoint.serviceType.rawValue,
                domain: endpoint.domain,
                interface: nil
            ),
            using: .tcp
        )

        return try await withTaskCancellationHandler {
            do {
                try await connect(connection)
            let ephemeralPrivateKey = Curve25519.KeyAgreement.PrivateKey()
            let ephemeralPublicKey = ephemeralPrivateKey.publicKey.rawRepresentation
            let startResponse = try await exchangeUnencrypted(
                connection: connection,
                type: .pairVerifyStart,
                dictionary: [
                    pairingDataKey: .data(try HAPTLV8.encode([
                        HAPTLVEntry(tag: .sequence, value: Data([0x01])),
                        HAPTLVEntry(tag: .publicKey, value: ephemeralPublicKey)
                    ])),
                    authenticationTypeKey: .integer(4)
                ]
            )
            let startFields = try pairingFields(from: startResponse, expectedSequence: 0x02)
            guard let accessoryEphemeralData = startFields[.publicKey],
                  let encryptedAccessoryData = startFields[.encryptedData] else {
                throw AppleTVControlError.protocolViolation
            }

            let accessoryEphemeralKey = try Curve25519.KeyAgreement.PublicKey(
                rawRepresentation: accessoryEphemeralData
            )
            let sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(
                with: accessoryEphemeralKey
            )
            let verifyKey = deriveKey(
                input: sharedSecret,
                salt: "Pair-Verify-Encrypt-Salt",
                info: "Pair-Verify-Encrypt-Info"
            )
            let accessoryTLV = try open(
                encryptedAccessoryData,
                key: verifyKey,
                nonceLabel: "PV-Msg02"
            )
            let accessoryFields = try HAPTLV8.decode(accessoryTLV)
            guard accessoryFields[.identifier] == credentials.accessoryIdentifier,
                  let accessorySignature = accessoryFields[.signature] else {
                throw AppleTVControlError.authenticationFailed
            }

            let accessorySigningKey = try Curve25519.Signing.PublicKey(
                rawRepresentation: credentials.accessoryPublicKey
            )
            let accessoryInfo = accessoryEphemeralData
                + credentials.accessoryIdentifier
                + ephemeralPublicKey
            guard accessorySigningKey.isValidSignature(
                accessorySignature,
                for: accessoryInfo
            ) else {
                throw AppleTVControlError.authenticationFailed
            }

            let controllerSigningKey = try Curve25519.Signing.PrivateKey(
                rawRepresentation: credentials.controllerPrivateKey
            )
            let controllerInfo = ephemeralPublicKey
                + credentials.controllerIdentifier
                + accessoryEphemeralData
            let controllerSignature = try controllerSigningKey.signature(for: controllerInfo)
            let encryptedControllerData = try seal(
                try HAPTLV8.encode([
                    HAPTLVEntry(
                        tag: .identifier,
                        value: credentials.controllerIdentifier
                    ),
                    HAPTLVEntry(tag: .signature, value: controllerSignature)
                ]),
                key: verifyKey,
                nonceLabel: "PV-Msg03"
            )
            let finishResponse = try await exchangeUnencrypted(
                connection: connection,
                type: .pairVerifyNext,
                dictionary: [pairingDataKey: .data(try HAPTLV8.encode([
                    HAPTLVEntry(tag: .sequence, value: Data([0x03])),
                    HAPTLVEntry(tag: .encryptedData, value: encryptedControllerData)
                ]))]
            )
            _ = try pairingFields(from: finishResponse, expectedSequence: 0x04)

                return EncryptedCompanionSession(
                    connection: connection,
                    outputKey: deriveKey(
                        input: sharedSecret,
                        salt: "",
                        info: "ClientEncrypt-main"
                    ),
                    inputKey: deriveKey(
                        input: sharedSecret,
                        salt: "",
                        info: "ServerEncrypt-main"
                    )
                )
            } catch {
                connection.cancel()
                throw error
            }
        } onCancel: {
            connection.cancel()
        }
    }

    private nonisolated static func pairingFields(
        from value: OPACKValue,
        expectedSequence: UInt8
    ) throws -> [HAPTLVTag: Data] {
        guard case .dictionary(let dictionary) = value,
              case .data(let pairingData) = dictionary[pairingDataKey] else {
            throw AppleTVControlError.protocolViolation
        }
        let fields = try HAPTLV8.decode(pairingData)
        if fields[.error] != nil { throw AppleTVControlError.authenticationFailed }
        guard fields[.sequence] == Data([expectedSequence]) else {
            throw AppleTVControlError.protocolViolation
        }
        return fields
    }

    private nonisolated static func exchangeUnencrypted(
        connection: NWConnection,
        type: CompanionFrameType,
        dictionary: [String: OPACKValue]
    ) async throws -> OPACKValue {
        let payload = try OPACKCodec.encode(.dictionary(dictionary))
        let frame = try CompanionFrameCodec.encode(CompanionFrame(type: type, payload: payload))
        try await send(frame, on: connection)
        let response = try await receiveFrame(from: connection)
        guard response.type == .pairVerifyNext else {
            throw AppleTVControlError.protocolViolation
        }
        return try OPACKCodec.decode(response.payload)
    }

    fileprivate nonisolated static func receiveFrame(
        from connection: NWConnection
    ) async throws -> CompanionFrame {
        let header = try await receiveExactly(CompanionFrame.headerLength, from: connection)
        let length = try CompanionFrameCodec.payloadLength(from: header)
        let payload = try await receiveExactly(length, from: connection)
        return try CompanionFrameCodec.decode(header: header, payload: payload)
    }

    fileprivate nonisolated static func send(
        _ data: Data,
        on connection: NWConnection
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if error == nil {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AppleTVControlError.connectionFailed)
                }
            })
        }
    }

    private nonisolated static func connect(_ connection: NWConnection) async throws {
        let gate = AppleTVControlContinuationGate()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        gate.resolve(.success(()))
                    case .failed:
                        gate.resolve(.failure(AppleTVControlError.connectionFailed))
                    case .cancelled:
                        gate.resolve(.failure(AppleTVControlError.cancelled))
                    case .setup, .waiting, .preparing:
                        break
                    @unknown default:
                        gate.resolve(.failure(AppleTVControlError.connectionFailed))
                    }
                }
                connection.start(queue: DispatchQueue(
                    label: "com.danielhagen.aura.apple-tv.control"
                ))
            }
        } onCancel: {
            connection.cancel()
            gate.resolve(.failure(CancellationError()))
        }
    }

    fileprivate nonisolated static func receiveExactly(
        _ byteCount: Int,
        from connection: NWConnection
    ) async throws -> Data {
        guard byteCount >= 0, byteCount <= CompanionFrame.maximumPayloadLength else {
            throw AppleTVControlError.protocolViolation
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
                        continuation.resume(throwing: AppleTVControlError.connectionFailed)
                    } else {
                        continuation.resume(throwing: AppleTVControlError.protocolViolation)
                    }
                }
            }
            result.append(chunk)
        }
        return result
    }

    private nonisolated static func deriveKey(
        input: SharedSecret,
        salt: String,
        info: String
    ) -> Data {
        let key = input.hkdfDerivedSymmetricKey(
            using: SHA512.self,
            salt: Data(salt.utf8),
            sharedInfo: Data(info.utf8),
            outputByteCount: 32
        )
        return key.withUnsafeBytes { Data($0) }
    }

    private nonisolated static func seal(
        _ plaintext: Data,
        key: Data,
        nonceLabel: String
    ) throws -> Data {
        let box = try ChaChaPoly.seal(
            plaintext,
            using: SymmetricKey(data: key),
            nonce: try pairingNonce(label: nonceLabel)
        )
        return box.ciphertext + box.tag
    }

    private nonisolated static func open(
        _ sealedData: Data,
        key: Data,
        nonceLabel: String
    ) throws -> Data {
        guard sealedData.count >= 16 else { throw AppleTVControlError.protocolViolation }
        let box = try ChaChaPoly.SealedBox(
            nonce: pairingNonce(label: nonceLabel),
            ciphertext: sealedData.dropLast(16),
            tag: sealedData.suffix(16)
        )
        return try ChaChaPoly.open(box, using: SymmetricKey(data: key))
    }

    private nonisolated static func pairingNonce(label: String) throws -> ChaChaPoly.Nonce {
        let labelData = Data(label.utf8)
        guard labelData.count == 8 else { throw AppleTVControlError.protocolViolation }
        return try ChaChaPoly.Nonce(data: Data(repeating: 0, count: 4) + labelData)
    }

    private nonisolated static func withTimeout<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: operationTimeout)
                throw AppleTVControlError.timedOut
            }
            guard let result = try await group.next() else {
                throw AppleTVControlError.connectionFailed
            }
            group.cancelAll()
            return result
        }
    }
}

private struct AppleTVControlConnectionContext: Sendable {
    let endpoint: AppleTVBonjourEndpoint
    let credentials: AppleTVPairingCredentials
}

private final class EncryptedCompanionSession: @unchecked Sendable {
    let connection: NWConnection
    private let outputKey: Data
    private let inputKey: Data
    private var outputCounter: UInt64 = 0
    private var inputCounter: UInt64 = 0
    private var transactionIdentifier: UInt64 = 1

    init(connection: NWConnection, outputKey: Data, inputKey: Data) {
        self.connection = connection
        self.outputKey = outputKey
        self.inputKey = inputKey
    }

    func exchangeCommand(
        identifier: String,
        content: [String: OPACKValue]
    ) async throws {
        try await withTaskCancellationHandler {
            let xid = transactionIdentifier
            transactionIdentifier += 1
            let request = OPACKValue.dictionary([
                "_c": .dictionary(content),
                "_i": .string(identifier),
                "_t": .integer(2),
                "_x": .integer(xid)
            ])
            try await sendEncrypted(try OPACKCodec.encode(request))

            for _ in 0..<AppleTVCompanionClient.maximumIgnoredFrames {
                let response = try await receiveEncrypted()
                guard response.type == .encryptedOPACK else { continue }
                guard case .dictionary(let dictionary) = try OPACKCodec.decode(response.payload) else {
                    throw AppleTVControlError.protocolViolation
                }
                guard dictionary["_x"] == .integer(xid) else { continue }
                if dictionary["_em"] != nil { throw AppleTVControlError.commandRejected }
                guard dictionary["_t"] == .integer(3) else {
                    throw AppleTVControlError.protocolViolation
                }
                return
            }
            throw AppleTVControlError.protocolViolation
        } onCancel: {
            connection.cancel()
        }
    }

    private func sendEncrypted(_ plaintext: Data) async throws {
        guard plaintext.count <= CompanionFrame.maximumPayloadLength - 16 else {
            throw AppleTVControlError.protocolViolation
        }
        let encryptedLength = plaintext.count + 16
        let header = Data([
            CompanionFrameType.encryptedOPACK.rawValue,
            UInt8((encryptedLength >> 16) & 0xFF),
            UInt8((encryptedLength >> 8) & 0xFF),
            UInt8(encryptedLength & 0xFF)
        ])
        let box = try ChaChaPoly.seal(
            plaintext,
            using: SymmetricKey(data: outputKey),
            nonce: AppleTVSessionCrypto.nonce(counter: outputCounter),
            authenticating: header
        )
        outputCounter += 1
        try await AppleTVCompanionClient.send(
            header + box.ciphertext + box.tag,
            on: connection
        )
    }

    private func receiveEncrypted() async throws -> CompanionFrame {
        let header = try await AppleTVCompanionClient.receiveExactly(
            CompanionFrame.headerLength,
            from: connection
        )
        let encryptedLength = try CompanionFrameCodec.payloadLength(from: header)
        guard encryptedLength >= 16 else { throw AppleTVControlError.protocolViolation }
        let encrypted = try await AppleTVCompanionClient.receiveExactly(
            encryptedLength,
            from: connection
        )
        let typeByte = header[header.startIndex]
        guard let type = CompanionFrameType(rawValue: typeByte) else {
            throw AppleTVControlError.protocolViolation
        }
        let box = try ChaChaPoly.SealedBox(
            nonce: AppleTVSessionCrypto.nonce(counter: inputCounter),
            ciphertext: encrypted.dropLast(16),
            tag: encrypted.suffix(16)
        )
        let plaintext = try ChaChaPoly.open(
            box,
            using: SymmetricKey(data: inputKey),
            authenticating: header
        )
        inputCounter += 1
        return CompanionFrame(type: type, payload: plaintext)
    }

}

enum AppleTVSessionCrypto {
    static func nonceData(counter: UInt64) -> Data {
        var littleEndian = counter.littleEndian
        let counterBytes = withUnsafeBytes(of: &littleEndian) { Data($0) }
        return counterBytes + Data(repeating: 0, count: 4)
    }

    static func nonce(counter: UInt64) throws -> ChaChaPoly.Nonce {
        try ChaChaPoly.Nonce(data: nonceData(counter: counter))
    }
}

private final class AppleTVControlContinuationGate: @unchecked Sendable {
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
