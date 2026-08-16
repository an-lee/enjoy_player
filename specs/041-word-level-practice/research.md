# Research: Word-Level Practice

**Feature**: `041-word-level-practice` | **Date**: 2026-08-16

Slice 4 already highlights the current timed word. Nested `phones[]` are still unused. This research locks how the panel becomes the **interactive** and **pronunciation-display** consumer without changing save, alignment, lookup, or karaoke’s highlight contract.

## Decisions

### 1. Two independent Settings keys (not karaoke, not enrichment)

**Decision**: Add:

- `SettingsKeys.transcriptIpaOverlay = 'transcript.ipaOverlay'`
- `SettingsKeys.transcriptWordPractice = 'transcript.wordPractice'`

Both `'true'`/`'false'`, missing ≡ off, device-global `SettingsDao`. Keep-alive Riverpod notifiers mirroring `KaraokeHighlightSettings` (`setEnabled` writes immediately; await the future on first read so loading ≠ off).

Place two new `SettingsRow` + `Switch.adaptive` in the Transcript section **after karaoke**. Registry `rowId`: `ipaOverlay`, `wordPractice`. Honor on the next play without restart. Hydrate both from `transcript_panel` during skeleton (same pattern as karaoke).

Neither requires `transcript.timelineEnrichment` or `transcript.karaokeHighlight` at play time.

**Rationale**: Spec FR-001 / FR-002. Learners may want IPA while reading without changing tap-to-seek, or tap/loop without crowding the line.

**Alternatives considered**:

- One bundled “word-level” switch — simpler Settings, but overlay would force seek-to-word on inactive rows (lookup-adjacent UX).
- Reuse karaoke key — mixes highlight vs IPA vs tap.
- Transport-bar toggles — spec assumes Settings persistence like karaoke.

### 2. IPA is an annotation layer, not part of selectable text

**Decision**: Keep the existing primary `Text.rich` / `TranscriptSelectableRichText` as **orthography only** (karaoke highlight stays in-place on that tree). When overlay is on, paint stored IPA in a separate `IgnorePointer` layer above each word box (`transcript_word_ipa_layer.dart`), using `TextPainter` boxes from the same plain text + style + width as the line.

- Concatenate non-empty `TranscriptPhone.phone` values in stored order (`transcript_word_ipa.dart`). Skip words with no usable phones. Do not invent spelling.
- Increase the tile’s top inset when overlay is on so ruby is not clipped.
- Blur wraps the **stack** (orthography + IPA) so spelling cannot leak through a blurred cue.
- `transcriptPlainForSelection` is unchanged. Lookup still receives line / substring text (FR-005).
- Semantics: MAY expose IPA on revealed cues via a dedicated child; MUST still include the line snippet; MUST NOT dump phones when overlay is off.
- Translation / secondary line: never annotated.

**Rationale**: Spec US2 / FR-004 / FR-005. WidgetSpan ruby inside `SelectableText.rich` would fight lookup selection (Windows/desktop especially). Inline `/ipa/` after the word would enter the selection string.

**Alternatives considered**:

- WidgetSpan ruby in the same span tree — rejected for lookup/selection.
- Inline IPA in the selectable string — violates FR-005.
- Overlay only on non-selectable rows — weaker than US2 (active line is where learners look).

### 3. Seek-to-word via plain-text hit-test, not chips

**Decision**: Do not replace the line with tappable chips. On **non-selectable** nested rows, when practice is on:

1. Map the tap’s local offset through `TextPainter.getPositionForOffset` → UTF-16 offset in `transcriptPlainForSelection`.
2. `wordIndexAtPlainOffset(plain, words, offset)` using sequential `wordHighlightRange` ranges (extend `current_transcript_word.dart` to return all ranges).
3. If the offset lands inside a timed word’s range (`durationMs > 0` and window intersects the line), call `PlayerInteractions.seekToWord(line, lineIndex, wordIndex)` → media time `line.startMs + word.startMs`, then play.
4. Otherwise fall through to today’s line seek (`onTap` / timestamp chrome).

Timestamp / meta row still line-seek. Gaps, punctuation, untimed words → line seek.

**Selectable** rows (active + echo): no word recognizers; `TranscriptSelectableRichText` unchanged. Loop/inspect the **current** timed word via `EnjoyTappableIcon`s on that cue’s meta row (tooltips; `Haptics`).

While echo is already active, tapping a **non-echo** line today retargets echo to that line (`_seekLine`). `seekToWord` on that path keeps that echo retarget (otherwise `EchoEnforcer` would clamp the seek back into the old echo and the learner would never hear the word) but seeks to the **word** start instead of the line start. Word **loop** still must not rewrite echo start/end (FR-008).

