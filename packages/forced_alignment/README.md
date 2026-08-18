# forced_alignment

On-device forced alignment for Enjoy Player. Input is **16 kHz mono Float32 PCM**
plus known transcript text and a BCP-47 language. Output is an Echogarden-shaped
`AlignmentResult` (seconds on the source audio) or a typed `AlignmentFailure`.

**Production success** compares the clip to a same-language **spoken** eSpeak-NG
reference (waveform + word/phone events) via MFCC + windowed DTW. A duration-model
tone stand-in is not a production success. If the voice cannot be built, the
result is `spokenReferenceUnavailable`.

This package does **not** call FFmpeg, Drift, Craft, or widgets. The app does
not import it from product features
([ADR-0071](../../docs/decisions/0071-on-device-alignment-engine.md),
[ADR-0072](../../docs/decisions/0072-spoken-alignment-reference.md)).

## API

```dart
import 'package:forced_alignment/forced_alignment.dart';

final outcome = await align(
  sourcePcm16k: pcm,
  transcript: 'hello world',
  language: 'en-US',
);

final segmented = await alignSegments(
  sourcePcm16k: pcm,
  language: 'en-US',
  segments: [
    AlignmentSegment(text: 'hello world', startTime: 0, endTime: 2),
  ],
);

if (outcome is AlignmentSuccess) {
  final flat = flattenToWordPhoneTimings(outcome.result);
}
```

- Whole-clip `align` refuses audio **> 90 s** (`wholeClipTooLong`).
- `alignSegments` is valid for multi-minute PCM; each cue is sliced locally
  and gets its **own** spoken reference.
- Default granularity is `medium` (words + phones). `low` omits phones.
- DSP + production synth run in a worker isolate. Pass `AlignmentCancelToken`
  / `timeout`.
- Tests may inject a `SpokenReferenceSynthesizer`. Omitting it uses eSpeak-NG.

## Native layout

Vendored binaries (lazy load; not compiled during `flutter test`):

```text
native/<os>/libespeak-ng.*
native/espeak-ng-data/
```

macOS / iOS app builds embed the dylib and data tree in the `.app` so
production alignment works outside the source checkout. See
[native/README.md](native/README.md). eSpeak-NG is GPL-3.0.

## Tests

```bash
cd packages/forced_alignment && flutter test
```

DTW, flatten, caps, fail-closed, and failure tests always run. The eSpeak
FFI tests (golden, native phonemize, fr-CA voice) run unconditionally —
native binaries are vendored for every supported host platform, so a load
failure is a regression, not a skip.
