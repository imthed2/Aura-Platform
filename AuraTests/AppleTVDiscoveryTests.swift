import XCTest
@testable import Aura

final class AppleTVDiscoveryTests: XCTestCase {
    func testServiceTypesAreBoundedToRequiredAppleTVProtocols() {
        XCTAssertEqual(
            Set(AppleTVBonjourService.allCases.map(\.rawValue)),
            ["_companion-link._tcp", "_mediaremotetv._tcp"]
        )
    }

    func testCandidateMapperMergesProtocolEndpointsForSameServiceName() throws {
        let companion = AppleTVDiscoveryObservation(
            endpoint: AppleTVBonjourEndpoint(
                serviceName: "Living Room",
                serviceType: .companion,
                domain: "local."
            )
        )
        let mediaRemote = AppleTVDiscoveryObservation(
            endpoint: AppleTVBonjourEndpoint(
                serviceName: " living room ",
                serviceType: .mediaRemote,
                domain: "local."
            )
        )

        let candidates = AppleTVDiscoveryCandidateMapper.candidates(
            from: [companion, mediaRemote]
        )

        let candidate = try XCTUnwrap(candidates.first)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidate.displayName, "Living Room")
        XCTAssertEqual(candidate.endpoints.count, 2)
    }

    func testCandidateMapperKeepsDistinctDevicesAndSortsNames() {
        let observations = [
            observation(name: "Office", service: .companion),
            observation(name: "Bedroom", service: .companion)
        ]

        let candidates = AppleTVDiscoveryCandidateMapper.candidates(from: observations)

        XCTAssertEqual(candidates.map(\.displayName), ["Bedroom", "Office"])
    }

    private func observation(
        name: String,
        service: AppleTVBonjourService
    ) -> AppleTVDiscoveryObservation {
        AppleTVDiscoveryObservation(
            endpoint: AppleTVBonjourEndpoint(
                serviceName: name,
                serviceType: service,
                domain: "local."
            )
        )
    }
}
