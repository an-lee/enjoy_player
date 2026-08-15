# Quickstart: Nested Transcript Timeline

**Feature**: `036-transcript-nested-timeline`  
**Contracts**: [contracts/README.md](./contracts/README.md) · **Model**: [data-model.md](./data-model.md)

## Prerequisites

- Flutter toolchain per repo README
- No new native deps, Drift migrations, or Settings entries

## Automated checks

```bash
flutter test test/data/subtitle/transcript_line_test.dart
flutter test test/features/transcript/transcript_lines_provider_dedupe_test.dart
flutter test test/features/domain_gaps_coverage_test.dart
flutter analyze
bash .github/scripts/validate_ci_gates.sh --fix
```

Expected:

- Round-trip tests: line-only JSON unchanged; nested words/phones preserved; empty lists omitted
- Malformed `timeline` does not drop the cue
- `cueIdFor` stable when `timeline` words are added (extend the existing `cueIdFor` group in `domain_gaps_coverage_test.dart` or cover it in `transcript_line_test.dart`)
- Existing provider dedupe tests still pass
- Tile with nested spans shows the same line text/timestamp as line-only

## Manual validation (E2E)

This slice has **no new UI**. Confirm existing library items still behave:

### A. Line-only library (P1)

1. Open one imported caption item, one YouTube item with captions, one ASR track, one Craft item with a synthesis transcript.
2. **Expect**: Same line text, order, and times as before this change; tap-to-seek, current-line, echo, lookup, auto-translate unchanged; no new buttons or per-word chrome.

### B. Nested fixture (P1, optional debug)

1. In a debug/dev build only, load a transcript whose `timeline_json` includes nested `timeline` / `phones` on some cues (test fixture or a one-off local row).
2. **Expect**: Panel still shows `line.text`; mixed nested/flat cues all visible; playback tracking still follows line times.

Do not ship a user-facing way to inject nested data in this slice.

## Done when

- [ ] Automated checks above pass (`flutter analyze` + `flutter test` green)
- [ ] Manual A passes on at least one desktop target
- [ ] `docs/features/transcript.md` notes storage-only nested spans
- [ ] ADR-0070 recorded and indexed in `docs/decisions/README.md`
