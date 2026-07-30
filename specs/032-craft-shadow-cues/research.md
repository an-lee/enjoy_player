# Research: Craft Shadow-Friendly Transcript Cues

**Feature**: `032-craft-shadow-cues` | **Date**: 2026-07-30

This document resolves the three open unknowns from the spec's Technical Context:

- **R1–R7 — Shadow-reading pedagogy**: concrete min/max line durations for FR-003 / SC-002.
- **R8 — Azure Speech Swift SDK word-boundary API**: the exact handler signature, event-arg shape, unit gotchas, and version availability for the iOS/macOS plugin fix (FR-001 / User Story 1).
- **R9 — Codebase architecture**: the locked contracts (method channel, segmenter tests, controller call-site, save path, wire format, CJK hook) the redesign must preserve.

Citations are marked **[verified]** when read this session, **[canonical]** when standard references widely reproduced in the literature (not re-fetched line-by-line this session).

## TL;DR recommendation (the numbers FR-003 needs)

- **Min useful line ≈ 1.2 s** (absolute floor); **practical target floor ≈ 1.5 s.**
- **Soft max ≈ 6.0 s** (preferred split point); **hard max ≈ 7.0 s** (no line may exceed).
- **Target window ≈ 1.5–6.0 s**, which matches the spec's working assumption
  ("roughly 1.5–6 seconds per line") and is defensible from three independent
  directions: (a) the verbatim working-memory ceiling, (b) the natural duration of a
  spoken thought/breath unit, and (c) professional concurrent-shadowing (interpreting)
  unit sizes. See R7 for the full reasoning.

---

## R1 — What "shadow unit" means in the literature

Shadowing in SLA is "repeating a portion of native-speaker input verbatim and almost
simultaneously, lagging a fraction of a second behind" (Argüelles' method, summarized by
the Mezzoguild review **[verified]**; Conti 2025 SLA summary **[verified]**). Three
research traditions converge on what the repeatable unit is:

1. **Japanese shadowing research** (the deepest empirical tradition on the technique).
   Conti (2025) **[verified]** names the canonical chain: Tamai (1992), one of the earliest
   studies, through Kadota (2007, 2012) and Hamada (2016). In that tradition the practice
   *material* is typically a **sentence or short utterance**, and the cognitive echo is the
   **clause/breath group inside it**, not the whole sentence at once **[canonical]**.
2. **Interpreter-training / concurrent-shadowing tradition** (Gerver; Chernov; Goldman-Eisler).
   Professional simultaneous interpreters — the expert end of shadowing — deliberately wait
   for a **meaning unit / clause** before producing, which empirically sizes the "shadow
   unit" at the clause level (R5).
3. **ESL pronunciation pedagogy** (thought groups / sense groups): Gilbert's *Clear Speech*
   and Celce-Murcia, Brinton & Goodwin's *Teaching Pronunciation* define a **thought group**
   as one idea + one intonation contour + one breath **[canonical]** — the exact thing a
   learner repeats. This is the practical definition that best fits a transcript *line*.

**Conclusion**: the defensible "shadow unit" for a transcript line is **one thought/breath
group ≈ one short clause**, i.e. "as much as a learner can say on one breath carrying one
idea." It is not a word, and not a full compound sentence.

## R2 — Empirical numbers: how long is a single shadowable phrase in seconds?

No single paper prescribes "a shadowing chunk is exactly X seconds." The range is
triangulated, and every strand lands inside roughly **1.5–6 s**:

