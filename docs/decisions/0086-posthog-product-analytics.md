# ADR-0086: PostHog product analytics integration

- Status: Accepted
- Date: 2026-09-03
- Spec: `specs/046-posthog-analytics-integration/`
- Related: ADR-0031 (login-only access), ADR-0048 (Linux first-class), spec 045 (credits errors)

## Context

The team has no product telemetry: we cannot answer "how many people use the app, on which platforms, which features, where do they drop off" without asking. The spec (046) chose PostHog per the official Flutter integration docs. The app ships Android, iOS, macOS, Windows, and Linux; the vendor's Flutter SDK has native implementations for Android, iOS, and macOS only.

## Decision

1. **Vendor**: PostHog cloud (`posthog_flutter` ^5.39.0), initialized **manually** — `com.posthog.posthog.AUTO_INIT=false` in each platform manifest, with `Posthog().setup(config)` driven from Dart. Manual init unlocks the `onFeatureFlags` and `beforeSend` hooks and makes the project key a compile-time `--dart-define` (`POSTHOG_API_KEY` / `POSTHOG_HOST`), so tokenless builds (dev, test, CI) are **structurally inert** and never report into production data.
2. **Architecture**: all vendor access is confined to `lib/core/analytics/` behind an `Analytics` facade. A Riverpod provider resolves either the PostHog implementation or a no-op null object; feature code never imports `package:posthog_flutter`. On Windows/Linux (no vendor implementation) the provider never constructs the vendor path — inertness is by construction, not try/catch.
3. **Identity**: events attribute to `UserProfile.id` after sign-in (`identify`), with `reset()` on sign-out. The email is never the distinct ID. Auth sync listens to `authCtrlProvider` from `lib/core/analytics` — the auth feature carries no analytics code.
4. **Opt-out**: capture defaults **ON** with a visible opt-out switch in Settings → About (`analytics.capture_enabled`, device-global Drift key). Disabling stops capture immediately, persists across restarts, and resumes in-session on re-enable. Device-global scope means the choice covers anonymous pre-sign-in events and survives sign-out. Capture-on-by-default (rather than opt-in) follows the industry-standard posture for product analytics in a login-only app and is the one deliberately debatable choice in this ADR.
5. **Payloads**: a closed event catalog (see `specs/046-posthog-analytics-integration/contracts/event-catalog.md`) enforced in code — typed constants, allowlisted property keys, coarse failure enums — plus a vendor `beforeSend` guard that drops any event outside the catalog or carrying a non-allowlisted property. User-generated content (media, transcripts, notes, prompts, lookups) can never leave the device through this pipeline.
6. **Platform split**: Android, iOS, and macOS capture; Windows and Linux stay byte-for-byte inert (no capture, no errors, no build impact). The macOS `pod install` build must be verified on Apple hardware before release (posthog-ios deployment target vs our `platform :osx, '10.15'`).

## Consequences

- The team gets real usage, retention, funnel, and adoption data with no further engineering; feature flags are available for future gradual rollouts (nothing is gated yet).
- New releases must pass `--dart-define` values at build time to enable telemetry; omitting them silently ships an inert build (safe default, easy to verify in PostHog's Activity feed).
- Residual risk (tracked in spec research D4 / task T037): whether the vendor's `disable()` also withholds the queued backlog. Implementation testing showed captures are additionally gated behind the stored preference in the facade, so only native-side lifecycle events could theoretically be in flight; verify on-device and revisit this ADR if the behavior is unacceptable.
