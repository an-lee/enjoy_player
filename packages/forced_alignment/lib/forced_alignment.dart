/// On-device forced alignment (PCM in, Echogarden-shaped timings out).
library;

export 'src/alignment_service.dart' show align, alignSegments;
export 'src/constants.dart';
export 'src/failures.dart';
export 'src/flatten.dart';
export 'src/language_map.dart'
    show
        kEspeakRequiredDataRelativePaths,
        kEspeakVoiceByLanguageTag,
        kSupportedAlignmentLanguageTags,
        isSupportedAlignmentLanguage;
export 'src/outcome.dart';
export 'src/phonemize.dart';
export 'src/request.dart';
export 'src/synth/espeak_ng_synthesizer.dart'
    show
        EspeakNgSynthesizer,
        createProductionSynthesizer,
        decodeEspeakPhonemeIdBytes,
        debugSetEspeakFfiAvailable,
        espeakFfiIsAvailable,
        productionSynthesizerIsEspeakNg;
export 'src/synth/native_paths.dart'
    show
        kEspeakAndroidSoname,
        resolveEspeakDataPath,
        resolveEspeakLibraryPath,
        missingEspeakRequiredDataFiles,
        setEspeakNativePathOverrides;
export 'src/synth/spoken_reference.dart';
export 'src/types.dart';
export 'src/web_timings.dart';
