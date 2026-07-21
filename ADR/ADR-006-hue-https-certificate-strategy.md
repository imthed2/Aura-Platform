# ADR-006: Hue HTTPS certificate and bridge-identity strategy

- Status: Proposed — blocked on authenticated vendor guidance and completion of hardware verification
- Date: 2026-07-21

## Context

Aura's first real-device integration is intended to be a Philips Hue Bridge v2. Hue API v2 uses HTTPS, and Philips Hue announced that current bridge firmware no longer supports HTTP. Hue also describes the bridge certificates used for this transition as Signify-signed.

An IP address is only a route to a bridge. It may change through DHCP and may later identify a different device. Aura therefore cannot treat a successful TLS handshake to an IP address, an mDNS result, a discovery response, or possession of a previously issued application key as sufficient bridge identity.

Apple's URL Loading System normally evaluates server trust. If Aura handles a server-trust challenge itself, it becomes responsible for evaluating the received `SecTrust` before creating a trust credential. Apple also recommends planning for certificate rotation and, when pinning is necessary, preferring a CA or public-key strategy over one leaf certificate.

The public Hue material does not expose enough detail to safely finalize the local bridge validation algorithm. The current application-design guidance that covers certificate handling requires a Hue developer login. A Hue Bridge v2 is available for read-only inspection, but one bridge observation cannot establish the supported trust anchors, renewal behavior, or firmware differences.

## Decision

Aura will use the following fail-closed design for Hue communication:

1. All Hue local API v2 requests and event streams use HTTPS. There is no HTTP fallback and no App Transport Security exception that weakens transport requirements.
2. Cached records, mDNS, Hue-assisted discovery, and manual addresses produce untrusted connection candidates. An address is never persisted as bridge identity.
3. The Hue networking boundary validates server trust before sending an application key, pairing request, or other sensitive payload. It must use Security framework trust evaluation and the current Signify-supported trust chain and identity rules.
4. Aura binds an accepted connection to the expected stable Hue bridge identifier. The exact certificate field, normalization algorithm, and trust anchor are deliberately not selected until the verification gates below pass.
5. A trust failure, bridge-identifier mismatch, expired certificate, unsupported certificate chain, or ambiguous identity cancels the request. Release builds provide no user override, trust-all path, or silent downgrade.
6. Hue application keys are stored in Keychain under the verified stable bridge identifier. Rediscovery may update the host and port only after the new route validates as the same bridge.
7. The shared HTTP layer owns challenge plumbing, cancellation, timeouts, and bounded responses. A Hue-specific trust policy owns vendor certificate and bridge-identity semantics. SwiftUI, discovery UI, and the domain layer do not evaluate certificates.
8. Diagnostics may record a redacted trust outcome, certificate-chain classification, firmware version, and stable per-report pseudonym. They must not export application keys, full bridge identifiers, raw certificates, serial numbers, or unredacted network addresses.

No production Hue networking code may be merged from this ADR alone. Implementation remains blocked until both verification gates are complete.

## Verification gates

### Vendor-documentation gate

Using an authorized Hue developer account, record the current first-party requirements for:

- Supported bridge certificate authorities and required anchors
- The certificate field that represents the bridge identifier
- Identifier normalization and comparison rules
- Host-name or IP-address policy when connecting to a local address
- Certificate validity, renewal, and rotation behavior
- Differences between Hue Bridge v2 and Hue Bridge Pro, if any

The results must update this ADR with the exact algorithm and identify any vendor certificate material that may legally and securely ship in the app.

### Hardware gate

On supported bridge hardware and current firmware, verify without recording secrets:

- Certificate chain, subject alternative names, identity field, key type, and validity period
- A valid connection by IP address and by discovered host name
- Rejection of a wrong bridge identifier and an unrelated certificate
- Behavior after bridge restart, DHCP address change, and certificate or firmware update
- Pairing and API requests are not sent before trust succeeds
- Compatibility with both an unpaired candidate and an already paired bridge

Evidence should include sanitized test output and firmware versions. A single observed certificate must not be promoted into a permanent leaf-certificate pin.

### Sanitized hardware observation — 2026-07-21

