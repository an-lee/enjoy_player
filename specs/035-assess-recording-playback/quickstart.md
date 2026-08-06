# Quickstart: Assessment Recording Playback

**Feature**: `035-assess-recording-playback`  
**Contracts**: [contracts/README.md](./contracts/README.md) · **Model**: [data-model.md](./data-model.md)

## Prerequisites

- Flutter toolchain per repo README
- A media item with echo/shadow-reading cue text
- Signed-in path for assessment token (Enjoy) as today
- Assessment-supported language on the take / media

## Automated checks

```bash
# After implementation:
flutter test test/features/shadow_reading/domain/assessment_word_timing_test.dart
flutter test test/features/shadow_reading/
flutter analyze
bash .github/scripts/validate_ci_gates.sh --fix
```

Expected: tick→ms and active-word index tests green; widget tests cover disabled path, play/stop, clip disabled on omission, dismiss stops audio (with fakes as needed).

## Manual validation (E2E)

### A. Full take (P1)

1. Record a shadow take and run pronunciation assessment (or open a take that already has a score).
2. In the result detail, tap **play my recording**.
3. **Expect**: Full take audible from the start; control shows playing; tap again stops; dismiss stops audio.
4. Delete/rename the take file (or use a broken path in a debug build) and reopen stored result.
5. **Expect**: Scores still visible; play control disabled or brief error; no stuck spinner.

### B. Karaoke (P2)

1. Assess a multi-word cue with clear speech.
2. Play full take and watch the word chips.
3. **Expect**: Highlight advances with speech for timed words; stops when playback ends; no stuck “current” chip.
4. Mid-play, tap a word chip.
5. **Expect**: Full take stops; word detail opens; karaoke current cleared.

### C. Word clip vs model (P2)

1. Select a word with a non-omission score.
2. Tap **standard pronounce** — hear model audio.
3. Tap **my clip** — hear only that word’s portion of the take.
4. Alternate quickly; change chips mid-play.
5. **Expect**: Never overlapping streams; clip ≠ full take; omission/zero-duration words disable my-clip; model still available when applicable.

### D. Mutex with toolbar preview

1. From the takes toolbar, start preview of the same take.
2. Open assessment result and play full take or clip.
3. **Expect**: Single preview engine — result playback takes over cleanly; dismiss stops take audio.

## Timing sanity

- Azure `Duration: 10000000` ticks = **1 second** → helper must report ~1000 ms.
- If karaoke is wildly early/late by orders of magnitude, check tick→ms conversion first ([research.md](./research.md)).

## Done when

- [ ] Automated checks above pass
- [ ] Manual A–D pass on at least one desktop and one mobile target when available
- [ ] `docs/features/shadow-reading.md` updated with take replay / karaoke / clip behavior
