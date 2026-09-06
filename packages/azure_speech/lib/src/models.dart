import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

const _azureEmptyPronunciationScores = AzurePronunciationAssessmentScores(
  accuracyScore: 0,
  fluencyScore: 0,
  completenessScore: 0,
  pronScore: 0,
  prosodyScore: null,
);

const _azureEmptyWordPronunciation = AzureWordPronunciationAssessment(
  accuracyScore: 0,
  errorType: 'None',
);

const _azureEmptySyllablePronunciation = AzureSyllablePronunciationAssessment(
  accuracyScore: 0,
);

const _azureEmptyPhonemePronunciation = AzurePhonemePronunciationAssessment(
  accuracyScore: 0,
  nBestPhonemes: null,
);

/// Normalizes a decoded JSON value to a `Map<String, dynamic>` — jsonDecode
/// yields `Map<dynamic, dynamic>` at runtime, so raw `is Map` results need
/// re-keying before `fromJson`.
Map<String, dynamic>? _asMap(Object? json) => json is Map<String, dynamic>
    ? json
    : (json is Map ? Map<String, dynamic>.from(json) : null);

/// Azure may omit tick fields for some word / error types (e.g. omission).
int _azureJsonIntTick(Object? json) {
  if (json == null) return 0;
  if (json is int) return json;
  if (json is num) return json.toInt();
  if (json is String) {
    final i = int.tryParse(json);
    if (i != null) return i;
    final d = double.tryParse(json);
    if (d != null) return d.toInt();
  }
  return 0;
}

double _azureJsonDoubleScore(Object? json) {
  if (json == null) return 0;
  if (json is double) return json;
  if (json is num) return json.toDouble();
  if (json is String) {
    final d = double.tryParse(json);
    if (d != null) return d;
  }
  return 0;
}

double? _azureJsonDoubleScoreOpt(Object? json) {
  if (json == null) return null;
  if (json is double) return json;
  if (json is num) return json.toDouble();
  if (json is String) {
    return double.tryParse(json);
  }
  return null;
}

String _azureJsonString(Object? json) {
  if (json == null) return '';
  if (json is String) return json;
  return json.toString();
}

String _azureJsonErrorType(Object? json) {
  if (json == null) return 'None';
  if (json is! String || json.isEmpty) return 'None';
  return json;
}

List<AzureNBestResult> _azureJsonNBestList(Object? json) {
  if (json is! List) return const [];
  return [
    for (final e in json)
      if (_asMap(e) case final m?) AzureNBestResult.fromJson(m),
  ];
}

List<AzureWordAssessment> _azureJsonWordsList(Object? json) {
  if (json is! List) return const [];
  return [
    for (final e in json)
      if (_asMap(e) case final m?) AzureWordAssessment.fromJson(m),
  ];
}

AzurePronunciationAssessmentScores _azureJsonPronunciationScores(Object? json) {
  final m = _asMap(json);
  return m == null
      ? _azureEmptyPronunciationScores
      : AzurePronunciationAssessmentScores.fromJson(m);
}

AzureWordPronunciationAssessment _azureJsonWordPronunciation(Object? json) {
  final m = _asMap(json);
  return m == null
      ? _azureEmptyWordPronunciation
      : AzureWordPronunciationAssessment.fromJson(m);
}

AzureSyllablePronunciationAssessment _azureJsonSyllablePronunciation(
  Object? json,
) {
  final m = _asMap(json);
  return m == null
      ? _azureEmptySyllablePronunciation
      : AzureSyllablePronunciationAssessment.fromJson(m);
}

AzurePhonemePronunciationAssessment _azureJsonPhonemePronunciation(
  Object? json,
) {
  final m = _asMap(json);
  return m == null
      ? _azureEmptyPhonemePronunciation
      : AzurePhonemePronunciationAssessment.fromJson(m);
}

/// Root JSON from [SpeechServiceResponse_JsonResult] (Azure Speech SDK).
@JsonSerializable(createToJson: false)
final class AzurePronunciationAssessmentResult {
  const AzurePronunciationAssessmentResult({
    required this.recognitionStatus,
    required this.offset,
    required this.duration,
    required this.displayText,
    required this.nBest,
  });

