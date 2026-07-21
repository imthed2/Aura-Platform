# Aura Platform Technical Review

Version: 1.0  
Status: Active review notes  
Scope: Documentation 00–15

## Purpose

This file records corrections, constraints and implementation checks discovered while reviewing the current Aura documentation. It is not a replacement for the individual specifications. When a document is revised, the relevant item here should be incorporated into that document and marked resolved.

## Repository consistency

### Filename convention

The current documents were created without `.md` extensions, while the original README listed them with `.md` extensions. The README has been corrected to link to the real paths.

A future repository-cleanup commit may migrate all documentation files to `.md` in one atomic change. Do not rename only a subset, because that would break cross-document links and create inconsistent conventions.

### Document maturity

Documents 00–13 are useful product and integration drafts, but many sections are intentionally architectural rather than endpoint-level implementation contracts. Before coding an integration, verify all protocol, API, entitlement, framework and platform claims against current first-party documentation.

## Hue Bridge corrections and constraints

The following rules supersede any conflicting wording in `15_Hue_Bridge` until that document is revised.

### HTTPS is required

Hue API v2 communication must use HTTPS. Aura must not implement HTTP as a production fallback. `ADR/ADR-006-hue-https-certificate-strategy.md` now records the proposed fail-closed design and has been incorporated into `15_Hue_Bridge`.

This review item is not fully resolved. The exact Signify trust anchor, certificate-to-bridge-identifier binding, host policy and rotation behavior still require authenticated Hue documentation and real-hardware verification. Production Hue networking remains blocked until both gates in ADR-006 pass.

### Discovery priority

Use cached bridge records and mDNS as the primary local discovery paths. Philips Hue has deprecated UPnP discovery, so SSDP/UPnP must not be treated as a preferred or guaranteed production method. Internet-assisted discovery may be optional, but local operation must not depend on it.

### Command-rate limits

The slider strategy in the current Hue document is too aggressive. The implementation must remain around a maximum of 10 light-resource commands per second and approximately 1 grouped-resource command per second unless current first-party guidance explicitly permits more.

Continuous animation, entertainment or high-frequency synchronization must not use ordinary REST traffic. It requires the dedicated Hue Entertainment streaming path.

### Effects model

Capability detection must prefer the current `effects_v2` feature model when present. The older effects model should be treated as compatibility behavior, not the primary long-term contract.

### State changes while off

Current Hue lights may support changing brightness, color or related state while the light is off, with the state applied when turned on. Aura must not universally assume that state writes require first powering on the light. This behavior must remain capability- and firmware-aware.

### API version isolation

Hue API v1 and v2 data models must remain isolated inside the Hue integration boundary. The general Aura domain layer must not depend on Hue resource schemas or legacy identifiers.

## HomeKit review notes

`14_HomeKit` correctly establishes a single long-lived `HMHomeManager`, delayed readiness until the manager callback, framework isolation and a normalized Sendable domain layer.

Before implementation, verify:

- Current HomeKit authorization APIs and status semantics
- Required Info.plist usage descriptions and entitlements
- Main-actor and delegate callback requirements
- Characteristic notification support per accessory
- Which HomeKit mutations are permitted for the selected app entitlement and deployment target
- Current MatterSupport commissioning rules if Matter onboarding is added later

Aura must not promise background execution or remote control beyond what iOS, HomeKit and the user's home-hub configuration actually permit.

## Philips TV review notes

The current Philips TV document is a product-level integration specification, not yet a model-specific API contract.

Before implementation, create a verified compatibility profile for the target television `65PUS7800/12`, including:

- Supported JointSpace/API generation
- Discovery behavior
- Pairing and authentication requirements
- HTTPS and certificate behavior
- Power-state limitations while the television is in standby
- Wake-on-LAN or network-standby requirements
- Supported key codes, sources, Ambilight endpoints and volume behavior
- Firmware-specific differences

No endpoint should be implemented from assumptions based on another Philips model.

## Apple TV review notes

The Apple TV integration document currently describes desired capabilities, not a guaranteed public Apple API surface.

`ADR/ADR-007-apple-tv-public-capability-scope.md` records the first-party capability assessment. The product owner rejected its proposal to omit direct Apple TV control: the capability remains required for Version 1. Because the reviewed public APIs do not provide third-party system-level discovery, pairing, navigation, power, arbitrary playback state or application detection, the Apple TV module is a release blocker pending a compliant implementation route.

Before implementation, divide features into:

1. Publicly supported Apple frameworks and system integrations
2. HomeKit-exposed capabilities
3. App Intents, Shortcuts and system handoff features
4. Unsupported or reverse-engineered protocols

Aura should not ship a production dependency on private Apple protocols without an explicit legal, reliability and App Store review decision. Unsupported capabilities must be removed or reframed rather than presented as guaranteed.

System-owned Control Center Remote, AirPlay routing for Aura-owned media, aggregate HomeKit hub state, runtime HomeKit accessory characteristics, user-composed Shortcuts and future same-team Handoff are separate public surfaces. None should be presented as proof that Aura directly controlled Apple TV.

## Architecture decisions confirmed

The following decisions are consistent across the current documentation and should remain:

- Plugin-based device integrations
- Unified capability model
- SwiftUI isolated from vendor API objects
- Actor-isolated mutable integration state
- Async networking with cancellation
- Keychain for credentials
- Event-driven updates where supported
- Polling only as a bounded fallback
- Per-capability UI rather than manufacturer assumptions
- Partial failure instead of all-or-nothing integration failure
- Sanitized diagnostics without secrets

## Required next action

Create `16_Device_Discovery` as the authoritative cross-plugin discovery specification. It must define how cached devices, Bonjour/mDNS, Network.framework, local-network permission, deduplication, stable identity, targeted rediscovery, timeouts and manual entry work across Philips TV, Apple TV, Hue and future plugins.
