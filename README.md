# Aura Platform

> **Control Less. Experience More.**

Aura is a local-first, experience-driven smart-home platform for iPhone. This repository currently contains the product, design, integration, architecture and implementation specifications that will guide development.

## Documentation status

Documents 00–15 exist in the repository. Documents 16–22 are planned and will be added sequentially.

> Note: The existing documentation files were originally created without a `.md` filename extension. The links below point to their real repository paths. New documentation should use the same convention until the files are migrated together, so links and references remain consistent.

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
- [15 — Hue Bridge](./15_Hue_Bridge)

## Planned platform documents

- 16 — Device Discovery
- 17 — Scene Engine
- 18 — Automation Engine
- 19 — Diagnostics
- 20 — App Architecture
- 21 — Codex Rules
- 22 — Roadmap

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

## Documentation rules

Each technical document should define its purpose, goals, non-goals, dependencies, architecture, state model, error handling, security, privacy, performance budgets, testing strategy and acceptance criteria.

Implementation-specific claims must be verified against current first-party platform documentation before production code is written.