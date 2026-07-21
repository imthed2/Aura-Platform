# Aura Platform

> **Control Less. Experience More.**

Aura is a local-first, experience-driven smart-home platform for iPhone. This repository contains the product, design, integration, architecture, implementation and planning specifications that guide development.

## Documentation status

The complete documentation set from 00 through 22 now exists in the repository.

> Note: The numbered documentation files were originally created without a `.md` filename extension. The links below point to their real repository paths. Keep the current convention until all numbered files are migrated together in one coordinated change.

## Product and design

- [00 — Product Vision](./00_Product_Vision)
- [01 — Product Requirements](./01_Product_Requirements)
- [02 — Brand Guidelines](./02_Brand_Guidelines)
- [03 — Aura Design Language](./03_Aura_Design_Language)
- [04 — Design Tokens](./04_Design_Tokens)
- [05 — Information Architecture](./05_Information_Architecture)
- [05.5 — Navigation System](./05.5_Navigation_System)
- [06 — User Flows](./06_User_Flows)
- [07 — Screen Specifications](./07_Screen_Specifications)
- [08 — Component Library](./08_Component_Library)
- [09 — Interaction Guidelines](./09_Interaction_Guidelines)
- [10 — Motion System](./10_Motion_System)
- [11 — Haptics](./11_Haptics)

## Integrations

- [12 — Philips TV](./12_Philips_TV)
- [13 — Apple TV](./13_Apple_TV)
- [14 — HomeKit](./14_HomeKit)
- [15 — Philips Hue Bridge](./15_Hue_Bridge)

## Platform and architecture

- [16 — Device Discovery](./16_Device_Discovery)
- [17 — Scene Engine](./17_Scene_Engine)
- [18 — Automation Engine](./18_Automation_Engine)
- [19 — Diagnostics](./19_Diagnostics)
- [20 — App Architecture](./20_App_Architecture)
- [21 — Codex Rules](./21_Codex_Rules)
- [22 — Roadmap](./22_Roadmap)

## Review and planning

- [Technical Review](./TECHNICAL_REVIEW.md)

## Current project stage

Documentation foundation: complete.

The first bounded implementation milestone is in progress on `feature/phase-1-aura-foundation`:

- Create the Xcode project and test targets
- Add root `AGENTS.md`
- Implement the application bootstrap and dependency environment
- Implement design tokens and base components
- Create the five-tab application shell
- Add vendor-neutral domain models and mock data
- Deliver a mock Home Dashboard
- Establish build and test automation

Real-device integrations should begin only after the foundation and feasibility gates in the roadmap are satisfied.

## Local development

Requirements:

- macOS with Xcode 16 or later
- An installed iOS Simulator runtime
- No third-party package installation

Open `Aura.xcodeproj` in Xcode and run the shared `Aura` scheme, or use the command line from the repository root.

Build without requiring a booted simulator:

```sh
xcodebuild \
  -project Aura.xcodeproj \
  -scheme Aura \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Run unit and UI tests on an available simulator (replace the device name when needed):

```sh
xcodebuild \
  -project Aura.xcodeproj \
  -scheme Aura \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

The app uses deterministic local mock data. It requires no account, cloud backend, local-network access, HomeKit entitlement, device credentials, or signing secrets for Simulator development.

## Core principles

Aura is designed around a small set of non-negotiable principles:

- Local-first operation
- Experiences before devices
- One unified capability model
- Plugin-based integrations
- Secure credential storage
- Graceful offline and recovery behavior
- Calm, premium and accessible interaction design
- No integration-specific API models in the SwiftUI layer
- Explicit side effects and clear state ownership
- Honest handling of platform and hardware limitations

## Architecture authority

`20_App_Architecture` is the primary technical architecture contract for the application.

`21_Codex_Rules` defines how Codex and other AI-assisted development tools must inspect, implement, test and report changes in the repository.

`22_Roadmap` defines milestone order, release gates and the first bounded implementation task.

Feature-specific documents define behavior within those shared architectural boundaries.

## Recommended development workflow

Implementation work should normally use a feature branch and pull request rather than direct commits to `main`.

Before changing code, Codex should:

1. Read `21_Codex_Rules`.
2. Read `20_App_Architecture`.
3. Read the relevant feature documents.
4. Inspect the current repository state.
5. Report conflicts or unverified platform assumptions.
6. Create a small implementation plan.
7. Build and test before presenting the change as complete.

## Documentation rules

Each technical document should define its purpose, goals, non-goals, dependencies, architecture, state model, error handling, security, privacy, performance budgets, testing strategy and acceptance criteria.

Implementation-specific claims must be verified against current first-party platform documentation and real supported hardware before production code is considered complete.
