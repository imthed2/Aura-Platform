# Aura repository guidance

Before changing implementation files, read these documents in order:

1. `21_Codex_Rules` — mandatory execution, safety, testing, and reporting contract.
2. `20_App_Architecture` — primary technical architecture contract.
3. `22_Roadmap` — milestone order, gates, and bounded scope.
4. The feature specifications relevant to the requested change.

For UI work, also read `03_Aura_Design_Language`, `04_Design_Tokens`, `07_Screen_Specifications`, `08_Component_Library`, `09_Interaction_Guidelines`, `10_Motion_System`, and `11_Haptics`.

For integration work, also read `16_Device_Discovery`, `19_Diagnostics`, the relevant vendor document, and `TECHNICAL_REVIEW.md`.

Authority and working rules:

- Follow the authority order in `21_Codex_Rules`; do not hide documentation conflicts in code.
- Preserve the dependency direction defined by `20_App_Architecture`.
- Keep SwiftUI independent from vendor frameworks and network response models.
- Add no third-party dependency without an explicit, documented decision.
- Work on a feature branch for meaningful implementation changes.
- Build and run the strongest relevant tests before claiming completion.
- Report anything that remains unverified, especially hardware, entitlements, permissions, background behavior, and vendor APIs.

