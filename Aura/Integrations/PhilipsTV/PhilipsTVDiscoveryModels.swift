import Foundation
import Network

enum PhilipsTVDiscoveryConstants {
    static let dialSearchTarget = "urn:dial-multiscreen-org:service:dial:1"
    static let multicastHost = "239.255.255.250"
    static let multicastPort: UInt16 = 1900
    static let maximumDatagramBytes = 16_384
    static let maximumResponseCount = 32
    static let maximumDescriptionBytes = 262_144

    static func searchRequest(maximumWaitSeconds: Int = 2) -> Data {
        let boundedWait = min(max(maximumWaitSeconds, 1), 5)
        let request = [
            "M-SEARCH * HTTP/1.1",
            "HOST: \(multicastHost):\(multicastPort)",
            "MAN: \"ssdp:discover\"",
            "MX: \(boundedWait)",
            "ST: \(dialSearchTarget)"
        ].joined(separator: "\r\n") + "\r\n\r\n"
        return Data(request.utf8)
    }
}

struct PhilipsTVSSDPObservation: Hashable, Sendable {
    let descriptionURL: URL
}

struct PhilipsTVDeviceDescription: Equatable, Sendable {
    let manufacturer: String
    let modelName: String?
    let modelNumber: String?

    var advertisedModel: String? {
        let values = [modelNumber, modelName]
        return values.compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }.first
    }
}

struct PhilipsTVDiscoveryCandidate: Equatable, Sendable {
    let advertisedModel: String
    let descriptionURL: URL
}

enum PhilipsTVDiscoveryError: Error, Equatable, Sendable {
    case transportFailed
    case cancelled
}

protocol PhilipsTVDiscovering: Sendable {
    func discover(timeout: Duration) async throws -> [PhilipsTVSSDPObservation]
}

protocol PhilipsTVSSDPTransport: Sendable {
    func search(
        request: Data,
        timeout: Duration,
        maximumResponses: Int,
        maximumDatagramBytes: Int
    ) async throws -> [Data]
}

enum PhilipsTVSSDPResponseParser {
    static func observation(from data: Data) -> PhilipsTVSSDPObservation? {
        guard data.count <= PhilipsTVDiscoveryConstants.maximumDatagramBytes,
              let response = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = response.components(separatedBy: .newlines)
        guard let statusLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              statusLine == "HTTP/1.1 200 OK" || statusLine == "HTTP/1.0 200 OK" else {
            return nil
        }

        var headers: [String: [String]] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = line[..<separator]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !value.isEmpty else { continue }
            headers[name, default: []].append(value)
        }

        guard headers["st"]?.count == 1,
              headers["st"]?.first?.lowercased()
                == PhilipsTVDiscoveryConstants.dialSearchTarget.lowercased(),
              headers["location"]?.count == 1,
              let location = headers["location"]?.first,
              let url = URL(string: location),
              isSafeLocalDescriptionURL(url) else {
            return nil
        }

        return PhilipsTVSSDPObservation(descriptionURL: url)
    }

    private static func isSafeLocalDescriptionURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              let host = components.host,
              let address = IPv4Address(host) else {
            return false
        }

        let bytes = [UInt8](address.rawValue)
        guard bytes.count == 4 else { return false }

        return bytes[0] == 10
            || (bytes[0] == 172 && (16...31).contains(bytes[1]))
            || (bytes[0] == 192 && bytes[1] == 168)
            || (bytes[0] == 169 && bytes[1] == 254)
    }
}

enum PhilipsTVDeviceDescriptionParser {
    static func parse(_ data: Data) -> PhilipsTVDeviceDescription? {
        guard data.count <= PhilipsTVDiscoveryConstants.maximumDescriptionBytes,
              let text = String(data: data, encoding: .utf8),
              !text.localizedCaseInsensitiveContains("<!DOCTYPE") else {
            return nil
        }

        let delegate = DeviceDescriptionXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false

        guard parser.parse(),
              let manufacturer = delegate.value(for: "manufacturer")?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !manufacturer.isEmpty else {
            return nil
        }

        return PhilipsTVDeviceDescription(
            manufacturer: manufacturer,
            modelName: delegate.value(for: "modelname"),
            modelNumber: delegate.value(for: "modelnumber")
        )
    }
}

enum PhilipsTVCandidateVerifier {
    static func candidate(
        observation: PhilipsTVSSDPObservation,
        descriptionData: Data
    ) -> PhilipsTVDiscoveryCandidate? {
        guard let description = PhilipsTVDeviceDescriptionParser.parse(descriptionData),
              isPhilips(description.manufacturer),
              let model = description.advertisedModel,
              PhilipsTVCompatibilityProfile.matchesTargetFamily(model) else {
            return nil
        }

        return PhilipsTVDiscoveryCandidate(
            advertisedModel: model,
            descriptionURL: observation.descriptionURL
        )
    }

    private static func isPhilips(_ manufacturer: String) -> Bool {
        let normalized = manufacturer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized == "philips" || normalized == "tp vision"
    }
}

private final class DeviceDescriptionXMLDelegate: NSObject, XMLParserDelegate {
    private let supportedElements = Set(["manufacturer", "modelname", "modelnumber"])
    private var currentElement: String?
    private var currentText = ""
    private var values: [String: String] = [:]

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let normalized = elementName.lowercased()
        guard supportedElements.contains(normalized) else { return }
        currentElement = normalized
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard currentElement != nil else { return }
        currentText.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let normalized = elementName.lowercased()
        guard currentElement == normalized else { return }
        values[normalized] = currentText
        currentElement = nil
        currentText = ""
    }

    func value(for element: String) -> String? {
        values[element]
    }
}
