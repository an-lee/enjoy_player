# Quickstart: Validating the PostHog Integration

**Feature**: `046-posthog-analytics-integration` | **Date**: 2026-09-03
Validation scenarios mapping to spec Success Criteria (SC-001…SC-006). Prereqs once: a PostHog project (a personal/test project first, per research D10) with its **project API key** and host (`https://us.i.posthog.com` or `https://eu.i.posthog.com`).

## Prerequisites & setup

```bash
# Toolchain gates (constitution: run before push)
dart run build_runner build        # new @riverpod providers → *.g.dart (must be committed)
flutter analyze
flutter test
bash .github/scripts/validate_ci_gates.sh

# Run with analytics enabled (dev-safe: point POSTHOG_* at the TEST project)
flutter run -d <device> \
  --dart-define=POSTHOG_API_KEY=<test_project_api_key> \
  --dart-define=POSTHOG_HOST=https://eu.i.posthog.com

# Run without defines (must be fully inert)
flutter run -d <device>
```

## Scenario 1 — Session capture from first launch (SC-001) → US1

1. Fresh install of the defines-enabled build on Android (or iOS/macOS); open the app, sign in, browse for ~1 minute.
2. **Expected**: `Application Opened` (and on later foregrounds, `Application Backgrounded`/`Opened`) appears in PostHog → Activity within ~2 minutes of launch; `$screen` events appear for each named route visited.
3. **Expected**: the same run without `--dart-define` produces **zero** PostHog network calls (verify in verbose logs: single init info line, no vendor activity) and identical app behavior.

## Scenario 2 — Account attribution & switching (SC-002 identity part) → US2

1. Sign in as account A; generate one event (e.g. run a dictionary lookup).
2. **Expected**: Activity shows the event under person `A` with `UserProfile.id` as the distinct ID — **not** an email — and person properties include email/name only as properties.
3. Sign out, sign in as account B, trigger one event.
4. **Expected**: the event attributes to person `B`; person `A` gains no events after the sign-out; reinstall + sign-in as A continues person `A`'s history.

## Scenario 3 — Journey catalog fires exactly once (SC-002) → US3

Walk each journey once and check Activity (names/properties per [event-catalog.md](contracts/event-catalog.md)):

- Practice: start & finish a shadow-reading session → `practice_session_started` + `practice_session_completed` (duration/items present).
- Transcript: generate a transcript → `transcript_generation_requested` → `completed` (or `failed` with `reason`).
- Lookup/translation: one dictionary lookup; one translation.
- Craft: create a project from text; finish one practice run.
- Vocabulary: finish one due-review session.
- Purchase: start checkout (cancel) → `subscription_purchase_started` only; a test purchase or a server-staged completion → `..._completed`.

**Expected**: exactly one well-named event per occurrence; duplicate triggers produce duplicate *legitimate* events, never stacked dupes for one action; every event carries the common context properties; no property value anywhere contains media names, transcript text, or prompts.

## Scenario 4 — Opt-out is immediate and durable (SC-004) → US4

1. Settings → About → toggle **Usage analytics** off (localized label; check zh + en).
2. Use the app for a minute (navigate, trigger a lookup).
3. **Expected**: zero new events in Activity from that device; the toggle persists across app restart; toggling back on resumes capture within the same session. (This scenario also settles research D4's open item: confirm no queued backlog from step 2 arrives after opt-out.)

## Scenario 5 — Windows/Linux inert (SC-005) → FR-008

```bash
flutter run -d linux   # and windows, if available — with and without defines
```

**Expected**: identical behavior both ways; app starts normally, no errors/warnings from analytics in logs, no outbound PostHog traffic (check with your usual proxy/logs), memory/startup indistinguishable by manual comparison. `Analytics` provider resolves to `NoopAnalytics`.

## Scenario 6 — Flags evaluate with safe fallback (SC-006 capability part, FR-011) → US5

1. In the test PostHog project, define flag `test_flag` = ON for the signed-in test user.
2. From a debug-only readout (Developer section or a temporary log line via `analytics.flag(key: 'test_flag', fallback: false)`): **Expected** `true` after `onFeatureFlags` loads; flipping the flag remotely and calling `reloadFeatureFlags` (or restarting) flips the readout without an app update.
3. Kill network, restart the app, read the flag: **Expected** instant `fallback` (no hang), and app startup unaffected.
4. Repeat step 2's readout build on Linux: **Expected** `fallback` always, no errors.

## Final gate (SC-003, SC-006)

- Startup comparison: cold-start the defines build vs. no-define build; first meaningful frame indistinguishable (no added wait — verify no `setup()` await on the startup path in code review).
- In the test PostHog project, build one insight: weekly active users by OS + a trend of `practice_session_completed`. If those two views answer from captured data alone, SC-006's "no additional engineering" holds.

## Platform compile smoke (Flutter Quality Gates)

```bash
flutter build apk --debug          # Android: minSdk ≥ 23 check (research D9)
cd ios && pod install && cd .. && flutter build ios --no-codesign   # iOS ≥ 13
cd macos && pod install && cd .. && flutter build macos             # macOS (network entitlement already present)
```