  @JsonKey(name: 'RecognitionStatus', fromJson: _azureJsonString)
  final String recognitionStatus;

  @JsonKey(name: 'Offset', fromJson: _azureJsonIntTick)
  final int offset;

  @JsonKey(name: 'Duration', fromJson: _azureJsonIntTick)
  final int duration;

  @JsonKey(name: 'DisplayText', fromJson: _azureJsonString)
  final String displayText;

  @JsonKey(name: 'NBest', fromJson: _azureJsonNBestList)
  final List<AzureNBestResult> nBest;

  factory AzurePronunciationAssessmentResult.fromJson(
    Map<String, dynamic> json,
  ) => _$AzurePronunciationAssessmentResultFromJson(json);

  /// Convenience: first hypothesis scores (null if [nBest] empty).
  AzurePronunciationAssessmentScores? get primaryScores =>
      nBest.isEmpty ? null : nBest.first.pronunciationAssessment;
}

@JsonSerializable(createToJson: false)
final class AzureNBestResult {
  const AzureNBestResult({
    required this.confidence,
    required this.lexical,
    required this.itn,
    required this.maskedItn,
    required this.display,
    required this.pronunciationAssessment,
    required this.words,
  });

  @JsonKey(name: 'Confidence', fromJson: _azureJsonDoubleScore)
  final double confidence;

  @JsonKey(name: 'Lexical', fromJson: _azureJsonString)
  final String lexical;

  @JsonKey(name: 'ITN', fromJson: _azureJsonString)
  final String itn;

  @JsonKey(name: 'MaskedITN', fromJson: _azureJsonString)
  final String maskedItn;

  @JsonKey(name: 'Display', fromJson: _azureJsonString)
  final String display;

  @JsonKey(
    name: 'PronunciationAssessment',
    fromJson: _azureJsonPronunciationScores,
  )
  final AzurePronunciationAssessmentScores pronunciationAssessment;

  @JsonKey(name: 'Words', fromJson: _azureJsonWordsList)
  final List<AzureWordAssessment> words;

  factory AzureNBestResult.fromJson(Map<String, dynamic> json) =>
      _$AzureNBestResultFromJson(json);
}

@JsonSerializable(createToJson: false)
final class AzurePronunciationAssessmentScores {
  const AzurePronunciationAssessmentScores({
    required this.accuracyScore,
    required this.fluencyScore,
    required this.completenessScore,
    required this.pronScore,
    this.prosodyScore,
  });

  @JsonKey(name: 'AccuracyScore', fromJson: _azureJsonDoubleScore)
  final double accuracyScore;

  @JsonKey(name: 'FluencyScore', fromJson: _azureJsonDoubleScore)
  final double fluencyScore;

  @JsonKey(name: 'CompletenessScore', fromJson: _azureJsonDoubleScore)
  final double completenessScore;

  @JsonKey(name: 'PronScore', fromJson: _azureJsonDoubleScore)
  final double pronScore;

  @JsonKey(name: 'ProsodyScore', fromJson: _azureJsonDoubleScoreOpt)
  final double? prosodyScore;

  factory AzurePronunciationAssessmentScores.fromJson(
    Map<String, dynamic> json,
  ) => _$AzurePronunciationAssessmentScoresFromJson(json);
}

@JsonSerializable(createToJson: false)
final class AzureWordAssessment {
  const AzureWordAssessment({
    required this.word,
    required this.offset,
    required this.duration,
    required this.pronunciationAssessment,
    this.syllables,
    this.phonemes,
  });

  @JsonKey(name: 'Word', fromJson: _azureJsonString)
  final String word;

  @JsonKey(name: 'Offset', fromJson: _azureJsonIntTick)
  final int offset;

  @JsonKey(name: 'Duration', fromJson: _azureJsonIntTick)
  final int duration;

  @JsonKey(
    name: 'PronunciationAssessment',
    fromJson: _azureJsonWordPronunciation,
  )
  final AzureWordPronunciationAssessment pronunciationAssessment;

  @JsonKey(name: 'Syllables')
  final List<AzureSyllableAssessment>? syllables;

  @JsonKey(name: 'Phonemes')
  final List<AzurePhonemeAssessment>? phonemes;

