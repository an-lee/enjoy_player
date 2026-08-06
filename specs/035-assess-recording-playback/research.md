# Research: Assessment Recording Playback

**Feature**: `035-assess-recording-playback` | **Date**: 2026-08-06

## Decisions

### 1. Playback engine for full take and word clips

**Decision**: Extend the existing `RecordingPreviewPlayer` (`lib/core/audio/recording_preview_player.dart`) — the ADR-0003-allowed second `media_kit` `Player` for shadow take previews. Add `seek` and clip playback (`playClip(path, start, end)` or equivalent: open/seek/play until end position then stop).

**Rationale**: Assessment results must not replace lesson media (`PlayerController`). Model pronounce already uses `audioplayers` and must not own take WAVs. Preview player already plays take `localPath` from the shadow panel; result surface should reuse the same singleton so toolbar preview and result never fight with two engines.

**Alternatives considered**:
- New third `media_kit` `Player` in the dialog → violates AGENTS / ADR-0003 spirit; rejected.
- Route takes through `PlayerController` → stomps lesson media; rejected.
- Play clips via `audioplayers` → second stack for local WAV, duplicate lifecycle; rejected when preview already exists.

### 2. Timestamp units

**Decision**: Treat `AzureWordAssessment.offset` / `.duration` as **Azure 100-nanosecond ticks**. Convert with `ms = (ticks / 10000).round()` in a pure helper. Do **not** reuse Craft/TTS `audioOffsetMs` fields without conversion — those pipelines already convert at the native boundary.

**Rationale**: `packages/azure_speech` stores raw ticks via `_azureJsonIntTick`; fixtures use `Duration: 10000000` for 1s. Wrong unit would desync karaoke/clips by 10 000×.

**Alternatives considered**:
- Assume ms already → incorrect against current models; rejected.
- Change azure_speech to store ms → wider blast radius; out of scope for this feature.

### 3. Usable word clip / karaoke eligibility

**Decision**: A word is clip/karaoke-eligible when `durationTicks > 0`, error type is not an omission that has no audio interval (treat `errorType == 'Omission'` or zero duration as unavailable), and take `localPath` exists. Karaoke current index = first eligible word where `startMs <= positionMs < endMs` (or last started if gaps); if none, no current highlight.

**Rationale**: Spec requires no invented timings for omissions/missing data.

### 4. Pass recording path into result UI

**Decision**: Add optional `recordingPath` (and keep scores usable when null/missing file) to `showAssessmentResultDialog` / dialog / sheet. `recording_assessment_flow.dart` passes `row.localPath` for both stored-JSON reopen and fresh success.

**Rationale**: Today the dialog only receives `assessment` + `localeTag`; without path, FR-001/FR-006 are impossible.

### 5. Audio mutual exclusion

**Decision**: On the assessment result surface:
- Start full take or word clip → `PronouncePlaybackController.stop()`
- Start model pronounce → stop preview (full/clip)
- Chip select → stop full take (spec assumption) + stop previous clip/model for old word
- Dismiss/dispose → stop preview + pronounce

Wire stop-before-pronounce either in the result’s wrap around `PronounceIconButton` or a small shared hook; prefer explicit stop in result presentation to avoid changing lookup/flashcard surfaces unless a tiny shared helper is cleaner.

**Rationale**: FR-008 / SC-004; today pronounce and preview do not stop each other.

### 6. Karaoke UX scope

**Decision**: Karaoke highlight only while **full-take** mode is playing. Chip tap opens word detail and **stops** full-take (per spec Assumptions). No seek-by-tap in v1.

**Rationale**: Avoid competing highlight vs A/B detail focus; matches locked product default.

### 7. Documentation / ADR

**Decision**: Update `docs/features/shadow-reading.md`. Cite ADR-0003 for preview player; new ADR only if we introduce a broader “assessment audio session” coordinator beyond stop coordination. Prefer documenting mutex in feature contracts first.

## Resolved unknowns

| Topic | Resolution |
|-------|------------|
| Dialog has no path | Thread `recordingPath` from `RecordingRow.localPath` |
| Preview lacks seek/clip | Add APIs on `RecordingPreviewPlayer` |
| Tick vs ms | Convert ticks/10000 → ms |
| Normalized WAV for Azure vs stored path | Timestamps from Azure align with audio sent to assess; product persists/uses `localPath` for preview today — verify in quickstart; if normalize temp was deleted, clips use same path as toolbar preview (status quo) |
| Shared preview with toolbar | Same provider: opening result play replaces toolbar preview; dismiss stops |

## Open risks (implementation / QA, not blockers)

1. Seek precision on short words on some desktop backends — accept Azure interval; disable if duration rounds to 0 ms.
2. Position stream frequency may skip tiny words — highlight may jump; still acceptable for SC-002 subjective sync.
3. Widget tests may need fakes for `RecordingPreviewPlayer` if native media_kit is heavy in CI.