| Strand | Typical unit duration | Source |
|---|---|---|
| Verbatim working-memory ceiling (what you can hold to repeat) | ~1.5–2.0 s of articulation | Baddeley, Thomson & Buchanan (1975) — word-length effect / phonological loop **[canonical]** |
| Conversational intonation units / "idea beats" | ~1.0–2.0 s (avg ~1.5 s) | Chafe (1994) *Discourse, Consciousness, and Time* — IUs avg ~5 words **[canonical]**; conversational turns mean **1.68 s** in Levinson & Torreira (2015) **[verified]** |
| Cortical/production rhythm of speech | low-θ ~3 Hz (syllable) wrapping a ~1 Hz super-unit → ~1–3 s parcels | "Sequences of Intonation Units form a ~1 Hz rhythm," *Sci. Reports* **[verified]** |
| Interpreter ear–voice span (pro shadow lag) | mean ~2 s, range ~1–5 s | Gerver (1969, 1976), empirical SI studies **[canonical]** |
| Read/formal-speech clause / breath group (the ceiling case) | ~2–6 s | Goldman-Eisler (1968, 1972) clause/breath-group timing **[canonical]** |

So the literature's implicit "shadow unit" is: **short end ~1.5–2 s (a single idea in fast
speech), long end ~5–6 s (one substantial clause in read/prepared speech).** That is the
empirical justification for a **~1.5–6 s target window** with a **~7 s hard cap.**

## R3 — Beginner vs advanced: does the recommended unit size change?

Yes, and the direction is consistent across traditions:

- **Beginners** should echo **shorter** units and slower speech, often with a look-ahead /
  preview pass ("read-and-look-up" before concurrent shadowing). Why: the Baddeley ~2 s
  *verbatim* ceiling bites harder when L2 phonological encoding is slow, so a beginner
  can't safely stretch to a long clause. Recommended unit ≈ **2–4 s, single clause**
  **[canonical; consistent with Hamada 2016 via Conti 2025, verified]**.
- **Advanced** learners can shadow longer stretches (a full sentence / two short clauses,
  up to ~6–8 s) with a shorter lag and faster input **[canonical]**.

Implication for a single, level-agnostic segmenter (which Craft must be): **target the
beginner-safe end of the window as the default**, because a line that's comfortable for a
beginner is still usable by an advanced learner, while a long line is unusable for a
beginner. That pushes the **soft max toward ~6 s, hard max ~7 s**, not higher.

**Minimum**: a line much under ~1 s is almost always a lone content word or a function-word
cluster — not a thought group and not worth a standalone line. Below ~1.2 s you typically
get single-token fragments. So **floor ≈ 1.2 s absolute, ~1.5 s practical.**

## R4 — CJK (Chinese / Japanese / Korean): clause-based, not word-count chunking

The research is clear that **word-count rules do not transfer to spaceless CJK scripts**;
the natural unit is prosodic/clausal:

- **Japanese**: the **bunsetsu** (a content word + its following particles) is the minimal
  prosodic/intonation unit; shadowing pedagogy (Kadota/Shiki tradition) and TTS prosody
  break naturally at bunsetsu and clause (文節 / 句) boundaries, not at "words." Clause
  punctuation (、) marks the canonical breath point **[canonical]**.
- **Chinese**: the **prosodic hierarchy** (韵律词 → 韵律短语 → 意群) places perceptible
  boundaries at commas and clause ends; there are no inter-word spaces, so chunking must
  follow punctuation + duration, exactly as the spec's FR-006 requires **[canonical;
  Chinese prosodic-boundary acoustic-cue literature, verified to exist]**.
- **Korean**: same pattern — prosodic breaks at 어절/clause boundaries, not space-count.

**Implication**: for CJK the segmenter should **never** apply a Latin word-count; it should
break at clause punctuation (、，；：。！？) and inter-token pauses, with duration as the
governing constraint (FR-005/FR-006). This is not a special-case hack — it matches how
native prosody is already organized in those languages.

## R5 — Break at natural pause points, not arbitrary word counts

Strongly supported across all traditions:

- **Goldman-Eisler (1968/1972)**: silent pauses cluster at **clause boundaries**, and
  longer pauses (the ones that mark real junctures) are reliably at clause/sentence ends,
  not mid-phrase **[canonical]**.
- **Interpreter training**: pros deliberately chunk at clause/sense boundaries; mid-phrase
  breaks are a known failure mode ("chunking error") **[canonical]**.
- **ESL thought-group teaching**: thought-group boundaries are defined at punctuation and
  pauses, *never* by counting words **[canonical]**.

