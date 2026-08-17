# Contract: Writers

## On-demand enrich (this slice)

- Writer: transcript application enricher → `TranscriptRepository.replaceTimeline`.
- Target: **current primary** row only. Same id, source, language, label.
- Invalidates lines cache so the panel and CC sheet see nested data without restart.
- Secondary / auto-translate tracks are not enriched.

## Unchanged writers (stay line-only unless they already nested)

| Writer | This slice |
|--------|------------|
| Caption import | Line-only |
| YouTube caption fetch / worker cache | Line-only until the learner taps enrich |
| ASR generate | Line-only |
| Auto-translate overlay | Line-level secondary |
| Craft save | Still always-on `alignSegments` when audio exists (ADR-0076). No change required. |

## Forbidden

- New transcript `source` value for “enriched”.
- Background library backfill.
- First-play / seek / toggle-triggered enrich.
- YouTube media extract.

## Feature imports

- `lib/features/transcript/application` MAY import `package:forced_alignment/`.
- `lib/features/transcript/presentation`, settings, l10n MUST NOT.
- Transcript MUST NOT import `lib/features/craft` or `lib/features/asr`.
- Shared language map lives in `lib/data/subtitle/alignment_language.dart`.
