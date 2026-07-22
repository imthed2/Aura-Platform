import XCTest
@testable import Aura

final class PhilipsTVDiscoveryTests: XCTestCase {
    func testSearchRequestIsBoundedToDIAL() throws {
        let request = try XCTUnwrap(
            String(data: PhilipsTVDiscoveryConstants.searchRequest(), encoding: .utf8)
        )

        XCTAssertTrue(request.contains("MX: 2"))
        XCTAssertTrue(request.contains("ST: urn:dial-multiscreen-org:service:dial:1"))
        XCTAssertFalse(request.localizedCaseInsensitiveContains("ssdp:all"))
        XCTAssertFalse(request.contains("MediaRenderer"))
    }

    func testResponseParserAcceptsPrivateDIALDescriptionURL() throws {
        let response = response(
            location: "http://192.168.1.50:6466/ssdp/device-desc.xml"
        )

        let observation = try XCTUnwrap(
            PhilipsTVSSDPResponseParser.observation(from: Data(response.utf8))
        )

        XCTAssertEqual(
            observation.descriptionURL,
            URL(string: "http://192.168.1.50:6466/ssdp/device-desc.xml")
        )
    }

    func testResponseParserRejectsPublicCredentialedAndWrongServiceURLs() {
        let publicResponse = response(location: "http://203.0.113.10/device.xml")
        let credentialedResponse = response(
            location: "http://user:password@192.168.1.50/device.xml"
        )
        let wrongServiceResponse = response(
            location: "http://192.168.1.50/device.xml",
            searchTarget: "ssdp:all"
        )

        XCTAssertNil(
            PhilipsTVSSDPResponseParser.observation(from: Data(publicResponse.utf8))
        )
        XCTAssertNil(
            PhilipsTVSSDPResponseParser.observation(from: Data(credentialedResponse.utf8))
        )
        XCTAssertNil(
            PhilipsTVSSDPResponseParser.observation(from: Data(wrongServiceResponse.utf8))
        )
    }

    func testResponseParserRejectsOversizedAndAmbiguousResponses() {
        let oversized = Data(
            repeating: 0x41,
            count: PhilipsTVDiscoveryConstants.maximumDatagramBytes + 1
        )
        let ambiguous = response(
            location: "http://192.168.1.50/device.xml",
            extraHeaders: "LOCATION: http://192.168.1.51/device.xml\r\n"
        )

        XCTAssertNil(PhilipsTVSSDPResponseParser.observation(from: oversized))
        XCTAssertNil(
            PhilipsTVSSDPResponseParser.observation(from: Data(ambiguous.utf8))
        )
    }

    func testCandidateVerifierAcceptsOnlyTargetPhilipsFamily() throws {
        let observation = PhilipsTVSSDPObservation(
            descriptionURL: try XCTUnwrap(
                URL(string: "http://192.168.1.50/device.xml")
            )
        )
        let targetDescription = description(
            manufacturer: "Philips",
            modelNumber: "PUS7800"
        )
        let otherPhilipsDescription = description(
            manufacturer: "Philips",
            modelNumber: "PUS9999"
        )
        let otherManufacturerDescription = description(
            manufacturer: "Example Vendor",
            modelNumber: "PUS7800"
        )

        let candidate = try XCTUnwrap(
            PhilipsTVCandidateVerifier.candidate(
                observation: observation,
                descriptionData: Data(targetDescription.utf8)
            )
        )

        XCTAssertEqual(candidate.advertisedModel, "PUS7800")
        XCTAssertNil(
            PhilipsTVCandidateVerifier.candidate(
                observation: observation,
                descriptionData: Data(otherPhilipsDescription.utf8)
            )
        )
        XCTAssertNil(
            PhilipsTVCandidateVerifier.candidate(
                observation: observation,
                descriptionData: Data(otherManufacturerDescription.utf8)
            )
        )
    }

    func testDescriptionParserRejectsDoctypeAndOversizedPayloads() {
        let doctype = """
        <?xml version="1.0"?>
        <!DOCTYPE root [<!ENTITY example "value">]>
        <root><manufacturer>Philips</manufacturer><modelNumber>PUS7800</modelNumber></root>
        """
        let oversized = Data(
            repeating: 0x20,
            count: PhilipsTVDiscoveryConstants.maximumDescriptionBytes + 1
        )

        XCTAssertNil(PhilipsTVDeviceDescriptionParser.parse(Data(doctype.utf8)))
        XCTAssertNil(PhilipsTVDeviceDescriptionParser.parse(oversized))
    }

    func testCompatibilityProfileReadsOnlyAPIVersion() throws {
        let response = Data(
            """
            {
              "api_version": {"Major": 6, "Minor": 1, "Patch": 0},
              "deviceid_encrypted": "not-a-real-device-id",
              "serialnumber_encrypted": "not-a-real-serial"
            }
            """.utf8
        )

        XCTAssertEqual(
            PhilipsTVCompatibilityProfile.apiVersion(fromSystemResponse: response),
            PhilipsTVAPIVersion(major: 6, minor: 1, patch: 0)
        )
    }

    func testDiscoveryDeduplicatesObservations() async throws {
        let datagram = Data(
            response(location: "http://192.168.1.50/device.xml").utf8
        )
        let client = PhilipsTVDiscoveryClient(
            transport: StubPhilipsTVSSDPTransport(responses: [datagram, datagram]),
            logger: NoOpAuraLogger()
        )

        let observations = try await client.discover(timeout: .seconds(1))

        XCTAssertEqual(observations.count, 1)
    }

    func testDiscoveryTranslatesCancellation() async {
        let client = PhilipsTVDiscoveryClient(
            transport: StubPhilipsTVSSDPTransport(error: CancellationError()),
            logger: NoOpAuraLogger()
        )

        do {
            _ = try await client.discover(timeout: .seconds(1))
            XCTFail("Expected discovery cancellation")
        } catch let error as PhilipsTVDiscoveryError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("Unexpected error: \(type(of: error))")
        }
    }

    private func response(
        location: String,
        searchTarget: String = PhilipsTVDiscoveryConstants.dialSearchTarget,
        extraHeaders: String = ""
    ) -> String {
        """
        HTTP/1.1 200 OK\r
        ST: \(searchTarget)\r
        LOCATION: \(location)\r
        \(extraHeaders)\r

        """
    }

    private func description(
        manufacturer: String,
        modelNumber: String
    ) -> String {
        """
        <?xml version="1.0"?>
        <root>
          <device>
            <manufacturer>\(manufacturer)</manufacturer>
            <modelName>Philips TV</modelName>
            <modelNumber>\(modelNumber)</modelNumber>
          </device>
        </root>
        """
    }
}

private struct StubPhilipsTVSSDPTransport: PhilipsTVSSDPTransport {
    let responses: [Data]
    let error: (any Error & Sendable)?

    init(
        responses: [Data] = [],
        error: (any Error & Sendable)? = nil
    ) {
        self.responses = responses
        self.error = error
    }

    func search(
        request: Data,
        timeout: Duration,
        maximumResponses: Int,
        maximumDatagramBytes: Int
    ) async throws -> [Data] {
        if let error { throw error }
        return Array(responses.prefix(maximumResponses))
    }
}
