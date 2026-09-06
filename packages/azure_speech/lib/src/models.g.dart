// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AzurePronunciationAssessmentResult _$AzurePronunciationAssessmentResultFromJson(
  Map<String, dynamic> json,
) => AzurePronunciationAssessmentResult(
  recognitionStatus: _azureJsonString(json['RecognitionStatus']),
  offset: _azureJsonIntTick(json['Offset']),
  duration: _azureJsonIntTick(json['Duration']),
  displayText: _azureJsonString(json['DisplayText']),
  nBest: _azureJsonNBestList(json['NBest']),
);

AzureNBestResult _$AzureNBestResultFromJson(Map<String, dynamic> json) =>
    AzureNBestResult(
      confidence: _azureJsonDoubleScore(json['Confidence']),
      lexical: _azureJsonString(json['Lexical']),
      itn: _azureJsonString(json['ITN']),
      maskedItn: _azureJsonString(json['MaskedITN']),
      display: _azureJsonString(json['Display']),
      pronunciationAssessment: _azureJsonPronunciationScores(
        json['PronunciationAssessment'],
      ),
      words: _azureJsonWordsList(json['Words']),
    );

AzurePronunciationAssessmentScores _$AzurePronunciationAssessmentScoresFromJson(
  Map<String, dynamic> json,
) => AzurePronunciationAssessmentScores(
  accuracyScore: _azureJsonDoubleScore(json['AccuracyScore']),
  fluencyScore: _azureJsonDoubleScore(json['FluencyScore']),
  completenessScore: _azureJsonDoubleScore(json['CompletenessScore']),
  pronScore: _azureJsonDoubleScore(json['PronScore']),
  prosodyScore: _azureJsonDoubleScoreOpt(json['ProsodyScore']),
);

AzureWordAssessment _$AzureWordAssessmentFromJson(
  Map<String, dynamic> json,
) => AzureWordAssessment(
  word: _azureJsonString(json['Word']),
  offset: _azureJsonIntTick(json['Offset']),
  duration: _azureJsonIntTick(json['Duration']),
  pronunciationAssessment: _azureJsonWordPronunciation(
    json['PronunciationAssessment'],
  ),
  syllables: (json['Syllables'] as List<dynamic>?)
      ?.map((e) => AzureSyllableAssessment.fromJson(e as Map<String, dynamic>))
      .toList(),
  phonemes: (json['Phonemes'] as List<dynamic>?)
      ?.map((e) => AzurePhonemeAssessment.fromJson(e as Map<String, dynamic>))
      .toList(),
);

AzureWordPronunciationAssessment _$AzureWordPronunciationAssessmentFromJson(
  Map<String, dynamic> json,
) => AzureWordPronunciationAssessment(
  accuracyScore: _azureJsonDoubleScore(json['AccuracyScore']),
  errorType: _azureJsonErrorType(json['ErrorType']),
);

AzureSyllableAssessment _$AzureSyllableAssessmentFromJson(
  Map<String, dynamic> json,
) => AzureSyllableAssessment(
  syllable: _azureJsonString(json['Syllable']),
  offset: _azureJsonIntTick(json['Offset']),
  duration: _azureJsonIntTick(json['Duration']),
  pronunciationAssessment: _azureJsonSyllablePronunciation(
    json['PronunciationAssessment'],
  ),
  phonemes: (json['Phonemes'] as List<dynamic>?)
      ?.map((e) => AzurePhonemeAssessment.fromJson(e as Map<String, dynamic>))
      .toList(),
);

AzureSyllablePronunciationAssessment
_$AzureSyllablePronunciationAssessmentFromJson(Map<String, dynamic> json) =>
    AzureSyllablePronunciationAssessment(
      accuracyScore: _azureJsonDoubleScore(json['AccuracyScore']),
    );

AzurePhonemeAssessment _$AzurePhonemeAssessmentFromJson(
  Map<String, dynamic> json,
) => AzurePhonemeAssessment(
  phoneme: _azureJsonString(json['Phoneme']),
  offset: _azureJsonIntTick(json['Offset']),
  duration: _azureJsonIntTick(json['Duration']),
  pronunciationAssessment: _azureJsonPhonemePronunciation(
    json['PronunciationAssessment'],
  ),
);

AzurePhonemePronunciationAssessment
_$AzurePhonemePronunciationAssessmentFromJson(Map<String, dynamic> json) =>
    AzurePhonemePronunciationAssessment(
      accuracyScore: _azureJsonDoubleScore(json['AccuracyScore']),
      nBestPhonemes: (json['NBestPhonemes'] as List<dynamic>?)
          ?.map((e) => AzureNBestPhoneme.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

AzureNBestPhoneme _$AzureNBestPhonemeFromJson(Map<String, dynamic> json) =>
    AzureNBestPhoneme(
      phoneme: _azureJsonString(json['Phoneme']),
      score: _azureJsonDoubleScore(json['Score']),
    );
