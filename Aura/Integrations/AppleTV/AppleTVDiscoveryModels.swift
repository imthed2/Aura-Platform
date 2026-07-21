import Foundation

enum AppleTVBonjourService: String, CaseIterable, Sendable {
    case companion = "_companion-link._tcp"
    case mediaRemote = "_mediaremotetv._tcp"
}

struct AppleTVBonjourEndpoint: Hashable, Sendable {
    let serviceName: String
    let serviceType: AppleTVBonjourService
    let domain: String
}

struct AppleTVDiscoveryObservation: Hashable, Sendable {
    let endpoint: AppleTVBonjourEndpoint
}

struct AppleTVDiscoveryCandidate: Hashable, Sendable {
    let displayName: String
    let endpoints: Set<AppleTVBonjourEndpoint>
}

enum AppleTVDiscoveryCandidateMapper {
    static func candidates(
        from observations: some Sequence<AppleTVDiscoveryObservation>
    ) -> [AppleTVDiscoveryCandidate] {
        let grouped = Dictionary(grouping: observations) { observation in
            normalized(observation.endpoint.serviceName)
        }

        return grouped.values
            .compactMap { group in
                guard let first = group.first else { return nil }
                return AppleTVDiscoveryCandidate(
                    displayName: first.endpoint.serviceName,
                    endpoints: Set(group.map(\.endpoint))
                )
            }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum AppleTVDiscoveryError: Error, Equatable, Sendable {
    case browserFailed
    case cancelled
}

protocol AppleTVDiscovering: Sendable {
    func discover(timeout: Duration) async throws -> [AppleTVDiscoveryCandidate]
}
