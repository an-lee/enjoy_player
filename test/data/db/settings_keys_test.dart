import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsKeys static constants', () {
    test('apiBaseUrl / apiAiBaseUrl use canonical dotted names', () {
      expect(SettingsKeys.apiBaseUrl, 'api.base_url');
      expect(SettingsKeys.apiAiBaseUrl, 'api.ai_base_url');
    });

    test('locale and language keys', () {
      expect(SettingsKeys.prefsLocale, 'prefs.locale');
      expect(SettingsKeys.prefsLearningLanguage, 'prefs.learning_language');
      expect(SettingsKeys.prefsNativeLanguage, 'prefs.native_language');
    });

    test('recording input device id', () {
      expect(
        SettingsKeys.prefsRecordingInputDeviceId,
        'prefs.recording_input_device_id',
      );
    });

    test('sync cursor keys', () {
      expect(SettingsKeys.syncCursorAudio, 'sync.cursor.audio');
      expect(SettingsKeys.syncCursorVideo, 'sync.cursor.video');
      expect(SettingsKeys.syncCursorRecording, 'sync.cursor.recording');
      expect(
        SettingsKeys.syncCursorVocabularyItem,
        'sync.cursor.vocabulary_item',
      );
      expect(
        SettingsKeys.syncCursorVocabularyContext,
        'sync.cursor.vocabulary_context',
      );
    });

    test('update keys', () {
      expect(SettingsKeys.updateLastCheckAt, 'update.last_check_at');
      expect(SettingsKeys.updateSnoozeUntil, 'update.snooze_until');
      expect(SettingsKeys.updateSnoozeVersion, 'update.snooze_version');
    });

    test('diagnostics / hotkeys / ai / youtube keys', () {
      expect(
        SettingsKeys.diagnosticsVerboseEnabled,
        'diagnostics.verbose_enabled',
      );
      expect(SettingsKeys.hotkeysCustomBindings, 'hotkeys_custom_bindings');
      expect(SettingsKeys.aiModalityConfigsV1, 'ai.modality_configs_v1');
      expect(
        SettingsKeys.youtubeClientProfilesV1,
        'youtube.client_profiles_v1',
      );
    });

    test('player preferences v1', () {
      expect(SettingsKeys.playerPreferencesV1, 'player_preferences_v1');
    });
  });

  group('SettingsKeys dynamic helpers', () {
    test('syncCursorRecordingTarget formats dotted path', () {
      expect(
        SettingsKeys.syncCursorRecordingTarget('Video', 'abc'),
        'sync.cursor.recording.Video.abc',
      );
      expect(
        SettingsKeys.syncCursorRecordingTarget('Audio', 'xyz'),
        'sync.cursor.recording.Audio.xyz',
      );
    });

    test('syncLastPullAtRecordingTarget formats dotted path', () {
      expect(
        SettingsKeys.syncLastPullAtRecordingTarget('Video', 'abc'),
        'sync.last_pull_at.recording.Video.abc',
      );
    });

    test('asrLongFormAttempt formats dotted path', () {
      expect(
        SettingsKeys.asrLongFormAttempt('m-1'),
        'asr.long_form.attempt.m-1',
      );
    });
  });

  group('SettingsKeys.isKnown', () {
    test('recognizes every static key as known', () {
      const staticKeys = <String>[
        SettingsKeys.apiBaseUrl,
        SettingsKeys.apiAiBaseUrl,
        SettingsKeys.prefsLocale,
        SettingsKeys.prefsLearningLanguage,
        SettingsKeys.prefsNativeLanguage,
        SettingsKeys.prefsRecordingInputDeviceId,
        SettingsKeys.syncCursorAudio,
        SettingsKeys.syncCursorVideo,
        SettingsKeys.syncCursorRecording,
        SettingsKeys.syncCursorVocabularyItem,
        SettingsKeys.syncCursorVocabularyContext,
        SettingsKeys.syncLastFullSyncAt,
        SettingsKeys.updateLastCheckAt,
        SettingsKeys.updateSnoozeUntil,
        SettingsKeys.updateSnoozeVersion,
        SettingsKeys.diagnosticsVerboseEnabled,
        SettingsKeys.playerPreferencesV1,
        SettingsKeys.hotkeysCustomBindings,
        SettingsKeys.aiModalityConfigsV1,
        SettingsKeys.youtubeClientProfilesV1,
      ];
      for (final k in staticKeys) {
        expect(SettingsKeys.isKnown(k), isTrue, reason: 'key: $k');
      }
    });

    test('recognizes sync.cursor.recording.*', () {
      expect(
        SettingsKeys.isKnown(
          SettingsKeys.syncCursorRecordingTarget('Video', 'x'),
        ),
        isTrue,
      );
      expect(
        SettingsKeys.isKnown(
          SettingsKeys.syncCursorRecordingTarget('Audio', 'y'),
        ),
        isTrue,
      );
    });

    test('recognizes sync.last_pull_at.recording.*', () {
      expect(
        SettingsKeys.isKnown(
          SettingsKeys.syncLastPullAtRecordingTarget('Video', 'x'),
        ),
        isTrue,
      );
    });

    test('recognizes asr.long_form.attempt.*', () {
      expect(
        SettingsKeys.isKnown(SettingsKeys.asrLongFormAttempt('m-1')),
        isTrue,
      );
    });

    test('returns false for unknown keys', () {
      expect(SettingsKeys.isKnown('not.a.key'), isFalse);
      expect(SettingsKeys.isKnown('sync.cursor.video.extra'), isFalse);
      expect(SettingsKeys.isKnown('asr.short.attempt.x'), isFalse);
      expect(SettingsKeys.isKnown(''), isFalse);
    });

    test('does NOT match sync.cursor.video with extra suffix', () {
      // Only the recording prefix family is dynamic; video / audio cursors
      // are static and don't open a sub-tree.
      expect(SettingsKeys.isKnown('sync.cursor.video.foo'), isFalse);
      expect(SettingsKeys.isKnown('sync.cursor.audio.foo'), isFalse);
    });
  });

  group('default api origins', () {
    test('kDefaultApiBaseUrl / kDefaultAiApiBaseUrl are stable URLs', () {
      expect(kDefaultApiBaseUrl, 'https://enjoy.bot');
      expect(kDefaultAiApiBaseUrl, 'https://worker.enjoy.bot');
      expect(kDefaultApiBaseUrl.endsWith('/'), isFalse);
      expect(kDefaultAiApiBaseUrl.endsWith('/'), isFalse);
    });
  });
}
