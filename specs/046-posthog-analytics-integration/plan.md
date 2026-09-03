# Implementation Plan: PostHog Product Analytics Integration

**Branch**: `046-posthog-analytics-integration` | **Date**: 2026-09-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/046-posthog-analytics-integration/spec.md`

## Summary

Integrate PostHog product analytics so the team can measure real app usage (sessions, screens, core learning/purchase journeys) and evaluate remote feature flags, per the official Flutter integration docs. The vendor SDK (`posthog_flutter` ^5.39.0) is initialized **manually** (`AUTO_INIT=false` + `Posthog().setup(config)` from Dart) so the project token/host are compile-time `--dart-define` values, debug builds stay out of production data, and `onFeatureFlags`/`beforeSend` hooks are available. All vendor access is funneled through a small analytics facade in `lib/core/analytics/` that is a complete no-op on Windows/Linux (no vendor support) and when no token is configured, making failures structurally invisible to users. Opt-out is a device-global Drift boolean preference surfaced as a switch in the Settings About section; identity follows `authCtrlProvider` (`identify` with `UserProfile.id`, `reset` on sign-out).

## Technical Context

**Language/Version**: Dart SDK ^3.12.0 (Flutter stable; app version 0.8.5+14)

**Primary Dependencies**: `posthog_flutter: ^5.39.0` (NEW — Android/iOS/macOS native SDKs + Dart facade), flutter_riverpod 3.3.2 + riverpod_generator 4.x (`@Riverpod(keepAlive: true)`, colocated `*.g.dart`), drift 2.34.2 (preference persistence), go_router 17.3.0 (screen autocapture via observer)

**Storage**: New device-global Drift settings key `analytics.capture_enabled` (via `SettingsDao`/`SettingsKeys`, following `diagnostics_verbose_provider.dart`); events themselves live only in the vendor SDK's on-device queue + PostHog cloud (never in `AppDatabase` user data)

**Testing**: `flutter test` (test/ mirrors lib/); in-memory Drift (`NativeDatabase.memory()`) + `ProviderContainer` overrides for pref/auth-sync tests; `TestDefaultBinaryMessengerBinding.setMockMethodCallHandler` to mock the posthog method channel; `bash .github/scripts/validate_ci_gates.sh` before push

**Target Platform**: Android (minSdk ≥ 23 required by vendor), iOS (≥ 13 required by vendor), macOS (App Sandbox `com.apple.security.network.client` already enabled in all 3 entitlements). Windows + Linux: **inert by design** (vendor has no native implementation — calls would throw `MissingPluginException`, hence the platform gate). Web: out of scope (no `web/` directory; constitution excludes it).

**Project Type**: Flutter mobile + desktop application (feature-first architecture, 24 features under `lib/features/`)

**Performance Goals**: Zero added first-frame latency — vendor `setup()` runs fire-and-forget off the startup critical path; every facade call is non-blocking (vendor-internal queue, batched async flush); no new work in `build` methods or list item builders

**Constraints**: No user-generated content in event properties (enforced by facade property types + `beforeSend` drop-guard); no crash/error/block may originate from analytics (all facade calls guarded + logged via `logNamed('analytics')`); opt-out takes effect immediately including queued events; debug builds without a token are fully inert

**Scale/Scope**: 1 new `lib/core/analytics/` capability (~6 files), 1 Drift settings key, 1 Settings toggle row, route names added for `$screen` autocapture, event catalog constants for 6 core journeys, `docs/features/analytics.md` + ADR-0086

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Architecture & Code Quality | ✅ PASS | Shared cross-feature capability → `lib/core/analytics/` (peer of `lib/core/logging`, `lib/core/diagnostics`); all access via Riverpod providers; vendor singleton `Posthog()` is reachable only inside the facade impl — **justification for not wrapping in Riverpod-owned state**: it is the vendor's imposed API shape, hidden behind the `Analytics` interface so no feature code ever touches it. Presentation stays UI-only; no domain-model coupling (events are fire-and-forget side observations, not domain state). |
| II. Testing Defines the Contract | ✅ PASS | Unit tests: facade no-op gating (unsupported platform / missing token / opted-out), pref notifier persistence, auth-sync identify/reset transitions, `beforeSend` UGC guard. Widget test: About-section switch row states. `dart run build_runner build` required (new `@riverpod` providers). |
| III. UX Consistency | ✅ PASS | Toggle reuses `SettingsRow` + `Switch.adaptive` exactly like the existing verbose-diagnostics row in `about_section_card.dart`; strings in `lib/l10n/app_{en,zh,zh_CN}.arb` (`settingsAnalytics*`); no new tappable patterns; Haptics via existing `SettingsRow`. |
| IV. Performance Is a Requirement | ✅ PASS | Startup budget: `setup()` awaited with a short timeout inside a fire-and-forget future — first frame never waits on it; no per-frame analytics work; vendor queue is file-backed with `maxQueueSize` bound. Verification: manual startup comparison + facade unit tests proving no awaiting on hot paths. |
| V. Documentation & Traceability | ✅ PASS | ADR-0086 (`docs/decisions/0086-posthog-product-analytics.md`: third-party vendor choice, capture-defaults-on rationale, platform split) + new `docs/features/analytics.md` (behavior, event catalog, opt-out) + update `docs/features/settings.md` About-section row list. |
| Flutter Quality Gates | ✅ PASS | Verification commands: `dart run build_runner build`, `flutter analyze`, `flutter test`, `bash .github/scripts/validate_ci_gates.sh`; platform compile smoke: Android Gradle build (native SDK added, minSdk bump), `pod install` + build for iOS/macOS. Vendor requires Android minSdk ≥ 23 and iOS ≥ 13 — verify current values, bump only if below. |

**Post-design re-check (after Phase 1)**: Re-verified — the facade + provider design above holds; no new violations. The only boundary note: `lib/core` gains a network-sending capability (like `lib/data/api` but telemetry). Accepted because `lib/core` already hosts device-wide services (`logging` file sink, `diagnostics`), and routing it through `lib/data` would wrongly suggest per-user database scoping — analytics is device-global, not user-scoped.

## Project Structure

### Documentation (this feature)

```text
specs/046-posthog-analytics-integration/
├── plan.md              # This file
├── research.md          # Phase 0 output: vendor setup mode, platform gating, identity, opt-out
├── data-model.md        # Phase 1 output: entities + state transitions
├── quickstart.md        # Phase 1 output: end-to-end validation guide
├── contracts/
│   ├── analytics-facade.md   # The Analytics interface contract + provider wiring
│   └── event-catalog.md      # Event names, properties, common context, naming rules
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
lib/
├── main.dart                        # + fire-and-forget analytics bootstrap kick (existing _bootstrap pattern)
├── app.dart                         # (no change expected beyond observer-free wiring)
├── core/
│   └── analytics/                   # NEW shared capability
│       ├── analytics.dart           # `Analytics` interface + NoopAnalytics
│       ├── analytics_provider.dart  # @Riverpod(keepAlive: true) provider: gate → PostHog impl | no-op
│       ├── analytics_config.dart    # String.fromEnvironment token/host + kDebugMode isolation
│       ├── analytics_bootstrap.dart # setup(config), opt-out apply, auth-sync listener wiring
│       ├── analytics_platform_gate.dart  # supported-platform predicate (Android/iOS/macOS only)
│       ├── analytics_events.dart    # event-name + property constants (the catalog in code)
│       └── posthog_analytics.dart   # vendor wrapper: guarded calls, logNamed('analytics')
├── data/db/
│   ├── settings_keys.dart           # + analytics.capture_enabled (and _staticKeys registration)
│   └── ...                          # SettingsDao unchanged
└── features/
    ├── auth/application/
    │   └── auth_controller.dart     # (no change — auth-sync listens to authCtrlProvider from outside)
    └── settings/presentation/widgets/
        ├── about_section_card.dart  # + "Usage analytics" Switch.adaptive row (next to verbose diagnostics)
        └── ...                      # registry/localizer/ARB entries for the new row

