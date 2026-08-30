# Quickstart: Validate Friendly AI Credits-Exhausted Errors (045)

Runnable validation for the finished feature. Implementation details live in tasks.md; contract references: [worker-402-envelope.md](contracts/worker-402-envelope.md), [client-presentation-api.md](contracts/client-presentation-api.md), [data-model.md](data-model.md).

## Prerequisites

- Flutter SDK as pinned by the repo; device/desktop target running.
- A **free-tier test account with burned credits** (easiest: run one ~20s shadow-read assessment — 50 credits/sec exhausts the 1,000/day pool in one attempt), or any account whose remaining daily credits are below a single request's cost.
- Alternative to a second exhausted account: temporarily run with a stubbed `ApiClient` (project pattern: `http/testing.dart` `MockClient` returning a canned 402 envelope — see `test/data/api/services/ai/pronounce_api_test.dart`).

## Automated validation (commands)

```bash
flutter analyze                       # zero new issues
flutter test                          # full suite green
# targeted during development:
flutter test test/core/errors/ test/features/subscription/presentation/credits_failure_actions_test.dart
flutter test test/features/lookup/presentation/sections/
flutter test test/features/asr/application/asr_generation_controller_test.dart test/features/shadow_reading/
bash .github/scripts/validate_ci_gates.sh   # format + codegen drift, before push
```

Key automated scenarios (unit + widget, per existing harness conventions):
1. Envelope parser: full body → numbers attached; missing/garbage body → nulls + generic fallback; never throws.
2. Classification matrix: Enjoy 402 → `CreditsFailure` (+fields); BYOK 402 (`byokProvider`) → `ProviderBillingFailure`; 401/5xx/network unchanged.
3. Snackbar: numbered message rendered; CTA tap navigates to `/subscription` (GoRouter harness as in existing `credits_failure_actions_test`).
4. Per-surface widget tests: dictionary/translation/contextual sections, pronounce action, craft failure card credits kind, vocabulary tab, ASR launcher action, assessment controller `credits` kind.

## Manual end-to-end checklist

With the exhausted account, trigger each surface and verify **message + CTA + recovery**:

| # | Action | Expected |
|---|---|---|
| 1 | Player → select word → Dictionary tab | Inline error: "needs X credits, Y left today" style message + **View plans & packages** button → opens `/subscription` |
| 2 | Lookup sheet → Translation tab | Same pattern as #1 |
| 3 | Lookup sheet → Contextual translation tab | Same pattern (new branch — previously raw `HTTP 402`) |
| 4 | Tap pronounce (🔊) icon anywhere | Warning snackbar with credits message + **action** → `/subscription` |
| 5 | Subtitles → auto-translate toggle | Blocked row: credits message + View plans button; translated-so-far lines kept |
| 6 | Local file → Generate transcript | Error snackbar with credits message + action; regenerate works after purchase |
| 7 | Shadow reading → record ~5s → assess | Credits message + CTA (previously "Couldn't run assessment: HTTP 402"); recording kept, assess again after purchase |
| 8 | Craft express: record → transcribe | Failure card: credits message + View plans alongside Retry; audio kept |
| 9 | Craft: translate / rewrite / synthesize | Same as #8 per stage |
| 10 | Vocabulary review → dictionary tab / contextual tab | Credits message + CTA (previously misleading "check network" text) |
| 11 | Subscription screen → attempt purchase with insufficient balance (if reachable) | Friendly credits error, no raw code (FR-010) |

Recovery loop (FR-007): after #1 or #7, buy the smallest package or subscribe on `/subscription`, return to the surface — prior state intact, retry succeeds without re-entry or app restart.

## Negative / regression checks

- **BYOK**: configure an AI provider (Settings → AI providers) whose key returns 402 (e.g. spend-capped OpenRouter key). Trigger translation → provider-billing message, **no** "View plans & packages" CTA, no `/subscription` push (FR-008).
- **Non-402 unchanged**: airplane mode → lookup/translate/ASR show the same network messages as before this feature; sign out → auth prompts unchanged; server 5xx → existing generic errors.
- **No stacking**: spam the pronounce icon 5× while exhausted → one snackbar replaces the previous (never a queue pile-up) (FR-006).
- **Locales**: switch app language to 中文/简体中文 → message, numbers, reset time, and CTA fully localized (all three ARBs).
- **No raw leak**: none of the surfaces in the table shows the strings `HTTP 402`, `credits_exhausted`, or server English copy.
