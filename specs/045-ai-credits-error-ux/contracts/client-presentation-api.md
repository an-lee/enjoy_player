# Contract: Client Presentation API (internal, cross-module)

The single seam every surface uses to present a credits-exhausted failure. Lives in `lib/features/subscription/presentation/credits_failure_actions.dart` (route knowledge stays inside the subscription feature, constitution I).

## Classification (unchanged location, changed rule)

`mapApiExceptionToAppFailure(ApiException e)` — `lib/features/ai/application/ai_api_failures.dart`, plus the repo mappers in `credits/` and `subscription/`:

| Input | Output |
|---|---|
| `statusCode == 402 && !e.byokProvider` | `CreditsFailure.fromApiException(e)` (envelope fields best-effort) |
| `statusCode == 402 && e.byokProvider` | `ProviderBillingFailure` — **no Enjoy CTA ever** (FR-008) |
| `statusCode == 401` | `AuthFailure(sessionRevoked)` (unchanged) |
| anything else | `NetworkFailure` (unchanged) |

`ApiException.byokProvider: bool` (default false) is set only by `throwByokHttpError` (`lib/features/ai/data/byok/byok_http_client.dart`).

## Presentation functions

```text
creditsFailureMessage(CreditsFailure failure, AppLocalizations l10n) → String
  - Envelope present: localized "<needs {required} credits>, {remaining} left today. Credits reset {time}."
    (new ARB keys creditsExhaustedDetailed / creditsExhaustedResets, placeholders; time via app intl formatting)
  - Envelope absent: l10n.subscriptionCreditsLimitMessageWithPackages (existing key, unchanged copy)
  - NEVER returns failure.message or any server/raw text

showCreditsFailureNotice(BuildContext context, CreditsFailure failure) → void
  - AppNotice.error(context, creditsFailureMessage(...), action: SnackBarAction(
      label: l10n.subscriptionViewPlansAndPackages,   // single CTA label everywhere
      onPressed: () => context.push('/subscription'), // single destination everywhere
    ))
  - Replaces/absorbs showCreditsFailureWithUpgradeAction (its test moves with it)

creditsCtaLabel(AppLocalizations l10n) → String
  - l10n.subscriptionViewPlansAndPackages — inline idioms (section rows, cards, sheets) use this
    with the same /subscription destination
```

### Idiom mapping (how each surface type consumes the contract)

| Idiom | Consumption |
|---|---|
| Transient snackbar | `showCreditsFailureNotice` (AppNotice error/warning's existing `clearSnackBars()` guarantees one-at-a-time — FR-006) |
| Inline section row (lookup sheet) | Existing error row pattern + `TextButton(creditsCtaLabel, → /subscription)` + `creditsFailureMessage` body |
| Card with actions (Craft `CraftFailureCard`) | Credits message + View plans action next to the existing Retry action |
| Controller state enum (ASR, auto-translate, assessment, vocabulary tokens) | State carries the failure kind/envelope; render site calls `creditsFailureMessage` and renders the idiom's CTA |
| Purchase-path failures (subscription/credits screens) | Same builder at their existing error slots (FR-010) |

## Non-goals / invariants

- `ProviderBillingFailure` renders as generic failure text (`byokProviderBillingMessage`) with **no** subscription CTA and no `/subscription` navigation.
- Severity stays per-surface (pronounce keeps `AppNotice.warning`; others error) — only message + CTA are unified.
- AI playground (`lib/features/ai/presentation/ai_playground_screen.dart`) is exempt: internal diagnostics keep raw output (documented exception to FR-004).
- No new widget classes in core; no new global error channel; no changes to non-402 failure rendering.
