import Crypto
import Foundation
import Security

enum AppleTVCredentialStoreError: Error, Equatable, Sendable {
    case encodingFailed
    case invalidCredential
    case keychainFailure(OSStatus)
}

protocol AppleTVCredentialStoring: Sendable {
    func save(_ credentials: AppleTVPairingCredentials) async throws
    func loadAll() async throws -> [AppleTVPairingCredentials]
    func remove(_ credentials: AppleTVPairingCredentials) async throws
}

actor AppleTVKeychainCredentialStore: AppleTVCredentialStoring {
    private let service = "com.danielhagen.aura.apple-tv.pairing"

    func save(_ credentials: AppleTVPairingCredentials) throws {
        guard credentials.isStructurallyValid else {
            throw AppleTVCredentialStoreError.invalidCredential
        }
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

    func loadAll() throws -> [AppleTVPairingCredentials] {
        var query = baseQuery()
        query[kSecMatchLimit] = kSecMatchLimitAll
        query[kSecReturnData] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else {
            throw AppleTVCredentialStoreError.keychainFailure(status)
        }

        let encodedItems: [Data]
        if let items = result as? [Data] {
            encodedItems = items
        } else if let item = result as? Data {
            encodedItems = [item]
        } else {
            throw AppleTVCredentialStoreError.encodingFailed
        }

        do {
            let credentials = try encodedItems.map { try JSONDecoder().decode(
                AppleTVPairingCredentials.self,
                from: $0
            ) }
            guard credentials.allSatisfy(\.isStructurallyValid) else {
                throw AppleTVCredentialStoreError.invalidCredential
            }
            return credentials
        } catch let error as AppleTVCredentialStoreError {
            throw error
        } catch {
            throw AppleTVCredentialStoreError.encodingFailed
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
        var query = baseQuery()
        query[kSecAttrAccount] = account
        return query
    }

    private func baseQuery() -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrSynchronizable: false
        ]
    }

    private func accountIdentifier(for accessoryIdentifier: Data) -> String {
        SHA256.hash(data: accessoryIdentifier)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
