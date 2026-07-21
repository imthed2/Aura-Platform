# ADR-001: Project and dependency-management approach

- Status: Accepted
- Date: 2026-07-21

## Context

Aura needs a reviewable iPhone application foundation that builds with Xcode, supports an application target plus unit and UI tests, and does not depend on unverified integrations or third-party packages. The repository currently contains only product and architecture documentation.

The composition root also owns a Main Actor-isolated navigation store. Although the illustrative `AppEnvironment` in `20_App_Architecture` is marked `Sendable`, moving a presentation state owner across actors would be misleading and unnecessary.

## Decision

Aura will use a checked-in native Xcode project with one iOS application target, one unit-test target, and one UI-test target. The initial code remains in one application module while folders preserve the documented Presentation, Application, Domain, Platform, and Feature boundaries.

The project uses SwiftUI, Swift 6 language mode, complete strict-concurrency checking, and an iOS 18 minimum deployment target. No third-party runtime or build dependency is introduced.

`AppEnvironment` is a Main Actor-isolated composition value because it contains the Main Actor-owned `NavigationStore` and haptic service. Dependencies that perform non-UI work remain independently `Sendable`; the environment is not used as a cross-actor service locator.

## Alternatives considered

- Swift Package Manager alone: rejected because it cannot represent the required iOS application and UI-test targets by itself.
- A third-party project generator: deferred because the first milestone does not justify an additional tool, version, or maintenance dependency.
- Multiple Swift packages immediately: deferred until module boundaries improve build isolation, test isolation, or reuse enough to justify them.
- A globally mutable service locator: rejected because it obscures ownership and conflicts with `20_App_Architecture`.

## Consequences

- The Xcode project file is reviewed and versioned with the source.
- Logical boundaries are established without premature package fragmentation.
- All external boundaries can be injected and mocked.
- New source files must be added to the relevant target in the Xcode project until a future project-generation ADR is accepted.
- Persistence technology, real device integrations, permissions, entitlements, and certificate strategies remain explicitly undecided.