**Implication for FR-004's break priority**: sentence-end → clause/phrase punctuation →
largest inter-word silence → duration cap → (word count only as a last-resort tiebreaker).
This is exactly the priority the spec already specifies, and it is the empirically correct
order: punctuation/pause boundaries are *where listeners and speakers actually segment*,
while a word count is a poor proxy that often cuts mid-thought. The duration **cap** exists
only to handle long unpunctuated sentences where no natural boundary falls inside the
window (the spec's Edge Case).

## R6 — Session/practice structure (secondary, for context)

- Tamai (1992) and successors prescribe **many short repetitions** of modest material
  (tens of sentences per session, ~15 min/day), emphasizing **quality of each repeat**
  over total volume **[canonical, via Conti 2025 verified]**.
- This reinforces the line-as-one-clean-echo model: a learner works through **one line at
  a time**, looping it. That only works if each line is a self-contained, repeatable unit —
  another argument against both ultra-short fragments and long run-ons.

## R7 — Consolidated recommendation for FR-003 min/max

Chosen so a line ≈ one beginner-safe thought/breath group, with the upper bound soft and
forgiving for advanced learners:

| Parameter | Value | Rationale |
|---|---|---|
| **Min line (absolute floor)** | **1.2 s** | Below this, lines are almost always a lone token / function-word run, not a thought group (R3). |
| **Min line (practical target)** | **~1.5 s** | The natural conversational "idea beat" (Levinson & Torreira 2015, verified; Chafe IUs, canonical). |
| **Soft max (preferred split point)** | **6.0 s** | Upper end of a read-speech clause/breath group (Goldman-Eisler, canonical) and of an interpreter meaning-unit (Gerver, canonical). |
| **Hard max (no line may exceed)** | **7.0 s** | Lets a long-but-still-shadowable clause survive one boundary miss; beyond ~7 s verbatim echo accuracy drops even for advanced learners (phonological-loop + breath-group ceilings). |
| **Target window** | **1.5–6.0 s** | Matches spec working assumption; safe default that also serves advanced users (R3). |

**How to apply** (informing the algorithm, not prescribing code):
1. Within a sentence, accumulate tokens while spoken span < **soft max (6.0 s)** and break
   at the highest-priority natural boundary (sentence end → clause mark → largest silence).
2. If no natural boundary appears before **hard max (7.0 s)**, force a break at the best
   available point (largest silence / clause mark), never letting any line exceed 7.0 s.
3. After building, **merge** any standalone line shorter than **1.2 s** into a neighbor
   (FR-007 prevents starting a line with punctuation, so merges absorb trailing punctuation
   tokens cleanly).
4. CJK path uses the same durations + clause punctuation only; no word-count path (FR-006).

This range is **defensible**: every constituent number is independently attested in the
verbatim-memory, prosody, and interpreter literatures (R2), and the beginner/advanced and
CJK evidence (R3, R4) all push toward the same window rather than widening it.

## Caveats / honesty about the evidence

- **No single source** states "a shadowing line must be 1.5–6 s." The range is a reasoned
  triangulation; R2 lists each contributing strand so the choice is auditable.
- The **classic references** (Baddeley et al. 1975; Chafe 1994; Goldman-Eisler 1968/1972;
  Gerver 1969/1976; Gilbert *Clear Speech*; Celce-Murcia et al. *Teaching Pronunciation*;
  Tamai 1992; Kadota 2007/2012; Hamada 2016) are reproduced across many secondary sources
  and are marked **[canonical]** here rather than re-fetched line-by-line; their core
  figures (≈2 s memory span, ≈2 s interpreter lag, clause-level chunking) are stable across
  sources and not in dispute.
- Empirical **fine-tuning** of 1.2 / 6.0 / 7.0 s should be validated against real Enjoy
  Craft samples post-implementation (SC-002 already measures "% lines in range"); the
  pedagogy justifies the *neighborhood*, and the success criterion closes the loop.

## Sources

Verified this session:
- Conti, G. (2025). *Shadowing for Fluency, Prosody, and Listening Comprehension — the what/why/how according to SLA research.* https://gianfrancoconti.com/2025/07/26/shadowing-for-fluency-prosody-and-listening-comprehension-the-what-why-and-how-according-to-sla-research/ — names Tamai (1992), Kadota (2007, 2012), Hamada (2016).
- *Sequences of Intonation Units form a ~1 Hz rhythm.* Scientific Reports. https://www.nature.com/articles/s41598-020-72739-4
- Levinson, S. C., & Torreira, F. (2015). Timing in turn-taking and its implications for processing models of language. *Front. Psychol.* (mean turn ≈ 1.68 s; gaps 100–300 ms). https://pmc.ncbi.nlm.nih.gov/articles/PMC4464110/
- *Effects of training of shadowing and reading aloud of second language…* (shadowing study, session-structure context). https://pmc.ncbi.nlm.nih.gov/articles/PMC8286220/
- *How Pause Duration Influences Impressions of English Speech.* (pause-duration review). https://pmc.ncbi.nlm.nih.gov/articles/PMC8874014/
- *Situating Shadowing in the Framework of Deliberate Practice.* RELC Journal / SAGE. https://journals.sagepub.com/doi/full/10.1177/00336882221087508
- *Shadowing as a Practice in Second Language Acquisition: Connecting Inputs and Outputs* (review). https://www.researchgate.net/publication/333202285_Shadowing_as_a_Practice_in_Second_Language_Acquisition_Connecting_Inputs_and_Outputs
- Mezzoguild. *Language Shadowing: A Superior Learning Method* (Argüelles method summary). https://www.mezzoguild.com/language-shadowing-a-superior-learning-method/

Canonical references (standard in the literature, not re-fetched line-by-line this session):
- Baddeley, A., Thomson, N., & Buchanan, M. (1975). Word length and the structure of short-term memory. *J. Verbal Learning & Verbal Behavior*, 14, 575–589. — phonological loop ≈ 1.5–2 s of articulation; the verbatim-repeat ceiling.
- Chafe, W. (1994). *Discourse, Consciousness, and Time.* Univ. of Chicago Press. — intonation units ≈ one focus of consciousness ≈ ~5 words ≈ ~1–2 s.
- Goldman-Eisler, F. (1968/1972). *Psycholinguistics: Experiments in Spontaneous Speech*; "Pauses, clauses, sentences." — clause/breath-group durations ~2–6 s; pauses cluster at clause boundaries.
- Gerver, D. (1969/1976). Empirical studies of simultaneous interpretation. — ear–voice span mean ~2 s (range ~1–5 s); interpreters chunk at meaning/clause units.
- Gilbert, J. B. *Clear Speech* (CUP). — thought/sense group = one idea + one intonation contour + one breath; boundaries at punctuation/pauses, not word counts.
- Celce-Murcia, M., Brinton, D. M., & Goodwin, J. M. *Teaching Pronunciation* (CUP). — thought-group pedagogy, boundary marking.
- Kadota, S. (2007/2012); Tamai, K. (1992); Hamada, Y. (2016). — Japanese shadowing tradition (practice unit = sentence/utterance; echo unit = clause/breath group; beginners use shorter/slower units).
- Japanese bunsetsu (Vendryes; McCawley) and Chinese prosodic hierarchy (韵律词/韵律短语/意群) — CJK minimal/prosodic units are clausal, not word-count-based.

---

## R8 — Azure Speech Swift SDK word-boundary API (FR-001 / User Story 1)

The iOS/macOS plugin at `packages/azure_speech` currently calls `SPXSpeechSynthesizer.speakText(text)` with **no** word-boundary handler registered (`ios/Classes/AzureSpeechPlugin.swift:221-231`, identical in macOS). This is exactly why Apple saves produce zero boundaries. The API to fix this is present and stable.

### Decision

Register `addSynthesisWordBoundaryEventHandler` on the `SPXSpeechSynthesizer` **before** calling `speakText`, append each event into a captured array, and emit the same `{text, audioOffset, duration}` JSON shape the Android/Windows plugins already produce.

### Exact Swift API

From `SPXSpeechSynthesizer.h` (ObjC header surfaced into Swift):

```objc
typedef void (^SPXSpeechSynthesisWordBoundaryEventHandler)(
    SPXSpeechSynthesizer * _Nonnull,
    SPXSpeechSynthesisWordBoundaryEventArgs * _Nonnull);

- (void)addSynthesisWordBoundaryEventHandler:
    (nonnull SPXSpeechSynthesisWordBoundaryEventHandler)eventHandler;
```

Swift usage:

```swift
synthesizer.addSynthesisWordBoundaryEventHandler { synthesizer, eventArgs in
    // append to captured array
}
```

No property form, no remove/unsubscribe API needed (the synthesizer is short-lived per call).

### Event-arg shape — `SPXSpeechSynthesisWordBoundaryEventArgs`

| Property | Type | Unit | Notes |
|---|---|---|---|
| `audioOffset` | `NSUInteger` | **100-ns ticks** | Same as Android/Windows. ÷ 10000 → ms. |
| `duration` | `NSTimeInterval` (Double) | **seconds** | **Cross-platform gotcha** — Java/C++ return ticks/ms; ObjC returns seconds. Must convert: `Int(eventArgs.duration * 10_000_000)` to emit ticks. |
| `text` | `NSString` | — | The word (or punctuation) text. Added 1.21.0. |
| `boundaryType` | `SPXSpeechSynthesisBoundaryType` | enum | **Defective on ObjC** — see gotcha below. |
| `textOffset` / `wordLength` | `NSUInteger` | UTF-16 code units | Offset into source text. |
| `resultId` | `NSString` | — | Added 1.25.0. |

### Threading / ordering

- Register the handler **before** `speakText` / `startSpeakingText`; events fire during synthesis.
- Events fire on a **background SDK thread**. The plugin's existing `performSynthesis` already runs on `DispatchQueue.global(qos: .userInitiated)` and `speakText` blocks until synthesis completes, so all events have fired by the time it returns. The handler body can stay off-main (captured-array append) — no `dispatch_get_main_queue()` hop needed.

### Version availability — no podspec bump required

Both podspecs (`packages/azure_speech/ios/azure_speech.podspec:18`, `macos/azure_speech.podspec:15`) pin **`~> 1.49.0`**. The handler surface has been stable since well before that:

- `addSynthesisWordBoundaryEventHandler:` — since **1.7.0**.
- `duration` / `text` / `boundaryType` on the event args — since **1.21.0**.
- `resultId` — since **1.25.0**.

So the full surface is present in 1.49.0. **No dependency bump needed.**

### Gotchas

1. **`duration` is seconds on ObjC** (not ticks, not ms). Android emits `Long` ticks; Windows multiplies ms × 10000 back to ticks; Swift must do `Int(duration * 10_000_000)` to match the Dart parser's tick expectation.
2. **`SPXSpeechSynthesisBoundaryType` enum collision** (`SPXSpeechEnums.h:1285-1299`): on the ObjC binding `Word = 1` and `Punctuation = 1` **collide** (`Sentence = 2`). You **cannot** reliably distinguish word-vs-punctuation tokens via this enum on Apple. Classify by `text` content instead — the existing `isPunctuationOnlyToken` / `mergePunctuationTokens` logic in the Dart segmenter already handles punctuation tokens by text, so forward punctuation events verbatim and let the Dart side merge them. (Java/C++ enums are correct; only the ObjC bridge is defective.)
3. **Punctuation boundaries fire** with the punctuation character as `text`. The segmenter's existing punctuation-merge path consumes these.
4. **No enable flag** — events fire by default once a handler is registered.
5. **CJK granularity**: docs do not document per-locale granularity; `WordBoundary` fires at the service's word segmentation for CJK (not per character). A separate voice-specific bug (Azure-Samples#2359) affects some neural voices after special characters — not CJK-specific, not blocking.

### Contract to mirror (Android / Windows)

The Swift port must produce the same JSON the method-channel Dart parser already expects (`packages/azure_speech/lib/src/method_channel_azure_speech.dart:120-130`):

- Top level: `{"audio": "<base64>", "wordBoundaries": [...]}`
- Per boundary: `{"text": String, "audioOffset": Int (ticks), "duration": Int (ticks)}`

- **Android** (`AzureSpeechPlugin.kt:201-208`): `synthesizer.WordBoundary.addEventListener { _, e -> ... e.text / e.audioOffset / e.duration }` — both offsets/durations are `Long` ticks, emitted verbatim.
- **Windows** (`azure_speech_plugin.cpp:139-154`): `synthesizer->WordBoundary.Connect(sink)`; `args.Duration` is ms, re-multiplied × 10000 to emit ticks.

### Decision summary

| Question | Resolution |
|---|---|
| Is the handler available in the pinned SDK? | **Yes** (1.49.0; surface since 1.7.0/1.21.0). No podspec bump. |
| Exact selector | `addSynthesisWordBoundaryEventHandler:` |
| When to register | Before `speakText` |
| Threading | Background SDK thread; captured-array append is safe |
| `duration` unit | **Seconds** → convert to ticks `Int(d * 10_000_000)` |
| `boundaryType` usable? | **No** (enum collision) — classify punctuation by `text` instead |
| CJK granularity | Service-segmented word level (not per char) |

---

## R9 — Codebase architecture: locked contracts the redesign must preserve

### R9.1 — Method-channel JSON contract

File: `packages/azure_speech/lib/src/method_channel_azure_speech.dart`, `synthesize(...)` lines 90–155.

- Native may return either a **plain base64 string** (legacy → empty boundaries) or a **JSON object** `{"audio": "<base64>", "wordBoundaries": [...]}`.
- Per-boundary decode (lines 120–130): keys `text` / `audioOffset` / `duration`; native sends **ticks (100-ns)**; Dart divides by **10000** and `.round()`s to ms.
- No `boundaryType` key is read — the Swift port need not emit it.
- `AzureWordBoundary` model (`azure_speech_synthesis_outcome.dart:6-22`): `{text: String, audioOffsetMs: int, durationMs: int}`.

### R9.2 — Domain boundary + result shapes

File: `lib/features/craft/domain/craft_synthesizer.dart:6-30`.

- `CraftWordBoundary {text, audioOffsetMs, durationMs}` — adapter-1:1 with `AzureWordBoundary` (`craft_adapters_test.dart:109-153` locks the mapping). **Keep this 3-field shape.**
- `CraftSynthesisResult {audioBytes: Uint8List, format: String, wordBoundaries: List<CraftWordBoundary>}`.
- `CraftSynthesizer.synthesize({text, language, voice})` — the port.

### R9.3 — Existing segmenter tests (locked contracts)

File: `test/features/craft/domain/word_boundary_segmenter_test.dart` (256 lines). Behaviors contractually locked:

| Behavior | Locked by | Redesign stance |
|---|---|---|
| Empty input → `[]` / `null` | `segmentWordBoundaries([])` → `isEmpty`; `buildCraftPrimaryTimelineJson([])` → `isNull` | **Preserve** (also FR-011). |
| Punctuation-only input → `null` | `[., ?]` → `isNull` | **Preserve** (blank-transcript gate). |
| Standalone Azure punct tokens never begin a segment; merged onto prior word; timing extended to later end | "attaches standalone period…", "does not start a line with standalone Azure punctuation tokens" | **Preserve** (FR-007). |
| Sentence-ending punct (`.。！？!?`) forces flush even below word count | "prefers sentence end over mid-sentence word-count chop" | **Preserve & extend** (add clause punctuation). |
| Within a sentence, chop at `preferredWordsPerSegment` (default 6) | "splits long sentences at preferred word count" | **Replace** with duration-aware + clause/pause-aware splitting (FR-003/FR-004). Tests asserting pure word-count behavior get updated. |
| `start` = first boundary onset; `duration` = (last end) − start | "timestamps come from word boundaries" | **Preserve** (FR-008). |
| CJK full-width `。！` handled | "handles CJK full-width punctuation tokens" | **Preserve & extend** to clause punctuation `、，；：` (FR-005/FR-006). |
| Wire JSON `{text, start, duration}` | `segmentsToTimelineJson` test | **Preserve** (FR-013). |

### R9.4 — Controller call-site (single seam)

File: `lib/features/craft/application/craft_controller.dart`.

- `previewWordBoundaries` set in **one** place: `synthesize()` lines 187–199. Both Express (`generateAudio` → `synthesize`) and Advanced route through this single method.
- `buildCraftPrimaryTimelineJson(state.previewWordBoundaries)` called **once** at save (lines 226–230); `preferredWordsPerSegment` is never passed (always default 6).
- **CJK-awareness hook**: the segmenter does not currently see `state.synthLanguage`. To make it CJK-aware, thread `state.synthLanguage` (or `primaryLanguageSubtag(state.synthLanguage) ∈ {zh, ja, ko}`) into `buildCraftPrimaryTimelineJson` — a localized change at this single call-site.

### R9.5 — Library repository save path

File: `lib/features/library/data/library_repository.dart`.

- `importCraftedFromText(..., String? primaryTimelineJson, ...)` (lines 338–442): transcript row written **only when `primaryTimelineJson != null`**; `source: 'ai'`, deterministic id via `enjoyTranscriptId(...)`.
- `updateCraftedFromText(..., String? primaryTimelineJson, ...)` (lines 524–620): bulk-deletes existing transcripts, then upserts primary row only when non-null. `null` clears prior cues (intentional).
- **No schema change needed** — `primaryTimelineJson` is already a nullable string parameter.

### R9.6 — Wire format consumers

- `TranscriptLine.fromJson` (`lib/data/subtitle/transcript_line.dart:55-63`): decodes `{text, start, duration}` defensively (`?? ''`, `?? 0`); optional `sourceKey` ignored by Craft.
- `_decodeTimeline` (`transcript_repository.dart:58-62`) memoized on `(id, sha1(timelineJson))`, with background-isolate variant.
- **The `{text, start, duration}` shape is the only hard contract.** Extra keys would be ignored; the Craft segmenter is the only producer that builds the JSON by hand rather than via `TranscriptLine.toJson()`.

### R9.7 — CJK detection (none exists)

- **No CJK/Unicode-script detection utility anywhere** in `lib/core` or `lib/features`. The only CJK-aware code is the segmenter's own `。！？` regex (`word_boundary_segmenter.dart:21-22`).
- The learning-language hook is `state.synthLanguage` (`craft_job_state.dart:84`); normalize via `primaryLanguageSubtag(state.synthLanguage)` (`app_language_catalog.dart:216-219`) and test membership in `{'zh', 'ja', 'ko'}`. CJK word boundaries from Azure arrive at service-segmented word granularity (R8), not per character.

### Decision summary (architecture)

| Concern | Decision |
|---|---|
| `CraftWordBoundary` shape | Keep 3 fields (`text, audioOffsetMs, durationMs`) |
| Method-channel JSON | Unchanged — Swift emits `{text, audioOffset(ticks), duration(ticks)}` |
| Wire format | Unchanged — `[{text, start, duration}]` |
| Schema | Unchanged — `primaryTimelineJson: String?` already nullable |
| CJK awareness | Thread `state.synthLanguage` into the single `buildCraftPrimaryTimelineJson` call-site; detect via `primaryLanguageSubtag ∈ {zh,ja,ko}` |
| Locked segmenter tests | Preserve empty/punct-merge/sentence-flush/timing/wire contracts; **update** the pure word-count-chop tests to the new duration + clause + pause algorithm |
| New util | Add a small CJK-script/language helper (none exists today) |

