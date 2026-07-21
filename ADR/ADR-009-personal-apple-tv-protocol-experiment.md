# ADR-009: Personal Apple TV protocol experiment

- Status: Accepted
- Date: 2026-07-21
- Supersedes: ADR-007 implementation block

## Context

Aura's owner requires direct Apple TV control in Version 1. Apple's public iPhone frameworks do not expose the necessary consumer-app discovery, pairing, navigation, power, playback, and status APIs.

The intended distribution is now explicitly limited to the owner's iPhone through private TestFlight builds that expire after 90 days or through direct Xcode installation. Aura is not being prepared for public App Store distribution at this stage.

Open-source projects such as `pyatv` demonstrate direct control by implementing Apple's undocumented Companion, Media Remote Protocol, and related LAN protocols. This route carries tvOS compatibility, TestFlight review, security, maintenance, and protocol-change risk.

## Decision

Aura may implement an experimental Apple TV integration using undocumented LAN protocols for the owner's private build.

This approval is deliberately narrow:

1. The implementation may speak Companion, Media Remote Protocol, and required related network protocols directly over the local network.
2. Aura must not link Apple private frameworks, call private selectors, use runtime symbol lookup to reach private APIs, or redistribute Apple binaries or confidential material.
3. Apple TV protocol code stays inside `Integrations/AppleTV` behind vendor-neutral discovery, pairing, command, credential, and diagnostics contracts.
4. Runtime addresses and device identifiers may exist in memory because network control requires them. They must not be hardcoded, committed, uploaded, included in normal logs, or exported without redaction.
5. Pairing credentials must be stored in Keychain under a stable, verified device identity. They must never be stored in ordinary settings, fixtures, source code, screenshots, or logs.
6. Discovery must be bounded to known Apple TV service types. Broad port scanning is prohibited.
7. Pairing requires explicit owner interaction and must support cancellation. Aura must not attempt default passwords, reuse credentials across devices, or send commands before pairing succeeds.
8. Commands must report dispatched, confirmed, failed, timed-out, or unknown outcomes honestly. A socket write alone is not confirmation.
9. Network inputs are untrusted. Framing, property lists, protobuf payloads, OPACK values, and TXT records require size limits and strict decoding.
10. The integration is labeled Experimental in diagnostics and release notes until real-hardware tests pass across the owner's supported tvOS versions.
11. No cloud relay, analytics, or device-data upload is introduced.
12. TestFlight acceptance is not assumed. Direct Xcode installation is the fallback distribution route if Apple rejects the build.

## Initial implementation sequence

The work proceeds as reviewable vertical slices:

1. Bounded Bonjour discovery and sanitized candidate mapping
2. Pairing state machine with test vectors and Keychain-backed credentials
3. Authenticated Companion session and basic navigation commands
4. Power and playback commands with honest acknowledgement semantics
5. Metadata and status synchronization
6. Hardware compatibility evidence and failure recovery

Each slice requires deterministic unit tests before hardware testing. Discovery does not authorize pairing; pairing does not authorize commands; a working command does not authorize synthetic state confirmation.

## Dependency policy

No third-party runtime dependency is approved by this ADR alone. A dependency may be proposed when it materially reduces cryptographic or protocol risk, but its license, maintenance, transitive packages, platform support, binary contents, and protocol implementation must be reviewed first.

Public open-source implementations may be used as protocol research sources. Any adapted code must comply with its license and retain required notices. Repository documentation must distinguish observed behavior from Apple-supported contracts.

## Alternatives considered

- Remove direct Apple TV control: rejected by the product owner because it removes a defining Aura experience.
- Use only Control Center Remote or Shortcuts: rejected as the primary experience because Aura cannot own or verify those actions.
- Link Apple's private MediaRemote frameworks: rejected because private framework use creates a stronger platform-integrity and static-review risk than an isolated network implementation.
- Run `pyatv` in a cloud or LAN sidecar: deferred because Aura is local-first and the owner wants a standalone iPhone app.
- Ship immediately without protocol isolation: rejected because undocumented behavior will require replacement and compatibility work.

## Consequences

- Direct Apple TV control can be developed for the owner's real environment.
- The feature may stop working after tvOS updates and will require hardware regression tests.
- TestFlight may reject a build even though distribution is private; no approval is promised.
- Protocol and cryptographic implementation work is substantial and security-sensitive.
- Aura preserves a clean vendor-neutral boundary so the experimental route can later be replaced by a public Apple API.
- ADR-007 remains the record of public API limitations; this ADR accepts the private-distribution risk that ADR-007 identified.

## Exit criteria

The experiment may be treated as usable for the owner only when:

- Discovery, pairing, reconnect, and credential deletion pass on real hardware
- Required remote, playback, and power commands have verified outcomes
- Credentials exist only in Keychain
- Diagnostics and exported evidence contain no secrets or unredacted addresses or identifiers
- Network interruption and tvOS restart recovery are bounded
- Unit, integration, app build, and simulator smoke tests pass
- The exact tested Apple TV model and tvOS version are recorded without committing personal identifiers

## Research references

- [Apple: Set up the Apple TV Remote on iPhone or iPad](https://support.apple.com/en-ca/108778)
- [Apple: Local Network Privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
- [Apple: Network framework](https://developer.apple.com/documentation/network)
- [pyatv repository](https://github.com/postlund/pyatv)
- [pyatv Companion protocol research](https://github.com/postlund/pyatv/issues/655)
