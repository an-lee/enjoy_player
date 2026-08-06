# Contract C1: Tip catalog

## Purpose

Define stable tip identities and sequences so new tips are additive (FR-011) without rewriting hosts.

## Tip ids (v1)

| Tip id | Sequence | Progress scope | Target surface |
|--------|----------|----------------|----------------|
| `home.import` | `home.entries` | global | Home Import button |
| `home.craft` | `home.entries` | global | Home Craft button |
| `player.empty_transcript.local` | `player.empty_transcript` | per `mediaId` | **One** primary local control: **Extract** when `showExtractButton` is true; otherwise **Add subtitle**. Generate stays in the empty state but is **not** a showcase step in v1 |
| `player.empty_transcript.youtube` | `player.empty_transcript` | per `mediaId` | YouTube **Fetch transcript** CTA (new) |
| `player.echo` | `player.practice` | global | Transport echo toggle |
| `player.record` | `player.practice` | global | Shadow record control |
| `player.assess` | `player.practice` | global | Recording assessment control |

## Sequence start order

| Sequence | Order |
|----------|-------|
| `home.entries` | `home.import` → `home.craft` |
| `player.empty_transcript` | Single tip: local **or** youtube variant by media type |
| `player.practice` | `player.echo` → `player.record` → `player.assess` (each gated; same-visit chain allowed) |

## Localization

Each tip exposes ARB keys (names illustrative; finalize in implementation):

- `onboardingTipHomeImportTitle` / `onboardingTipHomeImportBody`
- `onboardingTipHomeCraftTitle` / `onboardingTipHomeCraftBody`
- `onboardingTipEmptyTranscriptLocalTitle` / `Body`
- `onboardingTipEmptyTranscriptYoutubeTitle` / `Body`
- `onboardingTipEchoTitle` / `Body`
- `onboardingTipRecordTitle` / `Body`
- `onboardingTipAssessTitle` / `Body`
- Shared: `onboardingTipNext`, `onboardingTipSkip` (or package defaults styled via theme)

Tooltip UI strings must go through `flutter gen-l10n` ARBs (`app_en.arb`, `app_zh.arb`, `app_zh_CN.arb`).

## Eligibility (summary)

| Tip | Eligible when |
|-----|----------------|
| Home tips | Route Home; targets mounted; tip pending; no blocking overlay; home sequence not already resolved |
| Empty local | Player; `!isYoutube`; `!hasTranscript`; media progress pending; primary Extract or Add-subtitle control mounted |
| Empty youtube | Player; `isYoutube`; `!hasTranscript`; media progress pending; fetch CTA mounted |
| Echo | `hasTranscript`; echo tip pending; echo control mounted; empty-transcript not competing |
| Record | Echo tip resolved; record tip pending; `recordUiReady` |
| Assess | Record tip resolved; assess tip pending; `assessUiReady` |

Exact boolean helpers live in `TipEligibility` (unit-tested). See [data-model.md](../data-model.md).

## Non-goals

- Server-driven catalog
- Tips for Discover, vocabulary, Craft Studio internals, keyboard shortcut tour (v1)
