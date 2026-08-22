// ignore_for_file: scoped_providers_should_specify_dependencies
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/errors/app_failure.dart';
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
import 'package:enjoy_player/features/transcript/application/active_transcript_provider.dart';
import 'package:enjoy_player/features/transcript/application/auto_translate_controller.dart';
import 'package:enjoy_player/features/transcript/application/transcript_playback_highlight_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_repository_provider.dart';
import 'package:enjoy_player/features/transcript/domain/auto_translate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTranslation implements TranslationCapability {
  final calls = <String>[];
  final _delays = <Completer<void>>[];
  Exception? errorToThrow;
  int errorCount = 0;

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
    if (errorToThrow != null && errorCount > 0) {
      errorCount--;
      throw errorToThrow!;
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

class _SignedOutAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

class _ZhNativePrefsCtrl extends AppPreferencesCtrl {
  @override
  Future<AppPreferencesState> build() async => AppPreferencesState.initial
      .copyWith(nativeLanguage: 'zh-CN', learningLanguage: 'en-US');
}

void main() {
  group('AutoTranslateCtrl selectAutoTranslate error paths', () {
    late AppDatabase db;
    late TranscriptRepository repo;
    late _FakeTranslation fake;
    late ProviderContainer container;
    const mediaId = 'media-sel-err';

    Future<void> seedPrimary({
      String id = mediaId,
      String language = 'en',
      List<TranscriptLine>? lines,
    }) async {
      final now = DateTime.now();
      await db.videoDao.insertRow(
        VideoRow(
          id: id,
          vid: 'vid12345678',
          provider: 'user',
          title: 'Test',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 60,
          language: language,
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
        targetId: id,
        language: language,
        source: 'user',
      );
      final effectiveLines =
          lines ??
          const [
            TranscriptLine(text: 'Hello', startMs: 0, durationMs: 1000),
            TranscriptLine(text: 'World', startMs: 1000, durationMs: 500),
          ];
      await db.transcriptDao.upsert(
        TranscriptRow(
          id: primaryId,
          targetType: 'Video',
          targetId: id,
          language: language,
          source: 'user',
          timelineJson: jsonEncode(
            effectiveLines.map((e) => e.toJson()).toList(),
          ),
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
        id,
        primaryId,
      );
    }

    ProviderContainer buildContainer({
      AuthCtrl Function() authOverride = _SignedInAuthCtrl.new,
      AppPreferencesCtrl Function() prefsOverride = _ZhNativePrefsCtrl.new,
    }) {
      return ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          transcriptRepositoryProvider.overrideWithValue(repo),
          translationCapabilityProvider.overrideWithValue(fake),
          authCtrlProvider.overrideWith(authOverride),
          appPreferencesCtrlProvider.overrideWith(prefsOverride),
        ],
      );
    }

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
      fake = _FakeTranslation();
    });

    tearDown(() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      container.dispose();
      await db.close();
    });

    test('blocks with signedOut when not authenticated', () async {
      await seedPrimary();
      container = buildContainer(authOverride: _SignedOutAuthCtrl.new);
      await container.read(authCtrlProvider.future);
      await container.read(appPreferencesCtrlProvider.future);

      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.status, AutoTranslateStatus.blocked);
      expect(state.blockReason, AutoTranslateBlockReason.signedOut);
    });

    test(
      'blocks with noPrimary when no primary transcript row exists',
      () async {
        const noPrimaryMedia = 'media-no-primary';
        final now = DateTime.now();
        await db.videoDao.insertRow(
          VideoRow(
            id: noPrimaryMedia,
            vid: 'vid00000000',
            provider: 'user',
            title: 'No Primary',
            description: null,
            thumbnailUrl: null,
            durationSeconds: 60,
            language: 'en',
            source: 'local',
            localUri: '/tmp/noprimary.mp4',
            md5: null,
            size: null,
            mediaUrl: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
        container = buildContainer();
        await container.read(authCtrlProvider.future);
        await container.read(appPreferencesCtrlProvider.future);

        final ctrl = container.read(
          autoTranslateCtrlProvider(noPrimaryMedia).notifier,
        );
        await ctrl.selectAutoTranslate();

        final state = container.read(autoTranslateCtrlProvider(noPrimaryMedia));
        expect(state.status, AutoTranslateStatus.blocked);
        expect(state.blockReason, AutoTranslateBlockReason.noPrimary);
      },
    );

    test('blocks with noPrimary when primary lines are empty', () async {
      const emptyMedia = 'media-empty-lines';
      await seedPrimary(id: emptyMedia, lines: const []);
      container = buildContainer();
      await container.read(authCtrlProvider.future);
      await container.read(appPreferencesCtrlProvider.future);

      final ctrl = container.read(
        autoTranslateCtrlProvider(emptyMedia).notifier,
      );
      await ctrl.selectAutoTranslate();

      final state = container.read(autoTranslateCtrlProvider(emptyMedia));
      expect(state.status, AutoTranslateStatus.blocked);
      expect(state.blockReason, AutoTranslateBlockReason.noPrimary);
    });

    test('blocks with sameLanguage when source equals target', () async {
      const sameMedia = 'media-same-lang';
      await seedPrimary(id: sameMedia, language: 'zh-CN');
      container = buildContainer();
      await container.read(authCtrlProvider.future);
      await container.read(appPreferencesCtrlProvider.future);

      final ctrl = container.read(
        autoTranslateCtrlProvider(sameMedia).notifier,
      );
      await ctrl.selectAutoTranslate();

      final state = container.read(autoTranslateCtrlProvider(sameMedia));
      expect(state.status, AutoTranslateStatus.blocked);
      expect(state.blockReason, AutoTranslateBlockReason.sameLanguage);
    });

    test('successful select sets active state with correct fields', () async {
      await seedPrimary();
      container = buildContainer();
      await container.read(authCtrlProvider.future);
      await container.read(appPreferencesCtrlProvider.future);

      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.status, AutoTranslateStatus.active);
      expect(state.blockReason, isNull);
      expect(state.aiTranscriptId, isNotNull);
      expect(state.primaryTranscriptId, isNotNull);
      expect(state.sourceLanguage, 'en');
      expect(state.targetLanguage, 'zh-CN');
    });
  });

  group('AutoTranslateCtrl requestTranslateLine guards', () {
    late AppDatabase db;
    late TranscriptRepository repo;
    late _FakeTranslation fake;
    late ProviderContainer container;
    const mediaId = 'media-guard';

    Future<void> seedAndActivate() async {
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

      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();
    }

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
      fake = _FakeTranslation();
      await seedAndActivate();
    });

    tearDown(() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      container.dispose();
      await db.close();
    });

    test('ignores negative line index', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      ctrl.requestTranslateLine(-1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls, isEmpty);
    });

    test('ignores request when status is not active', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      final state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.status, AutoTranslateStatus.active);

      await db.echoSessionDao.updateSecondaryTranscriptForTarget(
        'Video',
        mediaId,
        'some-other-id',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final updatedState = container.read(autoTranslateCtrlProvider(mediaId));
      if (updatedState.status != AutoTranslateStatus.active) {
        ctrl.requestTranslateLine(0);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(fake.calls, isEmpty);
      }
    });

    test('skips line already marked as failed', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      fake.errorToThrow = Exception('fail');
      fake.errorCount = 999;

      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final stateAfterFail = container.read(autoTranslateCtrlProvider(mediaId));
      expect(stateAfterFail.failedLineIndexes, contains(0));

      final callsBefore = fake.calls.length;
      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls.length, callsBefore);
    });
  });

  group('AutoTranslateCtrl retranslateLine', () {
    late AppDatabase db;
    late TranscriptRepository repo;
    late _FakeTranslation fake;
    late ProviderContainer container;
    const mediaId = 'media-retranslate';

    Future<void> seedAndActivate() async {
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

      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();
    }

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
      fake = _FakeTranslation();
      await seedAndActivate();
    });

    tearDown(() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      container.dispose();
      await db.close();
    });

    test('no-op when lineIndex is negative', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.retranslateLine(-1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls, isEmpty);
    });

    test('no-op when lineIndex exceeds primary lines length', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.retranslateLine(99);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls, isEmpty);
    });

    test('force-refreshes a previously translated line', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);

      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fake.calls, ['Hello']);

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      final aiRow = await repo.transcriptRowById(state.aiTranscriptId!);
      expect(repo.linesForRow(aiRow!)[0].text, 'ZH:Hello');

      await ctrl.retranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fake.calls, ['Hello', 'Hello']);

      final updatedRow = await repo.transcriptRowById(state.aiTranscriptId!);
      expect(repo.linesForRow(updatedRow!)[0].text, 'ZH:Hello');
    });

    test('removes line from failedLineIndexes before re-translating', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      fake.errorToThrow = Exception('fail');
      fake.errorCount = 999;

      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      var state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.failedLineIndexes, contains(0));

      fake.errorToThrow = null;
      fake.errorCount = 0;
      await ctrl.retranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.failedLineIndexes, isNot(contains(0)));
    });

    test('clears line text in DB before re-translating', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);

      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      final gate = fake.delayNext();

      final future = ctrl.retranslateLine(0);
      await Future<void>.delayed(Duration.zero);

      final midRow = await repo.transcriptRowById(state.aiTranscriptId!);
      expect(repo.linesForRow(midRow!)[0].text, '');

      gate.complete();
      await future;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final finalRow = await repo.transcriptRowById(state.aiTranscriptId!);
      expect(repo.linesForRow(finalRow!)[0].text, 'ZH:Hello');
    });
  });

  group('AutoTranslateCtrl _translateLine error handling', () {
    late AppDatabase db;
    late TranscriptRepository repo;
    late _FakeTranslation fake;
    late ProviderContainer container;
    const mediaId = 'media-err';

    Future<void> seedAndActivate() async {
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
        TranscriptLine(text: '   ', startMs: 1500, durationMs: 500),
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

      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();
    }

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
      fake = _FakeTranslation();
      await seedAndActivate();
    });

    tearDown(() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      container.dispose();
      await db.close();
    });

    test('AuthFailure blocks with auth reason', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      fake.errorToThrow = const AuthFailure('unauthorized');
      fake.errorCount = 999;

      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.status, AutoTranslateStatus.blocked);
      expect(state.blockReason, AutoTranslateBlockReason.auth);
    });

    test('CreditsFailure blocks with credits reason', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      fake.errorToThrow = const CreditsFailure('no credits');
      fake.errorCount = 999;

      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.status, AutoTranslateStatus.blocked);
      expect(state.blockReason, AutoTranslateBlockReason.credits);
    });

    test('generic error retries then marks line as failed', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      fake.errorToThrow = Exception('network timeout');
      fake.errorCount = 999;

      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.failedLineIndexes, contains(0));
      expect(state.status, AutoTranslateStatus.active);
      expect(fake.calls.length, kAutoTranslateMaxLineAttempts);
    });

    test('generic error succeeds on retry', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      fake.errorToThrow = Exception('transient');
      fake.errorCount = 1;

      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.failedLineIndexes, isNot(contains(0)));
      expect(fake.calls.length, 2);

      final aiRow = await repo.transcriptRowById(state.aiTranscriptId!);
      expect(repo.linesForRow(aiRow!)[0].text, 'ZH:Hello');
    });

    test('empty plain text line does not call translation API', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);

      ctrl.requestTranslateLine(2);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(fake.calls, isEmpty);
    });

    test('stale AI track blocks with stalePrimary reason', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      final state = container.read(autoTranslateCtrlProvider(mediaId));
      final aiId = state.aiTranscriptId!;

      final aiRow = (await repo.transcriptRowById(aiId))!;
      await db.transcriptDao.upsert(
        aiRow.copyWith(referenceId: const Value('wrong-primary-id')),
      );

      ctrl.requestTranslateLine(0);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final updated = container.read(autoTranslateCtrlProvider(mediaId));
      expect(updated.status, AutoTranslateStatus.blocked);
      expect(updated.blockReason, AutoTranslateBlockReason.stalePrimary);
    });
  });

  group('AutoTranslateCtrl hydration', () {
    late AppDatabase db;
    late TranscriptRepository repo;
    late _FakeTranslation fake;
    late ProviderContainer container;
    const mediaId = 'media-hydrate';

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
      fake = _FakeTranslation();
    });

    tearDown(() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      container.dispose();
      await db.close();
    });

    test('hydrates active state when AI secondary already set', () async {
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

      final aiId = enjoyTranscriptId(
        targetType: 'Video',
        targetId: mediaId,
        language: 'zh-CN',
        source: 'ai',
      );
      final skeleton = buildAutoTranslateSkeleton(lines);
      await db.transcriptDao.upsert(
        TranscriptRow(
          id: aiId,
          targetType: 'Video',
          targetId: mediaId,
          language: 'zh-CN',
          source: 'ai',
          timelineJson: jsonEncode(skeleton.map((e) => e.toJson()).toList()),
          referenceId: primaryId,
          label: 'Auto translate (zh-CN)',
          trackIndex: null,
          syncStatus: 'local',
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.echoSessionDao.updateSecondaryTranscriptForTarget(
        'Video',
        mediaId,
        aiId,
      );

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

      // Pre-subscribe to stream providers so they emit before the notifier
      // reads their .value synchronously during build().
      container.listen(secondaryTranscriptIdProvider(mediaId), (_, _) {});
      container.listen(activeTranscriptIdProvider(mediaId), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.status, AutoTranslateStatus.active);
      expect(state.aiTranscriptId, aiId);
      expect(state.primaryTranscriptId, primaryId);
      expect(state.sourceLanguage, 'en');
      expect(state.targetLanguage, 'zh-CN');
    });

    test('does not hydrate when secondary is not AI source', () async {
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
      await db.echoSessionDao.updateSecondaryTranscriptForTarget(
        'Video',
        mediaId,
        primaryId,
      );

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

      container.listen(secondaryTranscriptIdProvider(mediaId), (_, _) {});
      container.listen(activeTranscriptIdProvider(mediaId), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.status, AutoTranslateStatus.idle);
    });
  });

  group('AutoTranslateCtrl secondary transcript change', () {
    late AppDatabase db;
    late TranscriptRepository repo;
    late _FakeTranslation fake;
    late ProviderContainer container;
    const mediaId = 'media-secondary';

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
      fake = _FakeTranslation();

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

      container.listen(secondaryTranscriptIdProvider(mediaId), (_, _) {});
      container.listen(activeTranscriptIdProvider(mediaId), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();
    });

    tearDown(() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      container.dispose();
      await db.close();
    });

    test(
      'requestTranslateLine bails when secondary is a non-AI track',
      () async {
        var state = container.read(autoTranslateCtrlProvider(mediaId));
        expect(state.status, AutoTranslateStatus.active);

        await db.echoSessionDao.updateSecondaryTranscriptForTarget(
          'Video',
          mediaId,
          'some-other-transcript',
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));

        final ctrl = container.read(
          autoTranslateCtrlProvider(mediaId).notifier,
        );
        ctrl.requestTranslateLine(0);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(fake.calls, isEmpty);
      },
    );
  });

  group('AutoTranslateCtrl primary changed behavior', () {
    late AppDatabase db;
    late TranscriptRepository repo;
    late _FakeTranslation fake;
    late ProviderContainer container;
    const mediaId = 'media-primary-changed';

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
      fake = _FakeTranslation();

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

      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();
    });

    tearDown(() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      container.dispose();
      await db.close();
    });

    test('re-select picks up new primary transcript', () async {
      var state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.status, AutoTranslateStatus.active);
      final originalPrimaryId = state.primaryTranscriptId!;

      final now = DateTime.now();
      final newPrimaryId = enjoyTranscriptId(
        targetType: 'Video',
        targetId: mediaId,
        language: 'ja',
        source: 'user',
      );
      const newLines = [
        TranscriptLine(text: 'Konnichiwa', startMs: 0, durationMs: 1000),
        TranscriptLine(text: 'Sekai', startMs: 1000, durationMs: 500),
      ];
      await db.transcriptDao.upsert(
        TranscriptRow(
          id: newPrimaryId,
          targetType: 'Video',
          targetId: mediaId,
          language: 'ja',
          source: 'user',
          timelineJson: jsonEncode(newLines.map((e) => e.toJson()).toList()),
          referenceId: null,
          label: 'Japanese',
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
        newPrimaryId,
      );

      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();

      state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.status, AutoTranslateStatus.active);
      expect(state.primaryTranscriptId, isNot(originalPrimaryId));
      expect(state.primaryTranscriptId, newPrimaryId);
    });

    test('blocks with noPrimary when primary is removed', () async {
      var state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.status, AutoTranslateStatus.active);

      await db.echoSessionDao.updatePrimaryTranscriptForTarget(
        'Video',
        mediaId,
        null,
      );

      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();

      state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.status, AutoTranslateStatus.blocked);
      expect(state.blockReason, AutoTranslateBlockReason.noPrimary);
    });
  });

  group('AutoTranslateCtrl waiting queue reprioritization', () {
    late AppDatabase db;
    late TranscriptRepository repo;
    late _FakeTranslation fake;
    late ProviderContainer container;
    const mediaId = 'media-reprioritize';

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
      fake = _FakeTranslation();

      final now = DateTime.now();
      await db.videoDao.insertRow(
        VideoRow(
          id: mediaId,
          vid: 'vid12345678',
          provider: 'user',
          title: 'Test',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 300,
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
      final lines = List.generate(
        60,
        (i) => TranscriptLine(
          text: 'Line $i',
          startMs: i * 1000,
          durationMs: 1000,
        ),
      );
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
    });

    tearDown(() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      container.dispose();
      await db.close();
    });

    test('drops waiting lines far from playback highlight on seek', () async {
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          transcriptRepositoryProvider.overrideWithValue(repo),
          translationCapabilityProvider.overrideWithValue(fake),
          authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
          appPreferencesCtrlProvider.overrideWith(_ZhNativePrefsCtrl.new),
          transcriptPlaybackHighlightProvider(
            mediaId,
          ).overrideWithValue((cueIndex: 0, wordIndex: null)),
        ],
      );
      await container.read(authCtrlProvider.future);
      await container.read(appPreferencesCtrlProvider.future);

      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();

      final gates = <Completer<void>>[];
      for (var i = 0; i < 4; i++) {
        gates.add(fake.delayNext());
      }

      ctrl.requestTranslateLine(0);
      ctrl.requestTranslateLine(1);
      await Future<void>.delayed(Duration.zero);
      expect(fake.calls.length, 2);

      ctrl.requestTranslateLine(2);
      ctrl.requestTranslateLine(3);
      ctrl.requestTranslateLine(50);
      await Future<void>.delayed(Duration.zero);

      container.invalidate(transcriptPlaybackHighlightProvider(mediaId));
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          transcriptRepositoryProvider.overrideWithValue(repo),
          translationCapabilityProvider.overrideWithValue(fake),
          authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
          appPreferencesCtrlProvider.overrideWith(_ZhNativePrefsCtrl.new),
          transcriptPlaybackHighlightProvider(
            mediaId,
          ).overrideWithValue((cueIndex: 50, wordIndex: null)),
        ],
      );
      await container.read(authCtrlProvider.future);
      await container.read(appPreferencesCtrlProvider.future);

      for (final g in gates) {
        g.complete();
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(fake.calls, isNot(contains('Line 50')));
    });
  });

  group('isAutoTranslateSecondary provider', () {
    late AppDatabase db;
    late TranscriptRepository repo;
    late ProviderContainer container;
    const mediaId = 'media-is-ai';

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);

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
      const lines = [
        TranscriptLine(text: 'Hello', startMs: 0, durationMs: 1000),
      ];
      await db.transcriptDao.upsert(
        TranscriptRow(
          id: 'user-track',
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
      await db.transcriptDao.upsert(
        TranscriptRow(
          id: 'ai-track',
          targetType: 'Video',
          targetId: mediaId,
          language: 'zh-CN',
          source: 'ai',
          timelineJson: jsonEncode(lines.map((e) => e.toJson()).toList()),
          referenceId: 'user-track',
          label: 'Auto translate',
          trackIndex: null,
          syncStatus: 'local',
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          transcriptRepositoryProvider.overrideWithValue(repo),
          authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
          appPreferencesCtrlProvider.overrideWith(_ZhNativePrefsCtrl.new),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('returns false for null secondaryId', () async {
      final result = await container.read(
        isAutoTranslateSecondaryProvider(mediaId, null).future,
      );
      expect(result, isFalse);
    });

    test('returns false for non-AI track', () async {
      final result = await container.read(
        isAutoTranslateSecondaryProvider(mediaId, 'user-track').future,
      );
      expect(result, isFalse);
    });

    test('returns true for AI track', () async {
      final result = await container.read(
        isAutoTranslateSecondaryProvider(mediaId, 'ai-track').future,
      );
      expect(result, isTrue);
    });

    test('returns false for nonexistent track', () async {
      final result = await container.read(
        isAutoTranslateSecondaryProvider(mediaId, 'nonexistent').future,
      );
      expect(result, isFalse);
    });
  });

  group('autoTranslateSelectionId provider', () {
    late AppDatabase db;
    late TranscriptRepository repo;
    late ProviderContainer container;
    const mediaId = 'media-sel-id';

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);

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
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('returns null when not signed in', () async {
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          transcriptRepositoryProvider.overrideWithValue(repo),
          authCtrlProvider.overrideWith(_SignedOutAuthCtrl.new),
          appPreferencesCtrlProvider.overrideWith(_ZhNativePrefsCtrl.new),
        ],
      );
      await container.read(authCtrlProvider.future);

      final result = await container.read(
        autoTranslateSelectionIdProvider(mediaId).future,
      );
      expect(result, isNull);
    });

    test(
      'returns predicted AI track id when signed in with native language',
      () async {
        container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            transcriptRepositoryProvider.overrideWithValue(repo),
            authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
            appPreferencesCtrlProvider.overrideWith(_ZhNativePrefsCtrl.new),
          ],
        );
        await container.read(authCtrlProvider.future);
        await container.read(appPreferencesCtrlProvider.future);

        final result = await container.read(
          autoTranslateSelectionIdProvider(mediaId).future,
        );
        expect(result, isNotNull);
        expect(
          result,
          autoTranslateAiTrackId(
            targetType: 'Video',
            mediaId: mediaId,
            targetLanguage: 'zh-CN',
          ),
        );
      },
    );

    test('returns null for unknown media id', () async {
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          transcriptRepositoryProvider.overrideWithValue(repo),
          authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
          appPreferencesCtrlProvider.overrideWith(_ZhNativePrefsCtrl.new),
        ],
      );
      await container.read(authCtrlProvider.future);
      await container.read(appPreferencesCtrlProvider.future);

      final result = await container.read(
        autoTranslateSelectionIdProvider('nonexistent-media').future,
      );
      expect(result, isNull);
    });
  });

  group('AutoTranslateCtrl drain waiting after completion', () {
    late AppDatabase db;
    late TranscriptRepository repo;
    late _FakeTranslation fake;
    late ProviderContainer container;
    const mediaId = 'media-drain';

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
      fake = _FakeTranslation();

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
        TranscriptLine(text: 'A', startMs: 0, durationMs: 1000),
        TranscriptLine(text: 'B', startMs: 1000, durationMs: 500),
        TranscriptLine(text: 'C', startMs: 1500, durationMs: 500),
        TranscriptLine(text: 'D', startMs: 2000, durationMs: 500),
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

      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      await ctrl.selectAutoTranslate();
    });

    tearDown(() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      container.dispose();
      await db.close();
    });

    test('drains all waiting lines as in-flight slots free up', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);
      final g0 = fake.delayNext();
      final g1 = fake.delayNext();
      final g2 = fake.delayNext();
      final g3 = fake.delayNext();

      ctrl.requestTranslateLine(0);
      ctrl.requestTranslateLine(1);
      ctrl.requestTranslateLine(2);
      ctrl.requestTranslateLine(3);
      await Future<void>.delayed(Duration.zero);

      expect(fake.calls.length, kAutoTranslateMaxConcurrency);

      g0.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls.length, 3);

      g1.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.calls.length, 4);

      g2.complete();
      g3.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.inFlightIndexes, isEmpty);
      expect(fake.calls.length, 4);
    });

    test('skips failed lines when draining waiting queue', () async {
      final ctrl = container.read(autoTranslateCtrlProvider(mediaId).notifier);

      fake.errorToThrow = Exception('fail');
      fake.errorCount = 999;
      final g0 = fake.delayNext();
      final g1 = fake.delayNext();

      ctrl.requestTranslateLine(0);
      ctrl.requestTranslateLine(1);
      await Future<void>.delayed(Duration.zero);

      ctrl.requestTranslateLine(2);
      await Future<void>.delayed(Duration.zero);

      g0.complete();
      g1.complete();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final state = container.read(autoTranslateCtrlProvider(mediaId));
      expect(state.failedLineIndexes, isNotEmpty);
    });
  });
}
