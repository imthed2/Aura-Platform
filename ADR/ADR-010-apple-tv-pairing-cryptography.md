# ADR-010: Apple TV pairing cryptography dependencies

- Status: Accepted
- Date: 2026-07-21
- Applies to: ADR-009 personal Apple TV protocol experiment

## Context

Companion Pair Setup uses Secure Remote Password with the RFC 5054 3072-bit group and SHA-512. CryptoKit provides SHA-512, HKDF, Ed25519, X25519 and ChaCha20-Poly1305, but it does not provide SRP or arbitrary-precision modular arithmetic.

Implementing SRP big-number operations directly in Aura would create avoidable authentication and side-channel risk. The dependency must remain isolated inside `Integrations/AppleTV`; no dependency type may cross into Aura's domain or presentation layers.

## Decision

Aura's private Apple TV experiment will use:

- `swift-srp` 2.3.0 or a compatible 2.x release for SRP-6a/RFC 5054 group operations and shared-secret calculation.
- `swift-crypto` 3.x for the `Crypto` module required by `swift-srp` and for a consistent SHA-512 implementation.
- `big-num`, transitively through `swift-srp`, for modular arithmetic.
- `swift-asn1`, resolved transitively by `swift-crypto`; no `swift-asn1` target is linked by the current Aura target graph.

HAP's proof transcript encodes SRP integers without the generic helper's proof padding. Aura therefore derives the HAP client and server proofs from `swift-srp`'s shared secret using `Crypto` SHA-512 and verifies the server proof in constant time. A deterministic vector generated from the Companion reference implementation protects this compatibility rule.

All other pairing cryptography uses the reviewed `Crypto` APIs: SHA-512, HKDF-SHA512, Ed25519 and ChaCha20-Poly1305. Aura implements only bounded Companion framing, TLV8 and the small OPACK subset needed by Pair Setup.

## Review

- Problem solved: SRP-3072 modular arithmetic and shared-secret calculation; Aura owns the small HAP-specific proof transcript adapter.
- Apple-framework gap: CryptoKit has no SRP or public arbitrary-precision integer API.
- Maintenance: `swift-srp` 2.3.0 was released in April 2026 and declares Swift 6/iOS support; its dependency ranges allow current `swift-crypto` and `big-num` releases.
- License: `swift-srp`, `swift-crypto` and `swift-asn1` use Apache-2.0; `big-num` uses MIT. Package licenses must remain available through Swift Package Manager metadata and release attribution.
- Binary impact: source packages add SRP and big-number code to the Apple TV integration. Exact optimized binary growth is not yet measured and must be recorded before a release candidate.
- Privacy: no telemetry, network service or binary SDK is introduced. All packages are source libraries.
- Security: audited library use is lower risk than new SRP arithmetic, but undocumented protocol behavior and dependency vulnerabilities remain risks. Server proofs and accessory signatures must still be verified by Aura.
- Concurrency: the value-oriented cryptographic operations run within the pairing actor; dependency objects do not cross actor boundaries.
- Exit strategy: confine imports to the Apple TV integration. The packages can be removed with that integration or replaced behind its pairing protocol.

## Verification evidence

- Deterministic HAP proof and server-proof vectors pass in the simulator unit suite.
- Pair Setup, server-proof verification, accessory-signature verification and Keychain persistence completed against the owner's Apple TV 4K (first generation) on 2026-07-21.
- The exact tvOS version remains unverified and must be recorded before the experiment meets ADR-009's full exit criteria.

## Consequences

- Apple TV Pair Setup can use a tested RFC 5054 implementation.
- Aura resolves four source packages including transitive dependencies; three provide linked targets in the current build graph.
- Dependency resolution now requires network access on a clean checkout.
- Dependency versions must be reviewed during security maintenance.
- This decision does not approve public App Store distribution or Apple private frameworks.

## References

- [swift-srp](https://github.com/adam-fowler/swift-srp)
- [swift-crypto](https://github.com/apple/swift-crypto)
- [RFC 5054](https://www.rfc-editor.org/rfc/rfc5054)
