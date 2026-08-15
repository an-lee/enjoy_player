# forced_alignment

On-device forced alignment for Enjoy Player. Input is **16 kHz mono Float32 PCM**
plus known transcript text and a BCP-47 language. Output is an Echogarden-shaped
`AlignmentResult` (seconds on the source audio) or a typed `AlignmentFailure`.

This package does **not** call FFmpeg, Drift, Craft, or widgets. The app does
not import it from product features in the slice that introduced it
([ADR-0071](../../docs/decisions/0071-on-device-alignment-engine.md)).

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
- `alignSegments` is valid for multi-minute PCM; each cue is sliced locally.
- Default granularity is `medium` (words + phones). `low` omits phones.
- DSP runs in a worker isolate. Pass `AlignmentCancelToken` / `timeout`.

## Tests

```bash
cd packages/forced_alignment && flutter test
```

DTW, flatten, caps, and failure tests always run. The eSpeak “hello world”
golden **skips** when native eSpeak-NG FFI is not loaded (`espeakFfiIsAvailable()`).