A read-only inspection of one Hue Bridge v2 produced the following evidence. No API request, pairing request, application key, device command, or state mutation was made.

- Local mDNS advertised one `_hue._tcp` service on port 443 with model `BSB002`.
- The official Hue iPhone app reported the bridge connected on software version `1.78.1978074000`. This firmware value is user-reported evidence and was not retrieved through an Aura API request.
- The advertised stable bridge identifier matched the physical label and the leaf certificate's common name and serial number. Exact identifiers are intentionally omitted.
- The discovered host name used a shorter hardware-address form and did not equal the full stable bridge identifier.
- The bridge sent one leaf certificate. Its subject organization was Philips Hue and its issuer common name was `root-bridge`; the issuer certificate was not included in the handshake.
- The leaf certificate contained no subject alternative name, Authority Information Access extension, or certificate revocation-list distribution point. It used an ECDSA P-256 public key, an ECDSA-with-SHA-256 signature, critical non-CA basic constraints, and a validity window spanning 2017–2038.
- The discovered IPv6 host route and IPv4 route returned the same leaf certificate.
- The bridge negotiated TLS 1.2 with `ECDHE-ECDSA-AES128-GCM-SHA256` during this observation.
- OpenSSL could not build the certificate chain from its default trust store, and macOS Security.framework reported the certificate as not trusted. This is expected evidence that Aura needs the vendor-supported Hue trust anchor and policy; it is not justification to bypass validation.
- No exact bridge identifier, address, certificate fingerprint, certificate bytes, QR payload, or setup data was committed.

This partially satisfies the hardware gate by establishing the observed certificate shape, identity relationship, and reported firmware version. The gate remains open until the authorized Hue documentation supplies the supported root material and policy, and until Aura verifies trusted evaluation, negative identity cases, restart, address change, firmware-update and certificate-rotation behavior, and pre-credential failure behavior.

## Required automated tests

The later implementation must cover:

- Accepted Signify-supported chain with matching bridge identity
- Valid chain with the wrong bridge identity
- Untrusted, expired, malformed, and incomplete chains
- Address change with unchanged verified bridge identity
- Address reuse by a different bridge
- Certificate renewal or approved anchor rotation
- Cancellation before credentials or pairing data are transmitted
- Redaction of all trust diagnostics

## Alternatives considered

- Trust every certificate presented by a local IP address: rejected because local networks are not trusted identity boundaries and this would enable credential disclosure to an impostor.
- Use HTTP when HTTPS validation fails: rejected because Hue requires HTTPS and downgrade would expose credentials and home-control traffic.
- Pin the first leaf certificate observed during discovery: rejected because discovery is unauthenticated and leaf certificates can expire or rotate.
- Pin one observed Hue leaf certificate in the application: rejected because it would not identify other bridges and would create brittle renewal behavior.
- Accept any system-trusted certificate without binding it to the expected bridge: rejected because trust in an issuer does not prove that the endpoint is the bridge the user selected.
- Prompt the user to approve certificate details: rejected because certificate interpretation is not a safe consumer decision and would encourage bypassing an identity failure.

## Consequences

- Hue work starts with an explicit security and hardware spike rather than production commands.
- The app can recover from DHCP changes without confusing address with identity.
- Certificate rotation can be supported deliberately instead of through a trust-all escape hatch.
- Initial implementation cost is higher because trust evaluation, identity binding, redaction, and negative tests are first-class work.
- The exact trust anchor and identifier-binding algorithm remain unresolved; this ADR stays Proposed until they are verified.

## First-party references

- [Philips Hue: Deprecation of HTTP support](https://developers.meethue.com/)
- [Philips Hue: New Hue API](https://developers.meethue.com/new-hue-api/)
- [Philips Hue: Get Started](https://developers.meethue.com/develop/get-started-2/)
- [Apple: Performing manual server trust authentication](https://developer.apple.com/documentation/foundation/performing-manual-server-trust-authentication)
- [Apple: `SecTrustEvaluateWithError`](https://developer.apple.com/documentation/security/sectrustevaluatewitherror%28_%3A_%3A%29)
