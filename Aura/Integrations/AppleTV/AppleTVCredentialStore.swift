import Crypto
import Foundation
import Security

enum AppleTVCredentialStoreError: Error, Equatable, Sendable {
    case encodingFailed
    case keychainFailure(OSStatus)
}

protocol AppleTVCredentialStoring: Sendable {
    func save(_ credentials: AppleTVPairingCredentials) async throws
    func remove(_ credentials: AppleTVPairingCredentials) async throws
}

actor AppleTVKeychainCredentialStore: AppleTVCredentialStoring {
    private let service = "com.danielhagen.aura.apple-tv.pairing"

    func save(_ credentials: AppleTVPairingCredentials) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(credentials)
        } catch {
            throw AppleTVCredentialStoreError.encodingFailed
        }

        let account = accountIdentifier(for: credentials.accessoryIdentifier)
        let lookup = baseQuery(account: account)
        let update: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(lookup as CFDictionary, update as CFDictionary)

        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw AppleTVCredentialStoreError.keychainFailure(updateStatus)
        }

        var addition = lookup
        addition[kSecValueData] = data
        addition[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addition as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AppleTVCredentialStoreError.keychainFailure(addStatus)
        }
    }

    func remove(_ credentials: AppleTVPairingCredentials) throws {
        let account = accountIdentifier(for: credentials.accessoryIdentifier)
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppleTVCredentialStoreError.keychainFailure(status)
        }
    }

    private func baseQuery(account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false
        ]
    }

    private func accountIdentifier(for accessoryIdentifier: Data) -> String {
        SHA256.hash(data: accessoryIdentifier)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