  factory AzureWordAssessment.fromJson(Map<String, dynamic> json) =>
      _$AzureWordAssessmentFromJson(json);
}

@JsonSerializable(createToJson: false)
final class AzureWordPronunciationAssessment {
  const AzureWordPronunciationAssessment({
    required this.accuracyScore,
    required this.errorType,
  });

  @JsonKey(name: 'AccuracyScore', fromJson: _azureJsonDoubleScore)
  final double accuracyScore;

  @JsonKey(name: 'ErrorType', fromJson: _azureJsonErrorType)
  final String errorType;

  factory AzureWordPronunciationAssessment.fromJson(
    Map<String, dynamic> json,
  ) => _$AzureWordPronunciationAssessmentFromJson(json);
}

@JsonSerializable(createToJson: false)
final class AzureSyllableAssessment {
  const AzureSyllableAssessment({
    required this.syllable,
    required this.offset,
    required this.duration,
    required this.pronunciationAssessment,
    this.phonemes,
  });

  @JsonKey(name: 'Syllable', fromJson: _azureJsonString)
  final String syllable;

  @JsonKey(name: 'Offset', fromJson: _azureJsonIntTick)
  final int offset;

  @JsonKey(name: 'Duration', fromJson: _azureJsonIntTick)
  final int duration;

  @JsonKey(
    name: 'PronunciationAssessment',
    fromJson: _azureJsonSyllablePronunciation,
  )
  final AzureSyllablePronunciationAssessment pronunciationAssessment;

  @JsonKey(name: 'Phonemes')
  final List<AzurePhonemeAssessment>? phonemes;

  factory AzureSyllableAssessment.fromJson(Map<String, dynamic> json) =>
      _$AzureSyllableAssessmentFromJson(json);
}

@JsonSerializable(createToJson: false)
final class AzureSyllablePronunciationAssessment {
  const AzureSyllablePronunciationAssessment({required this.accuracyScore});

  @JsonKey(name: 'AccuracyScore', fromJson: _azureJsonDoubleScore)
  final double accuracyScore;

  factory AzureSyllablePronunciationAssessment.fromJson(
    Map<String, dynamic> json,
  ) => _$AzureSyllablePronunciationAssessmentFromJson(json);
}

@JsonSerializable(createToJson: false)
final class AzurePhonemeAssessment {
  const AzurePhonemeAssessment({
    required this.phoneme,
    required this.offset,
    required this.duration,
    required this.pronunciationAssessment,
  });

  @JsonKey(name: 'Phoneme', fromJson: _azureJsonString)
  final String phoneme;

  @JsonKey(name: 'Offset', fromJson: _azureJsonIntTick)
  final int offset;

  @JsonKey(name: 'Duration', fromJson: _azureJsonIntTick)
  final int duration;

  @JsonKey(
    name: 'PronunciationAssessment',
    fromJson: _azureJsonPhonemePronunciation,
  )
  final AzurePhonemePronunciationAssessment pronunciationAssessment;

  factory AzurePhonemeAssessment.fromJson(Map<String, dynamic> json) =>
      _$AzurePhonemeAssessmentFromJson(json);
}

@JsonSerializable(createToJson: false)
final class AzurePhonemePronunciationAssessment {
  const AzurePhonemePronunciationAssessment({
    required this.accuracyScore,
    this.nBestPhonemes,
  });

  @JsonKey(name: 'AccuracyScore', fromJson: _azureJsonDoubleScore)
  final double accuracyScore;

  @JsonKey(name: 'NBestPhonemes')
  final List<AzureNBestPhoneme>? nBestPhonemes;

  factory AzurePhonemePronunciationAssessment.fromJson(
    Map<String, dynamic> json,
  ) => _$AzurePhonemePronunciationAssessmentFromJson(json);
}

@JsonSerializable(createToJson: false)
final class AzureNBestPhoneme {
  const AzureNBestPhoneme({required this.phoneme, required this.score});

  @JsonKey(name: 'Phoneme', fromJson: _azureJsonString)
  final String phoneme;

  @JsonKey(name: 'Score', fromJson: _azureJsonDoubleScore)
  final double score;

  factory AzureNBestPhoneme.fromJson(Map<String, dynamic> json) =>
      _$AzureNBestPhonemeFromJson(json);
}
