# ADR-007: Apple TV public capability scope

- Status: Proposed — product-scope approval required
- Date: 2026-07-21

## Context

Aura's product documents describe direct Apple TV discovery, pairing, wake and sleep, remote navigation, playback commands, Now Playing metadata, artwork, application detection, and status synchronization.

Those are product desires, not proof of an API. Aura may ship only capabilities supported by public Apple frameworks and App Store-compatible behavior. As of Xcode 26.3 and the installed iOS 26.2 SDK, the public iPhone frameworks contain no Apple TV remote-control client API that authorizes a third-party app to pair with and control the Apple TV system interface.

Apple provides an Apple TV Remote through Control Center. That system-owned experience is not exposed as a general remote-control framework for third-party apps. The public APIs that mention remotes, playback, AirPlay, HomeKit, App Intents, and Handoff serve narrower purposes and cannot be combined to imply system-level Apple TV control.

## First-party findings

### System Apple TV Remote

Apple documents the Apple TV Remote as a Control Center experience on iPhone and iPad. No documented URL scheme, App Intent, or public framework was found that lets Aura launch, embed, automate, or impersonate that remote.

### AirPlay and route selection

`AVRoutePickerView` presents system UI that lets a person route media owned by the current app to an AirPlay receiver such as Apple TV. It does not give Aura a general Apple TV device connection, remote navigation, power control, or access to the receiver's unrelated playback state.

### MediaPlayer and Now Playing

`MPRemoteCommandCenter` receives external commands for media playback handled by the current app. `MPNowPlayingInfoCenter` publishes information for media the current app plays. The newer Now Playing remote-session APIs describe sessions an app itself manages on an external device; they do not grant access to an arbitrary Apple TV system session.

### HomeKit

HomeKit controls accessories and services that the framework actually exposes. `HMHome.homeHubState` reports only the aggregate state of a home's hub; it does not identify or control an individual Apple TV. Public television and set-top-box accessory categories do not prove that Apple TV appears as a controllable `HMAccessory`.

If a future entitlement-backed hardware test returns an Apple TV-related accessory or service, Aura may expose only the public characteristics present at runtime, through the HomeKit integration boundary. Product name alone never enables capabilities.

### Game Controller

Game Controller APIs allow an app—particularly a tvOS game or media app—to receive input from physical or virtual controllers, including Siri Remote profiles. They do not synthesize commands to control the Apple TV system from Aura on iPhone.

### App Intents and Shortcuts

App Intents exposes Aura's own actions to Siri, Shortcuts, widgets, and other system experiences. It does not make another app's or the system remote's private implementation callable by Aura.

A person may build a Shortcut that combines a system-provided Apple TV action with an Aura App Intent. That shortcut remains user-configured and system-executed. Aura cannot inspect its private steps, treat its result as a confirmed Aura device command, or silently create it.

The beta `RunSystemShortcutIntent` announced in 2026 is limited to a person-configured widget button and is opaque to the app. It is not a direct-control escape hatch and is outside Aura's iOS 18 baseline.

### Handoff

Handoff transfers an activity between apps signed by the same developer team so the receiving app can continue that activity. A future Aura tvOS companion could continue Aura-owned state, but Handoff cannot control the Apple TV system UI or other tvOS apps.

## Decision

Aura Version 1 will not implement a direct Apple TV plugin unless Apple publishes a suitable public API and this ADR is superseded.

Specifically:

1. Aura will not implement or ship reverse-engineered Apple TV, MediaRemote, Companion, AirPlay-control, or other undocumented protocols.
2. Aura will not perform direct Apple TV discovery, pairing, credential storage, remote navigation, wake, sleep, playback control, Now Playing reads, artwork reads, application detection, or status polling.
3. Unsupported Apple TV controls remain absent from production UI. Mock Apple TV data may be used only in clearly identified preview and layout fixtures; it is not capability evidence.
4. Aura may explain how to use Apple's Control Center remote, but it will not use an undocumented URL scheme or private API to open or embed it.
5. Aura may present `AVRoutePickerView` only in a feature where Aura owns the media being routed. AirPlay routing is not represented as an Apple TV device capability.
6. The HomeKit integration may report aggregate home-hub availability and may map public television-related services that actually appear at runtime. It must not infer that a hub is an Apple TV or that Apple TV is controllable.
7. Future Aura App Intents expose only Aura-owned actions. A user-composed Shortcut may coordinate system Apple TV actions with Aura actions, but execution is external and cannot be reported as a confirmed Apple TV step inside an Aura Scene.
8. A future Aura tvOS companion and Handoff flow require a separate product and architecture decision. Such an app would control only Aura-owned experiences.
9. Scene validation rejects direct Apple TV command steps while this decision is active. Existing aspirational flows must omit the step or label it as an external, unverified user action; they must never report synthetic success.
10. Diagnostics reports the capability route as unavailable or system-managed. It does not fabricate connection, authentication, playback, or command health.

