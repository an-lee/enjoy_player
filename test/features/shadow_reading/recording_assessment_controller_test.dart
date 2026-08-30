import 'dart:convert';
import 'dart:io';

import 'package:azure_speech/azure_speech.dart';
import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/features/ai/application/ai_capability_providers.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/assessment_capability.dart';
import 'package:enjoy_player/features/ai/domain/models/assessment_request.dart';
import 'package:enjoy_player/features/ai/domain/models/assessment_result.dart';
import 'package:enjoy_player/features/shadow_reading/application/recording_assessment_controller.dart';
import 'package:enjoy_player/features/sync/application/sync_providers.dart';
import 'package:enjoy_player/features/sync/domain/sync_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

const _kAssessmentJson = '''
{
  "RecognitionStatus": "Success",
  "Offset": 0,
  "Duration": 10000000,
  "DisplayText": "Hi.",
  "NBest": [
    {
      "Confidence": 0.9,
      "Lexical": "hi",
      "ITN": "hi",
      "MaskedITN": "hi",
      "Display": "Hi.",
      "PronunciationAssessment": {
        "AccuracyScore": 90,
        "FluencyScore": 88,
        "CompletenessScore": 95,
        "PronScore": 91,
        "ProsodyScore": 80
      },
      "Words": [
        {
          "Word": "hi",
          "Offset": 0,
          "Duration": 10000000,
          "PronunciationAssessment": {
            "AccuracyScore": 92,
            "ErrorType": "None"
          }
        }
      ]
    }
  ]
}''';

final class _FakeAssessmentCapability implements AssessmentCapability {
  String? lastLanguage;

  @override
  Future<AssessmentResult> assess(AssessmentRequest request) async {
    lastLanguage = request.language;
    final map = jsonDecode(_kAssessmentJson) as Map<String, dynamic>;
    final detail = AzurePronunciationAssessmentResult.fromJson(map);
    return AssessmentResult(detail: detail, rawJson: map);
  }
}

/// Always rejected as credits-exhausted (the /azure/tokens 402 path).
final class _CreditsExhaustedCapability implements AssessmentCapability {
  @override
  Future<AssessmentResult> assess(AssessmentRequest request) async =>
      throw const CreditsFailure(
        'HTTP 402',
        requiredCredits: 1500,
        usedCredits: 0,
        limitCredits: 1000,
      );
}

void main() {
  test('RecordingAssessmentController persists score and JSON', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);

    final wav = File(
      '${Directory.systemTemp.path}/rec_assess_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await wav.writeAsBytes(List<int>.filled(120, 7));

    final id = const Uuid().v4();
    final now = DateTime.now();
    await db.recordingDao.insertRow(
      RecordingRow(
        id: id,
        targetType: 'Audio',
        targetId: 'm1',
        referenceStart: 0,
        referenceDuration: 5000,
        referenceText: 'Hi there',
        language: 'en',
        duration: 1000,
        md5: null,
        audioUrl: null,
        pronunciationScore: null,
        assessmentJson: null,
        localPath: wav.path,
        syncStatus: 'local',
        serverUpdatedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    var enqueued = 0;
    final fake = _FakeAssessmentCapability();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        assessmentCapabilityProvider.overrideWithValue(fake),
        syncEnqueueProvider.overrideWithValue((type, entityId, action) async {
          expect(type, SyncEntityType.recording);
          expect(entityId, id);
          expect(action, SyncAction.update);
          enqueued++;
        }),
      ],
    );
    addTearDown(container.dispose);

    final row = await db.recordingDao.getById(id);
    expect(row, isNotNull);

    final notifier = container.read(
      recordingAssessmentControllerProvider(id).notifier,
    );
    final outcome = await notifier.run(row!);

    expect(outcome, isA<RecordingAssessmentSuccess>());
    expect(enqueued, 1);
    expect(fake.lastLanguage, 'en-US');

    final updated = await db.recordingDao.getById(id);
    expect(updated!.pronunciationScore, 91);
    expect(updated.assessmentJson, isNotNull);
    expect(updated.assessmentJson, contains('PronScore'));
  });

  test('und recording language falls back to default learning locale', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);

    final wav = File(
      '${Directory.systemTemp.path}/rec_assess_und_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await wav.writeAsBytes(List<int>.filled(120, 7));

    final id = const Uuid().v4();
    final now = DateTime.now();
    await db.recordingDao.insertRow(
      RecordingRow(
        id: id,
        targetType: 'Video',
        targetId: 'yt1',
        referenceStart: 0,
        referenceDuration: 5000,
        referenceText: 'Hi there',
        language: 'und',
        duration: 1000,
        md5: null,
        audioUrl: null,
        pronunciationScore: null,
        assessmentJson: null,
        localPath: wav.path,
        syncStatus: 'local',
        serverUpdatedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final fake = _FakeAssessmentCapability();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        assessmentCapabilityProvider.overrideWithValue(fake),
        syncEnqueueProvider.overrideWithValue(
          (type, entityId, action) async {},
        ),
      ],
    );
    addTearDown(container.dispose);

    final row = (await db.recordingDao.getById(id))!;
    final outcome = await container
        .read(recordingAssessmentControllerProvider(id).notifier)
        .run(row);

    expect(outcome, isA<RecordingAssessmentSuccess>());
    // YouTube-style und must not hard-fail; default learning locale is en-US.
    expect(fake.lastLanguage, 'en-US');
  });

  test(
    'credits rejection maps to the credits kind carrying the envelope',
    () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);

      final wav = File(
        '${Directory.systemTemp.path}/rec_assess_credits_${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      await wav.writeAsBytes(List<int>.filled(120, 7));

      final id = const Uuid().v4();
      final now = DateTime.now();
      await db.recordingDao.insertRow(
        RecordingRow(
          id: id,
          targetType: 'Audio',
          targetId: 'm2',
          referenceStart: 0,
          referenceDuration: 5000,
          referenceText: 'Hi there',
          language: 'en',
          duration: 1000,
          md5: null,
          audioUrl: null,
          pronunciationScore: null,
          assessmentJson: null,
          localPath: wav.path,
          syncStatus: 'local',
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          assessmentCapabilityProvider.overrideWithValue(
            _CreditsExhaustedCapability(),
          ),
          syncEnqueueProvider.overrideWithValue(
            (type, entityId, action) async {},
          ),
        ],
      );
      addTearDown(container.dispose);

      final row = (await db.recordingDao.getById(id))!;
      final outcome = await container
          .read(recordingAssessmentControllerProvider(id).notifier)
          .run(row);

      expect(outcome, isA<RecordingAssessmentFailure>());
      final failure = outcome as RecordingAssessmentFailure;
      expect(failure.kind, RecordingAssessmentFailureKind.credits);
      expect(failure.debugMessage, isNull, reason: 'no raw status leak');
      expect(failure.creditsFailure?.requiredCredits, 1500);
      expect(failure.creditsFailure?.remainingCredits, 1000);
    },
  );
}
