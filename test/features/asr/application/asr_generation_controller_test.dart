import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/ai/application/ai_capability_providers.dart';
import 'package:enjoy_player/features/ai/domain/byok_not_configured_failure.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/asr_capability.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_request.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_result.dart';
import 'package:enjoy_player/features/ai/domain/modality_kind.dart';
import 'package:enjoy_player/features/asr/application/asr_generation_controller.dart';
import 'package:enjoy_player/features/asr/application/asr_generation_job.dart';
import 'package:enjoy_player/features/asr/data/asr_audio_extractor.dart';
import 'package:enjoy_player/features/transcript/application/transcript_repository_provider.dart';

void main() {
  late AppDatabase db;
  late TranscriptRepository repo;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = TranscriptRepository(db);
    tempDir = await Directory.systemTemp.createTemp('asr_controller_test_');
    final now = DateTime.utc(2026);
    await db.audioDao.insertRow(
      AudioRow(
        id: 'audio-1',
        aid: 'aid-1',
        provider: 'user',
        title: 'Audio',
        description: null,
        thumbnailUrl: null,
        durationSeconds: 10,
        language: 'es',
        translationKey: null,
        sourceText: null,
        voice: null,
        source: null,
        localUri: 'file://${tempDir.path}/audio.wav',
        md5: null,
        size: 3,
        mediaUrl: null,
        syncStatus: null,
        serverUpdatedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  ProviderContainer containerFor(AsrCapability capability) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        transcriptRepositoryProvider.overrideWithValue(repo),
        asrCapabilityProvider.overrideWithValue(capability),
      ],
    );
  }

  test(
    'persists detected language and makes the generated track primary',
    () async {
      final source = File('${tempDir.path}/audio.wav')
        ..writeAsBytesSync([1, 2, 3]);
      final container = containerFor(
        const _ResultAsrCapability(
          AsrResult(
            text: 'Hello.',
            language: 'en',
            segments: [AsrSegment(start: 0, end: 1, text: 'Hello.')],
          ),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(asrGenerationControllerProvider('audio-1').notifier)
          .generateTranscript(
            mediaSourceUri: source.path,
            kind: MediaKind.audio,
          );

      final job = container
          .read(asrGenerationControllerProvider('audio-1'))
          .valueOrNull;
      final rows = await db.transcriptDao.listForTarget('Audio', 'audio-1');
      final session = await db.echoSessionDao.getLatestForTarget(
        'Audio',
        'audio-1',
      );
      expect(job?.phase, AsrGenerationPhase.success);
      expect(job?.language, 'en');
      expect(rows.single.language, 'en');
      expect(session?.transcriptId, rows.single.id);
      expect((await db.audioDao.getById('audio-1'))?.language, 'en');
    },
  );

  test('forwards media duration to the ASR request', () async {
    final source = File('${tempDir.path}/audio.wav')
      ..writeAsBytesSync([1, 2, 3]);
    final capability = _RecordingAsrCapability(
      const AsrResult(text: 'Hola.', language: 'es'),
    );
    final container = containerFor(capability);
    addTearDown(container.dispose);

    await container
        .read(asrGenerationControllerProvider('audio-1').notifier)
        .generateTranscript(mediaSourceUri: source.path, kind: MediaKind.audio);

    expect(capability.lastRequest, isNotNull);
    expect(capability.lastRequest!.durationSeconds, 10.0);
  });

  test(
    'maps an empty recognition result to no-speech without persistence',
    () async {
      final source = File('${tempDir.path}/audio.wav')
        ..writeAsBytesSync([1, 2, 3]);
      final container = containerFor(
        const _ResultAsrCapability(AsrResult(text: '')),
      );
      addTearDown(container.dispose);

      await container
          .read(asrGenerationControllerProvider('audio-1').notifier)
          .generateTranscript(
            mediaSourceUri: source.path,
            kind: MediaKind.audio,
          );

      final job = container
          .read(asrGenerationControllerProvider('audio-1'))
          .valueOrNull;
      expect(job?.phase, AsrGenerationPhase.error);
      expect(job?.errorMessage, 'asrErrorNoSpeech');
      expect(await db.transcriptDao.listForTarget('Audio', 'audio-1'), isEmpty);
    },
  );

  test('maps missing BYOK configuration to a friendly error', () async {
    final source = File('${tempDir.path}/audio.wav')
      ..writeAsBytesSync([1, 2, 3]);
    final container = containerFor(_ByokFailureAsrCapability());
    addTearDown(container.dispose);

    await container
        .read(asrGenerationControllerProvider('audio-1').notifier)
        .generateTranscript(mediaSourceUri: source.path, kind: MediaKind.audio);

    expect(
      container
          .read(asrGenerationControllerProvider('audio-1'))
          .valueOrNull
          ?.errorMessage,
      'asrErrorByokMissing',
    );
  });

  test('maps CreditsFailure to asrErrorCreditsExhausted', () async {
    final source = File('${tempDir.path}/audio.wav')
      ..writeAsBytesSync([1, 2, 3]);
    final container = containerFor(
      _ThrowingAsrCapability(const CreditsFailure('Daily limit reached')),
    );
    addTearDown(container.dispose);

    await container
        .read(asrGenerationControllerProvider('audio-1').notifier)
        .generateTranscript(mediaSourceUri: source.path, kind: MediaKind.audio);

    expect(
      container
          .read(asrGenerationControllerProvider('audio-1'))
          .valueOrNull
          ?.errorMessage,
      'asrErrorCreditsExhausted',
    );
  });

  test('carries the CreditsFailure on the job for the launcher CTA', () async {
    final source = File('${tempDir.path}/audio.wav')
      ..writeAsBytesSync([1, 2, 3]);
    final failure = const CreditsFailure(
      'HTTP 402',
      requiredCredits: 1200,
      usedCredits: 400,
      limitCredits: 1000,
    );
    final container = containerFor(_ThrowingAsrCapability(failure));
    addTearDown(container.dispose);

    await container
        .read(asrGenerationControllerProvider('audio-1').notifier)
        .generateTranscript(mediaSourceUri: source.path, kind: MediaKind.audio);

    final job = container
        .read(asrGenerationControllerProvider('audio-1'))
        .valueOrNull;
    expect(job?.creditsFailure, same(failure));
    expect(job?.creditsFailure?.remainingCredits, 600);
  });

  test('maps NetworkFailure to asrErrorNetwork', () async {
    final source = File('${tempDir.path}/audio.wav')
      ..writeAsBytesSync([1, 2, 3]);
    final container = containerFor(
      _ThrowingAsrCapability(const NetworkFailure('timeout')),
    );
    addTearDown(container.dispose);

    await container
        .read(asrGenerationControllerProvider('audio-1').notifier)
        .generateTranscript(mediaSourceUri: source.path, kind: MediaKind.audio);

    expect(
      container
          .read(asrGenerationControllerProvider('audio-1'))
          .valueOrNull
          ?.errorMessage,
      'asrErrorNetwork',
    );
  });

  test('uses an explicit language when ASR does not detect one', () async {
    final source = File('${tempDir.path}/audio.wav')
      ..writeAsBytesSync([1, 2, 3]);
    final container = containerFor(
      const _ResultAsrCapability(AsrResult(text: 'Bonjour.')),
    );
    addTearDown(container.dispose);

    await container
        .read(asrGenerationControllerProvider('audio-1').notifier)
        .generateTranscript(
          mediaSourceUri: source.path,
          kind: MediaKind.audio,
          language: 'fr',
        );

    final rows = await db.transcriptDao.listForTarget('Audio', 'audio-1');
    expect(rows.single.language, 'fr');
    expect((await db.audioDao.getById('audio-1'))?.language, 'es');
  });
}

final class _ResultAsrCapability implements AsrCapability {
  const _ResultAsrCapability(this.result);

  final AsrResult result;

  @override
  Future<AsrResult> transcribe(AsrRequest request) async => result;
}

final class _RecordingAsrCapability implements AsrCapability {
  _RecordingAsrCapability(this.result);

  final AsrResult result;
  AsrRequest? lastRequest;

  @override
  Future<AsrResult> transcribe(AsrRequest request) async {
    lastRequest = request;
    return result;
  }
}

final class _ByokFailureAsrCapability implements AsrCapability {
  @override
  Future<AsrResult> transcribe(AsrRequest request) {
    throw const ByokNotConfiguredFailure(ModalityKind.asr);
  }
}

final class _ThrowingAsrCapability implements AsrCapability {
  _ThrowingAsrCapability(this.error);

  final Object error;

  @override
  Future<AsrResult> transcribe(AsrRequest request) {
    throw error;
  }
}