android/app/src/main/AndroidManifest.xml   # + com.posthog.posthog.AUTO_INIT=false
ios/Runner/Info.plist                      # + com.posthog.posthog.AUTO_INIT=false
macos/Runner/Info.plist                    # + com.posthog.posthog.AUTO_INIT=false
core/routing/app_router.dart               # + route names + PosthogObserver() in observers lists

docs/
├── decisions/0086-posthog-product-analytics.md   # NEW ADR
└── features/analytics.md                          # NEW feature page

test/
├── core/analytics/                  # facade gating, config isolation, auth-sync, beforeSend guard
└── features/settings/presentation/  # About-section analytics toggle row

pubspec.yaml                         # + posthog_flutter: ^5.39.0
```

**Structure Decision**: Single Flutter app (existing layout, no new packages/directories beyond `lib/core/analytics/`). The feature is a cross-cutting capability, so it lives in `lib/core/` per constitution Principle I; feature surfaces are touched only where behavior already exists (Settings toggle row, router observers, auth state listener). Existing conventions reused: device-global Drift boolean pref (`diagnostics_verbose_provider.dart` recipe), `String.fromEnvironment` config (`distribution_channel.dart` precedent), `TestDefaultBinaryMessengerBinding` channel mocks.

## Complexity Tracking

> No constitution violations require justification. Two design notes recorded inline in the Constitution Check: (1) vendor singleton hidden behind the facade interface; (2) `lib/core/analytics` as a network-sending device-global service, matching the precedent of `lib/core/logging`/`lib/core/diagnostics`.