**Rationale**: FR-006 / FR-007. Chips would steal lookup. Hit-test reuses slice 4 range mapping.

**Alternatives considered**:

- Per-word `TapGestureRecognizer` on chips — rejected in slice 4; still rejected.
- Seek-to-word on selectable rows — steals dictionary lookup.

### 4. Share the 50 ms bucket for “current timed word”; karaoke paint stays gated

**Decision**: Add `activeCueWordIndexProvider(mediaId)` that watches the 50 ms karaoke position stream **only when karaoke OR word-practice is on**. `karaokeWordIndexProvider` continues to return null unless karaoke is on (paint gate). Practice icons use `activeCueWordIndexProvider` even when karaoke is off.

Do **not** change `kPositionBucketDisplayMs = 400`.

**Rationale**: Spec current timed word ≡ karaoke’s time match. Avoid 50 ms subscriptions when both features are off.

### 5. Ephemeral word loop; EchoEnforcer still owns echo membership

**Decision**: `WordLoopController` (Riverpod, per open media) holds `{lineIndex, wordIndex, mediaStartMs, mediaEndMs}` in memory. Not written to `SessionDao`.

`WordLoopEnforcer` in `PlayerPositionTracker`, **before** `EchoEnforcer.enforceTick`:

- While active, when position reaches or passes `mediaEndMs` during ordinary playback, seek to `mediaStartMs` and keep playing (no pause).
- Cancel (clear state) on: stop / clear media, practice setting off, progress-bar scrub, line chrome seek, seek to a different word, echo shrink that drops the looping line out of the echo window, media switch.
- While looping, skip `EchoEnforcer.enforceTick` pause-and-rewind so echo end does not steal the wrap. `clampAndSeek` still keeps user seeks inside echo when echo is on.
- Expand/shrink echo still uses line indices; loop does not call `echoModeProvider.activate`.

**Rationale**: FR-008. Reusing echo start/end as the loop window would rewrite the practice region. A second `Player()` is forbidden.

**Alternatives considered**:

- Temporarily overwrite echo window — violates FR-008.
- New `media_kit` Player for the word clip — ADR-0003 / ADR-0015.

### 6. Inspect is an Enjoy adaptive sheet of stored phones

**Decision**: `showEnjoyAdaptiveSheet` listing the chosen word’s text and ordered `phone` labels (skip empty). No invented IPA. If there are no phones, omit the inspect icon (quiet empty — no sheet). Root navigator (ADR-0065 / ADR-0066). Do not play a spoken reference or call `/pronounce` in this slice (lookup already has pronounce).

**Rationale**: FR-009 / FR-010. Overlay is reading-time concat; inspect is the ordered piece list.

### 7. Writers, alignment, and karaoke stay inert

**Decision**: Import, YouTube, ASR, auto-translate, and Craft save unchanged. No `alignSegments`. Transcript, settings, player, lookup, l10n MUST NOT import `package:forced_alignment/`. Karaoke highlight contract (ADR-0074) unchanged except sharing the current-word index helper. Assessment take-replay Azure chips unchanged.

Retarget nested-inert tests: both new settings **off** still show no IPA and line-level tap. Overlay-on asserts IPA in the annotation layer, not in selection text. Practice-on asserts word tap on non-selectable only.

**Rationale**: FR-015–FR-018.

### 8. ADR-0075; docs

**Decision**: New ADR-0075 (two settings, annotation-layer IPA, hit-test seek, ephemeral loop, inspect sheet). Do not rewrite ADR-0070–0074. Update `docs/features/transcript.md` and Settings search keywords (IPA, pronunciation, word loop, word tap).

**Rationale**: Constitution V.

## Open items resolved (no spec change)

| Topic | Resolution |
|-------|------------|
| One vs two toggles | Two keys, independent of karaoke |
| IPA typography | Annotation layer above word boxes; not in lookup text |
| IPA source | Stored `phones[].phone` only (no G2P / #527 Phase 1) |
| Word tap vs lookup | Hit-test on non-selectable rows only |
| Current word on selectable rows | Meta-row loop/inspect icons |
| Loop vs echo | Ephemeral enforcer; skip echo rewind while looping |
| Settings load | Await notifier; panel hydrates; tests override off notifiers |
| Play-time alignment | None |

## Dependencies

- Slice 1 nested cue JSON (ADR-0070), slice 3 Craft writer (ADR-0073) for typical data, slice 4 karaoke (ADR-0074) for highlight + 50 ms bucket.
- `EchoEnforcer` / `PlayerInteractions._seekLine` (echo retarget on out-of-echo tap).
- Settings hub Transcript section from 039/040.
- Blur contracts from spec 006; lookup ADR-0019; modals ADR-0065.
