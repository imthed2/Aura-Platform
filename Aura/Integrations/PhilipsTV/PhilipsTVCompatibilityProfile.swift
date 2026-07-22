import Foundation

struct PhilipsTVAPIVersion: Equatable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
}

enum PhilipsTVCompatibilityProfile {
    static let targetProduct = "65PUS7800/12"
    static let targetAdvertisedFamily = "PUS7800"
    static let verifiedAPIVersion = PhilipsTVAPIVersion(major: 6, minor: 1, patch: 0)

    static func matchesTargetFamily(_ advertisedModel: String) -> Bool {
        normalize(advertisedModel) == normalize(targetAdvertisedFamily)
    }

    static func apiVersion(fromSystemResponse data: Data) -> PhilipsTVAPIVersion? {
        guard data.count <= PhilipsTVDiscoveryConstants.maximumDescriptionBytes,
              let response = try? JSONDecoder().decode(SystemResponse.self, from: data) else {
            return nil
        }

        return PhilipsTVAPIVersion(
            major: response.apiVersion.major,
            minor: response.apiVersion.minor,
            patch: response.apiVersion.patch
        )
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
}

private struct SystemResponse: Decodable {
    let apiVersion: APIVersion

    enum CodingKeys: String, CodingKey {
        case apiVersion = "api_version"
    }
}

private struct APIVersion: Decodable {
    let major: Int
    let minor: Int
    let patch: Int

    enum CodingKeys: String, CodingKey {
        case major = "Major"
        case minor = "Minor"
        case patch = "Patch"
    }
}
