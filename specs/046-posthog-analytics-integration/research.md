# Research: PostHog Product Analytics Integration

**Feature**: `046-posthog-analytics-integration` | **Date**: 2026-09-03
**Sources**: official docs (posthog.com/docs/libraries/flutter, retrieved in full 2026-09-03), pub.dev/packages/posthog_flutter (v5.39.0, published 2026-08-31), repo reconnaissance of `lib/`, `android/`, `ios/`, `macos/`, `test/`, `docs/`.

All NEEDS CLARIFICATION items from the spec/plan are resolved below. Every decision is tied to either the official docs or an existing repo pattern.

---

## D1. SDK setup mode: manual init (`AUTO_INIT=false` + Dart `Posthog().setup(config)`)

**Decision**: Disable the vendor's auto-init in each platform manifest and initialize from Dart during app bootstrap.

- `android/app/src/main/AndroidManifest.xml` → `<meta-data android:name="com.posthog.posthog.AUTO_INIT" android:value="false" />`
- `ios/Runner/Info.plist` and `macos/Runner/Info.plist` → `<key>com.posthog.posthog.AUTO_INIT</key><false/>`
- Dart: `final config = PostHogConfig(token); config.host = host; await Posthog().setup(config);`

**Rationale**: The docs restrict several capabilities we need to manual mode: the `onFeatureFlags` callback (flag-ready state, spec US5), the `beforeSend` callback (defense-in-depth UGC drop-guard, spec FR-004), and session replay/surveys (future). Manual mode also makes the token/host **Dart compile-time values** instead of values baked per-platform into three XML/plist files — one source of truth, trivially absent in dev builds (FR-010).

**Alternatives considered**:
- *Automatic init (token in manifests/plists)*: rejected — no `onFeatureFlags`/`beforeSend`, token duplicated across Android/iOS/macOS files, debug builds would need per-platform manifest tricks to stay out of production data.
- *Not integrating a vendor SDK / hand-rolled HTTP queue*: rejected — spec names PostHog as the vendor choice and the docs explicitly provide the offline queue, batching, and lifecycle autocapture we'd otherwise rebuild and maintain.

## D2. Token/host delivery: compile-time `String.fromEnvironment`, empty = disabled

**Decision**: `lib/core/analytics/analytics_config.dart` reads `POSTHOG_API_KEY` / `POSTHOG_HOST` via `const String.fromEnvironment(...)`. Empty key (the default for `flutter run`/`flutter test`/debug) ⇒ the provider returns a no-op implementation. Release/store builds are assembled with `--dart-define=POSTHOG_API_KEY=… --dart-define=POSTHOG_HOST=https://us.i.posthog.com`. `kDebugMode` additionally forces capture off unless an explicit `POSTHOG_API_KEY` is provided, so a dev running with defines still lands in a designated debug project, never production.

**Rationale**: The repo already uses this exact mechanism for `DISTRIBUTION_CHANNEL` (`lib/core/release/distribution_channel.dart:20`) — it's the established compile-time config precedent. Runtime-editable Drift settings (like the Worker/AI base URLs in the Developer section) were rejected for a **secret**: those URLs are developer-facing debugging affordances; a public analytics token is closer to build configuration and must not appear in a user-editable store.

**Alternatives considered**:
- *Drift-stored base URL + developer settings row*: rejected (mixes a build-time concern into runtime debug config; token would persist on disk in plaintext DB).
- *Hardcoded release token in source*: rejected — debug builds would then need extra logic to avoid production data, and tokens in VCS rotate painfully.

## D3. Windows/Linux (and tokenless/debug) support: structural no-op behind a facade

