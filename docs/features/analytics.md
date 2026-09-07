# Feature: Product analytics (PostHog)

## Summary

Enjoy Player ships opt-out-able product analytics via [PostHog](https://posthog.com) (spec [`specs/046-posthog-analytics-integration/`](../specs/046-posthog-analytics-integration/spec.md), [ADR-0086](../decisions/0086-posthog-product-analytics.md)). Capture is **on by default** with a visible switch in Settings → About → *Usage analytics*. All vendor access is confined to `lib/core/analytics/`; feature code uses the `Analytics` facade only and never imports `package:posthog_flutter`.

## Platform & build behavior

| Platform | Behavior |
|---|---|
| Android, iOS, macOS | Full capture (sessions, screens, journey events, flags) |
| Windows, Linux | Completely inert — the vendor has no native SDK there; the provider resolves a no-op before any vendor call exists |

The PostHog project key and host are compile-time values:

```bash
flutter run \
  --dart-define=POSTHOG_API_KEY=<ph_project_token> \
  --dart-define=POSTHOG_HOST=https://eu.i.posthog.com
```

No defines ⇒ no capture at all — `flutter test`, plain `flutter run`, and CI builds are inert by construction and can never pollute production data. Debug builds only capture when someone deliberately passes a (test-project) token.

Release builds get the defines automatically: the `release_*.yml` workflows inject the `POSTHOG_API_KEY` / `POSTHOG_HOST` secrets into the release scripts' env, and the scripts forward any set values as `--dart-define` (see `release_append_posthog_defines` in `.github/scripts/release_lib.sh`). Locally, export both in the shell or in `publish_env.local.sh` (see `publish_env.example.sh`) before running `release.sh`. Both values are required — a half-set config warns and ships inert.

Init is manual (`AUTO_INIT=false` in each platform manifest + `Posthog().setup()` from Dart, fired off the startup critical path in `EnjoyApp`), which is also what unlocks `onFeatureFlags` and the `beforeSend` guard.

## Identity

- Events attribute to the signed-in account's **`UserProfile.id`** (never the email — the email rides as a person property).
- Sign-out calls `reset()` so a shared device's next user is never attributed to the previous account.
- Common context registered once: `display_locale`, `learning_language`, `distribution_channel` (plus the vendor's own app-version/OS/session properties).

## Opt-out

Settings → About → **Usage analytics** (`Switch.adaptive`). Persisted as the device-global Drift key `analytics.capture_enabled` (missing ≡ on). Toggling off stops all capture immediately and survives restart; toggling on resumes in-session. The preference lives in `lib/core/analytics/analytics_capture_pref.dart`; the analytics provider applies it to the vendor, so the preference is the single source of truth.

## Event catalog

Source of truth: [`specs/046-posthog-analytics-integration/contracts/event-catalog.md`](../specs/046-posthog-analytics-integration/contracts/event-catalog.md); code constants in `lib/core/analytics/analytics_events.dart` (a unit test keeps the two in sync). Journeys covered: practice (shadow reading / word practice / flashcard), transcript generation (ASR / YouTube refresh / subtitle import), dictionary lookup, translation (standard + contextual), craft creation, vocabulary review completion, subscription and credits purchases.

House rules:

1. New events/properties extend the contract doc **and** `analytics_events.dart` in the same change.
2. Property values are coarse tags/ints only — never user-generated content. The facade's `beforeSend` guard drops any event outside the catalog or with a non-allowlisted property.
3. `$screen` events come from named routes in `lib/core/routing/app_router.dart` via `AnalyticsScreenObserver` (root + shell navigators).

## Feature flags

`Analytics.flag(key: ..., fallback: ...)` evaluates remote flags with a **required** built-in fallback (returned whenever analytics is unavailable, opted out, errored, or slow). No shipped behavior is gated behind a flag yet — this is capability-only groundwork.

## Verification

See [`specs/046-posthog-analytics-integration/quickstart.md`](../specs/046-posthog-analytics-integration/quickstart.md) for end-to-end scenarios. Unit coverage lives in `test/core/analytics/` (gating, guard, identity, opt-out, flags, failure mapping) and `test/features/settings/presentation/widgets/analytics_capture_toggle_row_test.dart` (the toggle).
