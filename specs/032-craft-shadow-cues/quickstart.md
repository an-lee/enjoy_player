# Quickstart: Craft Shadow-Friendly Transcript Cues

**Feature**: `032-craft-shadow-cues` | **Date**: 2026-07-30

Runnable validation scenarios that prove the feature works end-to-end. These are manual/device validation paths — the automated unit/widget tests live in `tasks.md`. See [data-model.md](data-model.md) for the entity rules and [contracts/azure-speech-word-boundaries.md](contracts/azure-speech-word-boundaries.md) for the method-channel shape.

---

## Prerequisites

- Dev environment set up per `README.md` (Flutter, platform SDKs).
- `bash .github/scripts/validate_ci_gates.sh` passes before starting.
- For device scenarios: an iOS or macOS device/simulator with network access (Enjoy default TTS needs the worker token).
- For segmentation-only scenarios: any platform — the segmenter is pure Dart and unit-tested headlessly.

---

## Scenario A — Unit-test the segmenter (headless, all platforms)

Validates FR-003 through FR-008, FR-011, FR-013 without a device.

**Setup**: none beyond the repo.

**Run**:
```bash
flutter test test/features/craft/domain/word_boundary_segmenter_test.dart
```

**Expected**: all segmenter tests pass. The updated test suite asserts:
- Empty / punctuation-only input → `null` (blank-transcript gate, FR-011).
- Standalone punctuation tokens never start a line (FR-007).
- Long multi-clause sentences split into lines within the 1.2–7.0 s window (FR-003); no line exceeds the hard max.
- Splits prefer clause punctuation / largest silence gap over arbitrary word count (FR-004, FR-005).
- CJK input breaks at full-width clause marks `、，；：` and sentence marks `。！？`, never by word count (FR-006).
- Line `start` = first boundary onset; `duration` = last release − start (FR-008).
- Output JSON is `[{text, start, duration}]` (FR-013).

**Pass criterion**: green suite.

---

## Scenario B — Apple device: timed cues on save (iOS / macOS)

Validates FR-001, FR-002, User Story 1, SC-001.

**Setup**: run the app on an iOS or macOS device/simulator, signed in with an Enjoy account (default TTS path).

**Steps**:
1. Open Craft (Home → Craft, or press `c`).
2. In Advanced mode, paste a multi-sentence paragraph (≥2 sentences, ≥12 words) in a supported language.
3. Synthesize → **Save & practice**.
4. In the player, open the transcript panel.

**Expected**:
- Transcript panel shows **multiple timed lines** (not the empty/generate state).
- Lines highlight in sync with playback as the words are spoken.
- Audio plays normally.

**Pass criterion (SC-001)**: on a set of ≥10 multi-sentence samples, 100% of saves produce a non-blank primary timed transcript on iOS and macOS (versus 0% before).

**Fallback check (FR-002)**: if a particular sample returns zero boundaries (rare SDK edge), the item still saves successfully and the player shows the empty/generate state — not a save failure.

---

## Scenario C — Shadow-friendly line sizing (any platform with boundaries)

Validates FR-003, FR-004, User Story 2, SC-002.

**Setup**: run on Android, Windows, iOS, or macOS with Enjoy default TTS.

**Steps**:
1. Craft a paragraph containing **one long multi-clause sentence** (e.g. "I went to the store, bought some milk, came back home, and then realized I forgot the eggs, so I had to go out again.") and **one short sentence** ("It was a long morning.").
2. Synthesize → save → open the transcript.

**Expected**:
- The long sentence is split into ≥2 lines, each within the ~1.5–6 s target window; none exceeds the ~7 s hard cap.
- The short sentence stays as **one** line (not fragmented).
- Splits land at clause marks (commas) or natural pauses, not mid-phrase.

**Pass criterion (SC-002)**: on ≥10 samples with long sentences, ≥90% of lines fall within the shadow-friendly duration range.

---

## Scenario D — Clause + CJK punctuation breaks

Validates FR-005, FR-006, User Story 3, SC-003, SC-004.

**Latin clause test**:
1. Craft text with commas / semicolons / em-dashes marking clauses.
2. Save → verify within-sentence splits occur at those clause marks when within the window.

**CJK test**:
1. Craft a Chinese or Japanese paragraph with full-width clause punctuation (e.g. `私は朝起きて、コーヒーを飲んで、それから仕事に行きました。` or `今天早上，我去了商店，买了牛奶，然后回家了。`).
2. Save → verify lines break at the full-width commas `、`/`，`, not by a Latin word-count rule.

**Pass criterion (SC-003)**: on ≥5 samples with clause punctuation (Latin + CJK), ≥80% of within-sentence splits occur at a clause mark or largest pause. **SC-004**: 100% of lines have non-empty text not starting with `.,;:!?。、，；：！？`.

---

## Scenario E — No-regression on platforms that keep blank transcripts

Validates FR-002 (fallback), out-of-scope boundaries (BYOK OpenAI, Linux).

**BYOK OpenAI TTS**:
1. Configure BYOK with an OpenAI key (no Azure subscription key).
2. Craft and save a paragraph.
3. Open in player → transcript should be **blank** (empty/generate state), audio playable. Generate-via-STT remains available.

**Linux** (no native TTS plugin):
1. On Linux, Craft and save.
2. Open in player → blank transcript, audio playable, Generate affordance present.

**Pass criterion**: these paths are unchanged — no fabricated cues, no save failure.

---

## Scenario F — Save latency no-regression

Validates SC-006.

**Steps**:
1. Time a Craft save (synthesize → save) for a typical short paragraph (< 500 chars) on the current `main` build.
2. Apply the feature; time the same save on the same device class.

**Pass criterion (SC-006)**: wall-time regression ≤ 10%. Segmentation is pure-Dart over a short boundary list; native word-boundary capture add only event-append overhead during an already-blocking synthesis.

---

## Scenario G — Re-synthesize / edit no-regression

Validates the Edge Case "re-synthesize with a different voice."

**Steps**:
1. Craft and save an item.
2. Open from Craft history (edit), change the voice, re-synthesize, save again.

**Expected**: the transcript rebuilds from the new word boundaries using the improved segmentation; the same media id is updated (no duplicate). If the new save somehow lacks solid timings, the prior transcript is cleared (blank policy).

---

## What is NOT validated here

- **Forced alignment quality** — out of scope (FR-012); this feature relies solely on synthesis word boundaries.
- **Echo-mode interaction** — unchanged; echo simply consumes the improved cues.
- **Schema migration** — none required (FR-013); `primaryTimelineJson` is already nullable.

Full task-level implementation and test breakdown belongs in `tasks.md` (`/speckit.tasks`).