**Decision**: `Analytics` (interface) + `NoopAnalytics` (null-object) + `PosthogAnalytics` (vendor wrapper). A single Riverpod provider picks the implementation: `analyticsSupported && tokenConfigured && !userOptedOut ⇒ PosthogAnalytics`, else `NoopAnalytics`. `analyticsSupported` = `Platform.isAndroid || Platform.isIOS || Platform.isMacOS` (matches the vendor's supported list exactly; verified: pub.dev lists Android/iOS/macOS/Web, and this app has no web target).

**Rationale**: On Windows/Linux the plugin has **no native implementation** — any call throws `MissingPluginException`. Gating at construction (not per-call try/catch) makes the unsupported-platform guarantee (spec FR-008) structural rather than defensive: no code path can even reach the vendor on those platforms. The same gate absorbs the tokenless/debug case (D2) and races where setup hasn't completed yet.

**Alternatives considered**:
- *Try/catch around every vendor call*: rejected — hides bugs, violates "inert, no errors" (FR-008) with runtime noise instead of by construction.
- *Conditional import per target platform*: rejected — overkill; a runtime `Platform.isX` predicate is testable with plain unit tests, conditional imports are not.

## D4. Opt-out preference: device-global Drift key following the `DiagnosticsVerbose` recipe

**Decision**: New `SettingsKeys.analyticsCaptureEnabled = 'analytics.capture_enabled'` (registered in `_staticKeys`, stored as `'true'/'false'`, default **true**), read/written through `deviceGlobalAppDatabaseProvider` by a `@Riverpod(keepAlive: true)` notifier mirroring `lib/core/diagnostics/diagnostics_verbose_provider.dart`. Toggling off calls `Posthog().disable()` (vendor opt-out; docs: "prevents any future events from being sent"), toggling on calls `Posthog().enable()`.

**Rationale**:
- *Device-global, not per-user*: the analytics identity spans pre-sign-in (anonymous) and post-sign-in (identified) events, and must survive sign-out (a shared device's next user shouldn't silently inherit the previous user's opt-out). The repo already splits `appDatabaseProvider` (per-user) from `deviceGlobalAppDatabaseProvider` (pre-sign-in/device scope) for exactly this class of preference — verbose diagnostics uses the device-global one.
- *Vendor `disable()`/`enable()`* is the documented opt-out path; `isOptedOut()` exists for verification.
- **Open verification item for implementation** (tracked in quickstart SC-004): the docs promise disable stops *future* sends but are silent on the already-queued backlog. The facade will additionally drop Dart-side capture while disabled; if implementation testing shows queued native lifecycle events still flush after `disable()`, the fallback documented here is to set `config.captureApplicationLifecycleEvents = false` and gate all capture behind the preference (acceptable, loses only native lifecycle events), escalating to a vendor issue only if that's still insufficient.

**Alternatives considered**:
- *shared_preferences*: rejected — not a dependency in this app; adding it for one boolean contradicts the Drift key/value store already used for every other preference.
- *Per-user preference (per-user DB)*: rejected — opt-out must cover pre-sign-in anonymous events and survive sign-out (spec FR-007, identity-switch edge case).

## D5. Identity: `identify(UserProfile.id)` on sign-in, `reset()` on sign-out

**Decision**: A keepAlive provider (`analytics_bootstrap.dart`) subscribes to `authCtrlProvider` state:
- `AuthSignedIn(profile)` → `Posthog().identify(userId: profile.id, userProperties: {...})` — **`UserProfile.id` (server-assigned String) is the distinct ID**; email/name go only into person properties, never the ID.
- `AuthSignedOut` (including the path inside `AuthCtrl.signOut()`) → `Posthog().reset()` (docs: clears stored super properties and identity) so the next user's events cannot be attributed to the previous account (spec FR-006).
- No `alias()` calls: the login-only app has no anonymous→known merge problem worth the documented complexity; `identifiedOnly` person profiles (vendor default) keep anonymous events cheap.

**Rationale**: The docs recommend a stable database ID over email (`UserProfile.id` is exactly that), and identify should happen "as soon as you're able to… typically after login". Listening from outside `AuthCtrl` keeps the auth feature untouched (constitution Principle I — no analytics code inside `auth_controller.dart`).

**Alternatives considered**:
- *Identify inside `AuthCtrl.signOut()`/sign-in flow*: rejected — couples the auth feature to analytics; a state listener needs no auth-code changes and is fully unit-testable with the existing `_SignedInAuthCtrl` override pattern (`test/core/application/app_preferences_provider_test.dart`).
- *alias()-based merging*: rejected — unnecessary given identify links prior anonymous events automatically (docs).

## D6. Screen autocapture: `PosthogObserver()` + naming the go_router routes

**Decision**: Add `PosthogObserver()` to the existing observers lists in `lib/core/routing/app_router.dart` (root `GoRouter.observers` and the `ShellRoute.observers`, alongside `rootOverlayObserver`/`shellOverlayObserver`), and add `name:` to `GoRoute` entries that lack one.

**Rationale**: The docs' go_router recipe is exactly `observers: [PosthogObserver()]` + named routes ("Your routes should be named. Otherwise, they won't be recorded"). Adding names has no behavioral side effect on go_router navigation (only enables `goNamed`/debugging) and gives `$screen` events for free on every surface — the cheapest way to satisfy the "which features are used" question (spec SC-006) without instrumenting 20+ screens by hand.

**Alternatives considered**:
- *Manual `screen()` calls per feature*: rejected — high churn, drifts out of date; only reserved for surfaces whose journey events (D7) already carry the context.
- *Skipping screen capture*: rejected — SC-006's "which features are used most" is otherwise underpowered for surfaces without a catalog event.

## D7. Event catalog: snake_case `object_verb` constants in code, mirrored in docs

**Decision**: `lib/core/analytics/analytics_events.dart` exposes typed constants (names + per-event property keys) for the six spec journeys; `contracts/event-catalog.md` is the human/docs source of truth. Naming follows the docs' recommendation (`[object] [verb]`, snake_case): `practice_session_started/completed`, `transcript_generation_requested/completed/failed`, `dictionary_lookup_performed`, `translation_requested`, `craft_project_created`, `vocabulary_review_completed`, `subscription_purchase_started/completed`, `credits_package_purchased`. Common context (display locale, learning language, distribution channel) rides along as super properties registered at init (`Posthog().register(...)`).

**Rationale**: Constants in one file make rename/typo a compile error and give unit tests a single enumeration to verify against the docs page; stringly-typed capture scattered across features is how catalogs rot. Failure reasons are restricted to a closed enum of coarse categories (`network|credits|auth|server|cancelled`) — enough for funnels, structurally incapable of carrying payloads (FR-004).

**Alternatives considered**:
- *Free-form `capture(eventName: '...')` at call sites*: rejected — violates catalog consistency (FR-003) and invites UGC into properties.
- *JSON-defined catalog*: rejected — no runtime need; Dart constants + markdown contract doc is simpler and type-checked.

## D8. Startup wiring: fire-and-forget from `EnjoyApp` init, never on the first-frame path

**Decision**: `_bootstrap()` (lib/main.dart) stays untouched except for kicking an idempotent `analyticsInitProvider` read (via the root widget's first init), which runs `setup()` with the config from D2, applies the stored opt-out (D4), registers super properties, and attaches the auth-sync listener (D5). `setup()` is awaited only against a short internal timeout inside that background future — `runApp` never waits on it.

**Rationale**: Matches the existing startup philosophy in `main.dart` (parallel `Future.wait` for logging/diagnostics config, databases opened lazily via providers). The docs' lifecycle-events caveat ("won't have any special context… by the time it is initialized") is acceptable: Application Opened losing early context costs nothing for our questions. Waiting for `setup()` before `runApp` would put a network-adjacent native call on the first-frame path — the one thing spec FR-009/IV forbid.

**Alternatives considered**:
- *`await setup()` inside `_bootstrap()` before `runApp`*: rejected — startup latency hostage to plugin init (spec FR-009, constitution IV).
- *Init lazily on first capture*: rejected — would drop `Application Opened` entirely and complicate the observer, which needs the client existing at router construction.

## D9. Platform minimums: verify, bump only if below vendor requirements

**Decision**: Implementation must check `android/app/build.gradle` `minSdkVersion ≥ 23` and `ios/Podfile` `platform :ios, '13.0'` (docs requirements), and the macOS Podfile target; bump only if the current value is lower.

**Rationale**: Docs state these minimums for posthog_flutter 5.x. Modern Flutter templates usually already satisfy them, so the task is a verification gate, not a presumed change. macOS uses the same posthog-ios pod; network entitlements are already present in all three `.entitlements` files (verified: `com.apple.security.network.client` enabled), so no entitlement changes are needed.

**Alternatives considered**: None — this is a hard vendor constraint.

## D10. Debug/CI isolation

**Decision**: No token in any committed file. `flutter test` and debug runs get `NoopAnalytics` (D2). PostHog's `debug` flag is set from `kDebugMode` so verbose vendor logs appear only in development. Release verification uses a personal/test PostHog project token passed via `--dart-define` before any production token is wired into release automation.

**Rationale**: FR-010 requires dev builds never report into production data; making "no token ⇒ structurally inert" the default means CI, tests, and every contributor build satisfy it with zero configuration. The docs' recommended pattern is exactly "set debug to true in development environments only using environment variables".

**Alternatives considered**:
- *Separate debug token committed in source*: rejected — still ships a secret in VCS and risks fat-fingering into release builds.

---

## Vendor API surface used (verified against official docs, 2026-09-03)

| Need | API (from `package:posthog_flutter/posthog_flutter.dart`) |
|---|---|
| Init (manual mode) | `PostHogConfig(token)` + `host`, `debug`, `captureApplicationLifecycleEvents` (default true since 5.23.0), `personProfiles` (default `identifiedOnly`), `onFeatureFlags`, `beforeSend`, `maxQueueSize`; `await Posthog().setup(config)` |
| Custom events | `Posthog().capture(eventName:, properties:)` |
| Screen views | `PosthogObserver()` navigator/go_router observer; `$screen`; routes must be named |
| Identity | `Posthog().identify(userId:, userProperties:, userPropertiesSetOnce:)`, `Posthog().reset()`, `Posthog().getDistinctId()` |
| Opt-out | `Posthog().disable()` / `enable()` / `isOptedOut()` |
| Super properties | `Posthog().register(k, v)` / `unregister(k)` |
| Flags | `isFeatureEnabled(key)`, `getFeatureFlag(key)`, `getFeatureFlagPayload(key)`, `reloadFeatureFlags()` |
| Offline queue | File-backed queue, `maxQueueSize` bound (oldest dropped when full), flushed on restart/online |
| Diagnostics | `Posthog().debug()`, `flush()` |
| Out of scope (docs-noted platform limits) | Session replay (Web/Android/iOS only), Surveys (Web/iOS/Android only) — excluded by spec assumptions anyway |
