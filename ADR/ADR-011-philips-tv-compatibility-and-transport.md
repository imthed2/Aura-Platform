# ADR-011: Philips TV compatibility and transport feasibility

- Status: Proposed
- Date: 2026-07-22

## Context

Aura targets the owner's Philips `65PUS7800/12`. AURA-12 is a product-level specification rather than a verified endpoint contract, and `TECHNICAL_REVIEW.md` prohibits assuming that behavior from another Philips model applies to this television.

Philips' historical JointSpace documentation describes a local JSON API, but the target television's current API generation, advertisement behavior, authentication, certificate, standby, and command behavior require direct verification. Philips' current product sheet also states that Philips TV Remote functionality varies by model, country, device, and operating system.

## Read-only evidence

The following observations were made on the owner's local network on 2026-07-22. No pairing, credentials, state-changing requests, or commands were used.

- One bounded SSDP `M-SEARCH` for `urn:dial-multiscreen-org:service:dial:1` returned a description whose manufacturer was `Philips` and whose advertised model was `PUS7800`.
- Targeted searches for the generic UPnP `MediaRenderer:1` and `Basic:1` device types did not identify this television and are not needed for the initial provider.
- Read-only `GET /1/system` and `GET /6/system` requests on port `1925` returned HTTP `200`.
- The same read-only path for API versions 2 through 5 returned HTTP `404`.
- Both successful responses reported JointSpace API version `6.1.0`.
- Identity, model, serial-number, and software-version fields in the system response were encrypted; their values were not retained or committed.
- A read-only HTTPS request to API v6 on port `1926` failed normal Apple system trust with `NSURLErrorServerCertificateUntrusted` (`-1202`). No trust bypass was attempted.
- The SSDP description advertised only the family string `PUS7800`; the full `65PUS7800/12` identity remains a project/owner assertion until a securely authenticated response verifies it.

## Decision

The first implementation slice is discovery and compatibility parsing only.

1. Aura sends one DIAL-specific SSDP search. It does not use `ssdp:all`, generic port scanning, or the two generic UPnP searches that did not identify the target.
2. SSDP responses are untrusted observations, not devices. Aura accepts a bounded response only when it has a successful SSDP status, the exact DIAL search target, one description URL, no URL credentials, and a private or link-local IPv4 host.
3. Device descriptions are size-bounded, reject document type declarations, disable external-entity resolution, and must identify `Philips` or `TP Vision` plus the exact advertised target family `PUS7800`.
4. Discovery logs use fixed event names and contain no addresses, names, serial numbers, identifiers, response bodies, or credentials.
5. API-version parsing retains only the numeric API version needed for compatibility decisions.
6. Pairing, credential storage, authenticated requests, commands, power behavior, standby/wake behavior, input switching, volume, navigation, polling, and production HTTP/TLS policy are explicitly deferred.
7. Aura will not add a trust-all TLS delegate, an App Transport Security exception, or a silent HTTP downgrade to make control work.

## Consequences

- Aura can find the target family through the smallest observed discovery surface without claiming it is paired or controllable.
- The production control transport remains blocked until certificate identity, authentication, and credential handling are separately decided and tested.
- IPv6 and hostname-based SSDP locations are not accepted by this first target-specific slice. Support may be added only with equivalent local-address validation and tests.
- The exact firmware version, full model identity, standby/wake behavior, supported commands, and capability matrix remain unverified.

## Next verification gate

Before pairing or control code is added:

1. Inspect the target certificate chain without bypassing trust and define how it binds to a verified TV identity.
2. Observe the target's pairing challenge using owner interaction, without logging or committing secrets.
3. Store resulting credentials only in Keychain.
4. Verify one read-only authenticated state request before any command.
5. Add deterministic fixtures for authentication rejection, malformed responses, cancellation, timeout, and certificate mismatch.

## References

- [Philips JointSpace: Getting Started](https://jointspace.sourceforge.net/projectdata/documentation/jasonApi/1/doc/API-gettingstarted.html)
- [Philips JointSpace API reference](https://jointspace.sourceforge.net/projectdata/documentation/jasonApi/1/doc/API.html)
- [Philips 65PUS7800/12 product sheet](https://www.documents.philips.com/assets/20250102/0bd0cb7c3c1147d09db4b25900bd8be0.pdf)
- AURA-12 Philips TV Integration
- AURA-16 Device Discovery
- AURA-19 Diagnostics
- AURA-20 App Architecture
- AURA-21 Codex Rules
- `TECHNICAL_REVIEW.md`
