import Foundation
import Network

actor AppleTVDiscoveryClient: AppleTVDiscovering {
    private let logger: any AuraLogging

    init(logger: any AuraLogging) {
        self.logger = logger
    }

    func discover(timeout: Duration = .seconds(5)) async throws -> [AppleTVDiscoveryCandidate] {
        logger.log(.notice, event: "apple_tv_discovery_started")

        do {
            let observations = try await withThrowingTaskGroup(
                of: [AppleTVDiscoveryObservation].self,
                returning: [AppleTVDiscoveryObservation].self
            ) { group in
                for service in AppleTVBonjourService.allCases {
                    group.addTask {
                        try await self.browse(service: service, timeout: timeout)
                    }
                }

                var combined: [AppleTVDiscoveryObservation] = []
                for try await serviceObservations in group {
                    combined.append(contentsOf: serviceObservations)
                }
                return combined
            }

            let candidates = AppleTVDiscoveryCandidateMapper.candidates(from: observations)
            logger.log(.notice, event: "apple_tv_discovery_completed")
            return candidates
        } catch is CancellationError {
            logger.log(.notice, event: "apple_tv_discovery_cancelled")
            throw AppleTVDiscoveryError.cancelled
        } catch let error as AppleTVDiscoveryError {
            logger.log(.error, event: "apple_tv_discovery_failed")
            throw error
        } catch {
            logger.log(.error, event: "apple_tv_discovery_failed")
            throw AppleTVDiscoveryError.browserFailed
        }
    }

    private func browse(
        service: AppleTVBonjourService,
        timeout: Duration
    ) async throws -> [AppleTVDiscoveryObservation] {
        let accumulator = AppleTVDiscoveryAccumulator()

        return try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for try await update in Self.updates(for: service) {
                    try Task.checkCancellation()
                    await accumulator.replace(with: update)
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

    private nonisolated static func updates(
        for service: AppleTVBonjourService
    ) -> AsyncThrowingStream<Set<AppleTVDiscoveryObservation>, Error> {
        AsyncThrowingStream { continuation in
            let browser = NWBrowser(
                for: .bonjourWithTXTRecord(type: service.rawValue, domain: "local."),
                using: .tcp
            )
            let queue = DispatchQueue(label: "com.danielhagen.aura.apple-tv.discovery")

            browser.browseResultsChangedHandler = { results, _ in
                let observations = Set(results.compactMap { result in
                    Self.observation(from: result, service: service)
                })
                continuation.yield(observations)
            }

            browser.stateUpdateHandler = { state in
                switch state {
                case .failed:
                    continuation.finish(throwing: AppleTVDiscoveryError.browserFailed)
                case .cancelled:
                    continuation.finish()
                case .setup, .waiting, .ready:
                    break
                @unknown default:
                    continuation.finish(throwing: AppleTVDiscoveryError.browserFailed)
                }
            }

            continuation.onTermination = { _ in
                browser.cancel()
            }

            browser.start(queue: queue)
        }
    }

    private nonisolated static func observation(
        from result: NWBrowser.Result,
        service: AppleTVBonjourService
    ) -> AppleTVDiscoveryObservation? {
        let endpoint = result.endpoint
        guard case let .service(name, type, domain, _) = endpoint,
              type == service.rawValue else {
            return nil
        }

        if service == .companion {
            guard case .bonjour(let txtRecord) = result.metadata else { return nil }
            let properties = Dictionary(uniqueKeysWithValues: txtRecord.dictionary.map {
                ($0.key.lowercased(), $0.value)
            })
            guard properties["rpmd"]?.hasPrefix("AppleTV") == true else { return nil }
        }

        return AppleTVDiscoveryObservation(
            endpoint: AppleTVBonjourEndpoint(
                serviceName: name,
                serviceType: service,
                domain: domain
            )
        )
    }
}

private actor AppleTVDiscoveryAccumulator {
    private var observations: Set<AppleTVDiscoveryObservation> = []

    func replace(with update: Set<AppleTVDiscoveryObservation>) {
        observations = update
    }

    func snapshot() -> [AppleTVDiscoveryObservation] {
        Array(observations)
    }
}
