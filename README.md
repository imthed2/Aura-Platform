# Aura Platform

> **Control Less. Experience More.**

Aura is a local-first, experience-driven smart-home platform for iPhone. This repository contains the product, design, integration, architecture and implementation specifications that guide development.

## Documentation status

Documents 00–21 now exist in the repository. Document 22 — Roadmap is the remaining planned platform document.

> Note: The documentation files were originally created without a `.md` filename extension. The links below point to their real repository paths. New numbered documentation should use the same convention until all files are migrated together in one coordinated change.

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

## Review and planning

- [Technical Review](./TECHNICAL_REVIEW.md)
- 22 — Roadmap — planned

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

Feature-specific documents define behavior within those shared architectural boundaries.

## Documentation rules

Each technical document should define its purpose, goals, non-goals, dependencies, architecture, state model, error handling, security, privacy, performance budgets, testing strategy and acceptance criteria.

Implementation-specific claims must be verified against current first-party platform documentation and real supported hardware before production code is considered complete.
