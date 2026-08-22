// ignore_for_file: scoped_providers_should_specify_dependencies
import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/ids/enjoy_ids.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/ai/application/ai_capability_providers.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/translation_capability.dart';
import 'package:enjoy_player/features/ai/domain/models/translation_result.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/transcript/application/auto_translate_controller.dart';
import 'package:enjoy_player/features/transcript/application/transcript_playback_highlight_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_repository_provider.dart';
import 'package:enjoy_player/features/transcript/domain/auto_translate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTranslation implements TranslationCapability {
  final calls = <String>[];
  final _delays = <Completer<void>>[];

  Completer<void> delayNext() {
    final c = Completer<void>();
    _delays.add(c);
    return c;
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    bool? forceRefresh,
  }) async {
    calls.add(text);
    if (_delays.isNotEmpty) {
      await _delays.removeAt(0).future;
    }
    return TranslationResult(
      translatedText: 'ZH:$text',
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }
}

class _SignedInAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'u1', email: 't@example.com', name: 'Test'),
  );
}

class _ZhNativePrefsCtrl extends AppPreferencesCtrl {
  @override
  Future<AppPreferencesState> build() async => AppPreferencesState.initial
      .copyWith(nativeLanguage: 'zh-CN', learningLanguage: 'en-US');
}

void main() {
  group('AutoTranslateCtrl requestTranslateLine', () {
    late AppDatabase db;
    late TranscriptRepository repo;
    late _FakeTranslation fake;
    late ProviderContainer container;
    const mediaId = 'media-at-req';

    Future<void> seedPrimary() async {
      final now = DateTime.now();
      await db.videoDao.insertRow(
        VideoRow(
          id: mediaId,
          vid: 'vid12345678',
          provider: 'user',
          title: 'Test',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 60,
          language: 'en',
          source: 'local',
          localUri: '/tmp/test.mp4',
          md5: null,
          size: null,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final primaryId = enjoyTranscriptId(
        targetType: 'Video',
        targetId: mediaId,
        language: 'en',
        source: 'user',
      );
      const lines = [
        TranscriptLine(text: 'Hello', startMs: 0, durationMs: 1000),
        TranscriptLine(text: 'World', startMs: 1000, durationMs: 500),
        TranscriptLine(text: 'Again', startMs: 1500, durationMs: 500),
      ];
      await db.transcriptDao.upsert(
        TranscriptRow(
          id: primaryId,
          targetType: 'Video',
          targetId: mediaId,
          language: 'en',
          source: 'user',
          timelineJson: jsonEncode(lines.map((e) => e.toJson()).toList()),
          referenceId: null,
          label: 'English',
          trackIndex: null,
          syncStatus: 'local',
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.echoSessionDao.updatePrimaryTranscriptForTarget(
        'Video',
        mediaId,
        primaryId,
      );
    }

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
      fake = _FakeTranslation();
      await seedPrimary();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          transcriptRepositoryProvider.overrideWithValue(repo),
          translationCapabilityProvider.overrideWithValue(fake),
          authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
          appPreferencesCtrlProvider.overrideWith(_ZhNativePrefsCtrl.new),
        ],
      );
      await container.read(authCtrlProvider.future);
      await container.read(appPreferencesCtrlProvider.future);
    });

    tearDown(() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      container.dispose();
      await db.close();
    });

    test('select then request translates once and caches', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.status, AutoTranslateStatus.active);
      expect(state.aiTranscriptId, isNotNull);

      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fake.calls, ['Hello']);
      final aiRow = await repo.transcriptRowById(state.aiTranscriptId!);
      final cue = repo.linesForRow(aiRow!)[0];
      expect(cue.text, 'ZH:Hello');
      expect(
        cue.sourceKey,
        autoTranslateSourceKey(
          primaryText: 'Hello',
          sourceLanguage: 'en',
          targetLanguage: 'zh-CN',
        ),
      );

      // Second request is a no-op (cached).
      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls, ['Hello']);
    });

    test('reuses same-key translation without a second API call', () async {
      // Fresh media with two identical primary cues.
      const mediaDup = 'media-at-dup';
      final now = DateTime.now();
      await db.videoDao.insertRow(
        VideoRow(
          id: mediaDup,
          vid: 'vid87654321',
          provider: 'user',
          title: 'Dup',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 60,
          language: 'en',
          source: 'local',
          localUri: '/tmp/dup.mp4',
          md5: null,
          size: null,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final primaryId = enjoyTranscriptId(
        targetType: 'Video',
        targetId: mediaDup,
        language: 'en',
        source: 'user',
      );
      const lines = [
        TranscriptLine(text: 'Hello', startMs: 0, durationMs: 1000),
        TranscriptLine(text: 'Hello', startMs: 1000, durationMs: 500),
      ];
      await db.transcriptDao.upsert(
        TranscriptRow(
          id: primaryId,
          targetType: 'Video',
          targetId: mediaDup,
          language: 'en',
          source: 'user',
          timelineJson: jsonEncode(lines.map((e) => e.toJson()).toList()),
          referenceId: null,
          label: 'English',
          trackIndex: null,
          syncStatus: 'local',
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.echoSessionDao.updatePrimaryTranscriptForTarget(
        'Video',
        mediaDup,
        primaryId,
      );

      final ctrl = container.read(autoTranslateCtrlProvider(mediaDup).notifier);
      await ctrl.selectAutoTranslate();

      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls, ['Hello']);

      ctrl.requestTranslateLine(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls, ['Hello']);

      final aiId = container
          .read(autoTranslateCtrlProvider(mediaDup))
          .aiTranscriptId!;
      final aiLines = repo.linesForRow((await repo.transcriptRowById(aiId))!);
      expect(aiLines[0].text, 'ZH:Hello');
      expect(aiLines[1].text, 'ZH:Hello');
      expect(aiLines[0].sourceKey, aiLines[1].sourceKey);
    });

    test('soft-stale key mismatch re-requests translation', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();
      final state = container.read(autoTranslateCtrlProvider(mediaId));
      final aiId = state.aiTranscriptId!;

      final staleKey = autoTranslateSourceKey(
        primaryText: 'Old Hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh-CN',
      );
      await repo.updateAutoTranslateLineText(
        aiTranscriptId: aiId,
        lineIndex: 0,
        text: '旧翻译',
        sourceKey: staleKey,
      );

      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls, ['Hello']);
      final cue = repo.linesForRow((await repo.transcriptRowById(aiId))!)[0];
      expect(cue.text, 'ZH:Hello');
      expect(
        cue.sourceKey,
        autoTranslateSourceKey(
          primaryText: 'Hello',
          sourceLanguage: 'en',
          targetLanguage: 'zh-CN',
        ),
      );
    });

    test('in-flight dedupe does not double-call', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();
      final gate = fake.delayNext();

      ctrl.requestTranslateLine(0);
      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(Duration.zero);
      expect(fake.calls, ['Hello']);

      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls, ['Hello']);
    });

    test('concurrency never exceeds two', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();
      final g0 = fake.delayNext();
      final g1 = fake.delayNext();
      final g2 = fake.delayNext();

      ctrl.requestTranslateLine(0);
      ctrl.requestTranslateLine(1);
      ctrl.requestTranslateLine(2);
      await Future<void>.delayed(Duration.zero);

      expect(fake.calls.length, 2);
      expect(
        container
            .read(autoTranslateCtrlProvider(mediaId))
            .inFlightIndexes
            .length,
        2,
      );

      g0.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls.length, 3);

      g1.complete();
      g2.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('waiting queue prefers lines near playback highlight', () async {
      // Highlight already at mid cue: early in-flight work may start, but the
      // waiting queue should drain the viewport line next.
      container.dispose();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          transcriptRepositoryProvider.overrideWithValue(repo),
          translationCapabilityProvider.overrideWithValue(fake),
          authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
          appPreferencesCtrlProvider.overrideWith(_ZhNativePrefsCtrl.new),
          transcriptPlaybackHighlightProvider(
            mediaId,
          ).overrideWithValue((cueIndex: 2, wordIndex: null)),
        ],
      );
      await container.read(authCtrlProvider.future);
      await container.read(appPreferencesCtrlProvider.future);

      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();
      final g0 = fake.delayNext();
      final g1 = fake.delayNext();
      final g2 = fake.delayNext();

      ctrl.requestTranslateLine(0);
      ctrl.requestTranslateLine(1);
      await Future<void>.delayed(Duration.zero);
      expect(fake.calls, ['Hello', 'World']);

      ctrl.requestTranslateLine(2);
      g0.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls.last, 'Again');

      g1.complete();
      g2.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
}
