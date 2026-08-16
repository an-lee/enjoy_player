/// Keys for [SettingsDao] key/value rows.
library;

abstract final class SettingsKeys {
  static const String apiBaseUrl = 'api.base_url';

  /// Worker-hosted AI routes (OpenAI-compatible chat, ASR, translation, etc.).
  static const String apiAiBaseUrl = 'api.ai_base_url';
  static const String prefsLocale = 'prefs.locale';
  static const String prefsLearningLanguage = 'prefs.learning_language';
  static const String prefsNativeLanguage = 'prefs.native_language';

  /// Capture device id (`record` package `InputDevice.id`) for shadow-reading
  /// recordings. Empty / missing means "auto-pick the first non-virtual mic".
  static const String prefsRecordingInputDeviceId =
      'prefs.recording_input_device_id';

  /// ISO-8601 cursor for incremental `updatedAfter` downloads.
  static const String syncCursorAudio = 'sync.cursor.audio';
  static const String syncCursorVideo = 'sync.cursor.video';
  static const String syncCursorRecording = 'sync.cursor.recording';

  /// ISO-8601 cursors for incremental vocabulary `updatedAfter` downloads.
  static const String syncCursorVocabularyItem = 'sync.cursor.vocabulary_item';
  static const String syncCursorVocabularyContext =
      'sync.cursor.vocabulary_context';

  /// Per-target recording pull (`sync.cursor.recording.{targetType}.{targetId}`).
  static String syncCursorRecordingTarget(String targetType, String targetId) =>
      'sync.cursor.recording.$targetType.$targetId';

  /// ISO-8601 UTC timestamp of the last pull attempt for a given
  /// recording target, used as a cooldown to avoid hammering the
  /// server on every media open
  /// (`sync.last_pull_at.recording.{targetType}.{targetId}`).
  static String syncLastPullAtRecordingTarget(
    String targetType,
    String targetId,
  ) => 'sync.last_pull_at.recording.$targetType.$targetId';

  /// ISO-8601 UTC timestamp of last fully successful full sync (downloads + queue).
  static const String syncLastFullSyncAt = 'sync.last_full_sync_at';

  /// ISO-8601 UTC timestamp of the last successful update feed check.
  static const String updateLastCheckAt = 'update.last_check_at';

  /// ISO-8601 UTC — do not show optional update prompts until this instant.
  static const String updateSnoozeUntil = 'update.snooze_until';

  /// Version string the user snoozed (optional updates only).
  static const String updateSnoozeVersion = 'update.snooze_version';

  /// When `true`, allowlisted diagnostic loggers write FINE records to the log file.
  static const String diagnosticsVerboseEnabled = 'diagnostics.verbose_enabled';

  /// When `true`, Craft save may attach nested word/phone spans via on-device
  /// alignment. Missing value ≡ off.
  static const String transcriptTimelineEnrichment =
      'transcript.timelineEnrichment';

  /// When `true`, the transcript panel highlights the current word if the cue
  /// already has stored word timings. Missing value ≡ off.
  static const String transcriptKaraokeHighlight =
      'transcript.karaokeHighlight';

  /// When `true`, show stored pronunciation spelling with each primary-line
  /// word that has phone pieces. Missing value ≡ off.
  static const String transcriptIpaOverlay = 'transcript.ipaOverlay';

  /// When `true`, allow seek/loop/inspect of stored timed words. Missing ≡ off.
  static const String transcriptWordPractice = 'transcript.wordPractice';

  /// JSON blob: volume, rate, repeat, split width ([PlayerPreferencesCtrl]).
  static const String playerPreferencesV1 = 'player_preferences_v1';

  /// JSON map of custom hotkey action id → binding string.
  static const String hotkeysCustomBindings = 'hotkeys_custom_bindings';

  /// JSON blob: per-modality AI provider config (BYOK non-secrets only).
  static const String aiModalityConfigsV1 = 'ai.modality_configs_v1';

  /// JSON array: cached YouTube InnerTube client profiles from worker
  /// `GET /youtube/client-profiles`. Fall back to built-in defaults when absent.
  static const String youtubeClientProfilesV1 = 'youtube.client_profiles_v1';

  /// In-flight Enjoy long-form ASR attempt JSON for [mediaId].
  static String asrLongFormAttempt(String mediaId) =>
      'asr.long_form.attempt.$mediaId';

  /// JSON map of global onboarding tip id → completed|skipped.
  static const String onboardingTipProgressV1 = 'onboarding.tip_progress_v1';

  /// Per-media empty-transcript tip resolution (`completed`|`skipped`).
  static String onboardingEmptyTranscript(String mediaId) =>
      'onboarding.empty_transcript.$mediaId';

  /// Prefix for [onboardingEmptyTranscript] keys.
  static const String onboardingEmptyTranscriptPrefix =
      'onboarding.empty_transcript.';

  static const _staticKeys = {
    apiBaseUrl,
    apiAiBaseUrl,
    prefsLocale,
    prefsLearningLanguage,
    prefsNativeLanguage,
    prefsRecordingInputDeviceId,
    syncCursorAudio,
    syncCursorVideo,
    syncCursorRecording,
    syncCursorVocabularyItem,
    syncCursorVocabularyContext,
    syncLastFullSyncAt,
    updateLastCheckAt,
    updateSnoozeUntil,
    updateSnoozeVersion,
    diagnosticsVerboseEnabled,
    transcriptTimelineEnrichment,
    transcriptKaraokeHighlight,
    transcriptIpaOverlay,
    transcriptWordPractice,
    playerPreferencesV1,
    hotkeysCustomBindings,
    aiModalityConfigsV1,
    youtubeClientProfilesV1,
    onboardingTipProgressV1,
  };

  /// Whether [key] is a known static or dynamic settings key.
  static bool isKnown(String key) {
    if (_staticKeys.contains(key)) return true;
    if (key.startsWith('sync.cursor.recording.')) return true;
    if (key.startsWith('sync.last_pull_at.recording.')) return true;
    if (key.startsWith('asr.long_form.attempt.')) return true;
    if (key.startsWith(onboardingEmptyTranscriptPrefix)) return true;
    return false;
  }
}

/// Default Enjoy API origin (no trailing slash).
const String kDefaultApiBaseUrl = 'https://enjoy.bot';

/// Default Enjoy Worker origin for AI endpoints (no trailing slash).
const String kDefaultAiApiBaseUrl = 'https://worker.enjoy.bot';
