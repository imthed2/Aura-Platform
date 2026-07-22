import Foundation
import Darwin

actor PhilipsTVDiscoveryClient: PhilipsTVDiscovering {
    private let transport: any PhilipsTVSSDPTransport
    private let logger: any AuraLogging

    init(
        transport: any PhilipsTVSSDPTransport = SystemPhilipsTVSSDPTransport(),
        logger: any AuraLogging
    ) {
        self.transport = transport
        self.logger = logger
    }

    func discover(timeout: Duration = .seconds(5)) async throws -> [PhilipsTVSSDPObservation] {
        logger.log(.notice, event: "philips_tv_discovery_started")

        do {
            let datagrams = try await transport.search(
                request: PhilipsTVDiscoveryConstants.searchRequest(),
                timeout: timeout,
                maximumResponses: PhilipsTVDiscoveryConstants.maximumResponseCount,
                maximumDatagramBytes: PhilipsTVDiscoveryConstants.maximumDatagramBytes
            )
            let observations = Set(datagrams.compactMap(PhilipsTVSSDPResponseParser.observation))
                .sorted { $0.descriptionURL.absoluteString < $1.descriptionURL.absoluteString }
            logger.log(.notice, event: "philips_tv_discovery_completed")
            return observations
        } catch is CancellationError {
            logger.log(.notice, event: "philips_tv_discovery_cancelled")
            throw PhilipsTVDiscoveryError.cancelled
        } catch let error as PhilipsTVDiscoveryError {
            logger.log(.error, event: "philips_tv_discovery_failed")
            throw error
        } catch {
            logger.log(.error, event: "philips_tv_discovery_failed")
            throw PhilipsTVDiscoveryError.transportFailed
        }
    }
}

struct SystemPhilipsTVSSDPTransport: PhilipsTVSSDPTransport {
    func search(
        request: Data,
        timeout: Duration,
        maximumResponses: Int,
        maximumDatagramBytes: Int
    ) async throws -> [Data] {
        let accumulator = PhilipsTVSSDPAccumulator(limit: maximumResponses)

        return try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for try await response in Self.responses(
                    request: request,
                    maximumResponses: maximumResponses,
                    maximumDatagramBytes: maximumDatagramBytes
                ) {
                    try Task.checkCancellation()
                    let reachedLimit = await accumulator.append(response)
                    if reachedLimit { break }
                }
            }

            group.addTask {
                try await Task.sleep(for: timeout)
            }

            do {
                _ = try await group.next()
                group.cancelAll()
                return await accumulator.snapshot()
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    private static func responses(
        request: Data,
        maximumResponses: Int,
        maximumDatagramBytes: Int
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(maximumResponses)) { continuation in
            let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            guard descriptor >= 0 else {
                continuation.finish(throwing: PhilipsTVDiscoveryError.transportFailed)
                return
            }

            guard fcntl(descriptor, F_SETFL, O_NONBLOCK) >= 0 else {
                close(descriptor)
                continuation.finish(throwing: PhilipsTVDiscoveryError.transportFailed)
                return
            }

            var localAddress = sockaddr_in()
            localAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            localAddress.sin_family = sa_family_t(AF_INET)
            localAddress.sin_port = 0
            localAddress.sin_addr = in_addr(s_addr: INADDR_ANY)

            let wasBound = withUnsafePointer(to: &localAddress) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(
                        descriptor,
                        $0,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
            guard wasBound == 0 else {
                close(descriptor)
                continuation.finish(throwing: PhilipsTVDiscoveryError.transportFailed)
                return
            }

            let queue = DispatchQueue(label: "com.danielhagen.aura.philips-tv.discovery")
            let source = DispatchSource.makeReadSource(
                fileDescriptor: descriptor,
                queue: queue
            )

            source.setEventHandler {
                while true {
                    var buffer = [UInt8](repeating: 0, count: maximumDatagramBytes + 1)
                    let received = recv(descriptor, &buffer, buffer.count, 0)
                    if received > 0 {
                        continuation.yield(Data(buffer.prefix(received)))
                    } else if received == 0 || errno == EWOULDBLOCK || errno == EAGAIN {
                        break
                    } else {
                        continuation.finish(throwing: PhilipsTVDiscoveryError.transportFailed)
                        break
                    }
                }
            }
            source.setCancelHandler {
                close(descriptor)
            }
            continuation.onTermination = { _ in
                source.cancel()
            }
            source.resume()

            var multicastAddress = sockaddr_in()
            multicastAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            multicastAddress.sin_family = sa_family_t(AF_INET)
            multicastAddress.sin_port = PhilipsTVDiscoveryConstants.multicastPort.bigEndian
            let addressResult = PhilipsTVDiscoveryConstants.multicastHost.withCString {
                inet_pton(AF_INET, $0, &multicastAddress.sin_addr)
            }
            guard addressResult == 1 else {
                continuation.finish(throwing: PhilipsTVDiscoveryError.transportFailed)
                return
            }

            let sent = request.withUnsafeBytes { bytes in
                withUnsafePointer(to: &multicastAddress) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        sendto(
                            descriptor,
                            bytes.baseAddress,
                            bytes.count,
                            0,
                            $0,
                            socklen_t(MemoryLayout<sockaddr_in>.size)
                        )
                    }
                }
            }
            if sent != request.count {
                continuation.finish(throwing: PhilipsTVDiscoveryError.transportFailed)
            }
        }
    }
}

private actor PhilipsTVSSDPAccumulator {
    private let limit: Int
    private var responses: [Data] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func append(_ response: Data) -> Bool {
        guard responses.count < limit else { return true }
        responses.append(response)
        return responses.count == limit
    }

    func snapshot() -> [Data] {
        responses
    }
}