## Capability matrix

| Product desire | Public surface reviewed | Version 1 decision |
| --- | --- | --- |
| Discover and pair Apple TV | Control Center Remote; AirPlay system UI; installed public SDK | Not available to Aura |
| Directional, Select, Back, Home, TV, Menu | Game Controller receives input inside an app | Not available to Aura |
| Wake and sleep | System Remote and user-facing system experiences | Not available as an Aura command |
| Play, pause, seek, fast-forward, rewind | MediaPlayer/Now Playing for app-managed playback | Not available for arbitrary Apple TV playback |
| Now Playing, artwork, application, progress | MediaPlayer/Now Playing publication by the managing app | Not readable from arbitrary Apple TV sessions |
| Volume | System Remote or current media-route behavior | Not an Apple TV capability in Aura |
| AirPlay destination selection | `AVRoutePickerView` | Allowed only for Aura-owned media |
| Home hub status | `HMHome.homeHubState` | Aggregate diagnostic state only |
| HomeKit television characteristics | Runtime `HMAccessory` services and characteristics | Allowed only when actually exposed |
| Siri and Shortcuts | Aura App Intents; user-authored shortcuts | Aura actions only; cross-app composition is user-managed |
| Handoff | `NSUserActivity` between same-team apps | Future Aura companion only |

## Alternatives considered

- Adopt a third-party Apple TV protocol library: rejected because library availability does not make an undocumented protocol public, stable, legally approved, or App Store-safe.
- Implement discovered AirPlay or Companion services directly: rejected because Bonjour visibility is not permission to implement undocumented control protocols.
- Treat Apple TV as a HomeKit accessory by product name: rejected because HomeKit capabilities must come from runtime services and characteristics.
- Use an undocumented URL scheme to open the system remote: rejected because no first-party contract guarantees availability or App Review acceptance.
- Keep the controls visible but disabled: rejected because Aura hides unsupported capabilities and disabled controls would preserve a misleading product promise.
- Report a user Shortcut as an Aura command: rejected because Aura cannot validate the shortcut's steps, target, execution, or result.

## Consequences

- The Version 1 product scope is smaller than `01_Product_Requirements` and `13_Apple_TV` currently describe.
- Movie Night cannot guarantee waking or controlling Apple TV. Television HDMI-CEC behavior may occur independently but cannot be attributed to a successful Aura Apple TV action.
- Users retain Apple's full Control Center Remote experience and may compose their own Shortcuts with future Aura App Intents.
- Aura avoids private protocol maintenance, credential risk, App Review risk, and false success reporting.
- This ADR must be revisited when Apple publishes a relevant public API, when HomeKit hardware enumeration provides new public characteristics, or before adding an Aura tvOS companion.

## Acceptance gates

This ADR may become Accepted after product review confirms:

- Version 1 can omit direct Apple TV control
- Apple TV controls are removed or clearly gated in production information architecture
- Scene definitions cannot contain unsupported Apple TV commands
- Marketing and acceptance criteria do not promise direct Apple TV control
- User-facing system handoff language does not imply that Aura executed or verified the action

## First-party references

- [Apple Support: Set up the Apple TV Remote on iPhone or iPad](https://support.apple.com/en-ca/108778)
- [Apple: `AVRoutePickerView`](https://developer.apple.com/documentation/avkit/avroutepickerview)
- [Apple: Supporting AirPlay in your app](https://developer.apple.com/documentation/avfoundation/supporting-airplay-in-your-app)
- [Apple: Media Player](https://developer.apple.com/documentation/mediaplayer)
- [Apple: Now Playing](https://developer.apple.com/documentation/nowplaying)
- [Apple: HomeKit](https://developer.apple.com/documentation/homekit)
- [Apple: `HMHome`](https://developer.apple.com/documentation/homekit/hmhome)
- [Apple: Game Controller](https://developer.apple.com/documentation/gamecontroller)
- [Apple: App Intents](https://developer.apple.com/documentation/appintents)
- [Apple: `RunSystemShortcutIntent`](https://developer.apple.com/documentation/appintents/runsystemshortcutintent)
- [Apple: Implementing Handoff in your app](https://developer.apple.com/documentation/foundation/implementing-handoff-in-your-app)

## Local SDK evidence

The public-framework inventory and headers in Xcode 26.3's iOS 26.2 SDK were inspected on 2026-07-21. They include AVFoundation, AVKit, HomeKit, MediaPlayer, GameController, and related public types described above, but no public Apple TV remote-control client framework.
