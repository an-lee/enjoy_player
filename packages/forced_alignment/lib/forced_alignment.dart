/// On-device forced alignment (PCM in, Echogarden-shaped timings out).
library;

export 'src/alignment_service.dart' show align, alignSegments;
export 'src/constants.dart';
export 'src/failures.dart';
export 'src/flatten.dart';
export 'src/language_map.dart'
    show kSupportedAlignmentLanguageTags, isSupportedAlignmentLanguage;
export 'src/outcome.dart';
export 'src/request.dart';
export 'src/synth/espeak_reference.dart' show espeakFfiIsAvailable;
export 'src/types.dart';
export 'src/web_timings.dart';
