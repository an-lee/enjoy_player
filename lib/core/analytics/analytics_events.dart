/// Event catalog constants for product analytics (specs/046).
///
/// 1:1 with specs/046-posthog-analytics-integration/contracts/event-catalog.md
/// — a unit test asserts the pairing. Event names follow the vendor
/// recommendation (`object_verb`, snake_case); property keys and values are a
/// closed vocabulary so payloads are structurally incapable of carrying
/// user-generated content (spec FR-004).
library;

/// The only sanctioned failure vocabulary for journey failure events.
/// Never server payloads or message text — `AppFailure` variants map here
/// via [analyticsFailureReasonFromAppFailure]; `cancelled` is used
/// explicitly at call sites where the user (or a superseding pass) aborts.
enum AnalyticsFailureReason {
  network,
  credits,
  auth,
  server,
  local,
  cancelled,
  unknown,
}

/// Event names, property keys, and per-event property builders.
abstract final class AnalyticsEvents {
  // --- Event names ---------------------------------------------------------

  static const String practiceSessionStarted = 'practice_session_started';
  static const String practiceSessionCompleted = 'practice_session_completed';
  static const String transcriptGenerationRequested =
      'transcript_generation_requested';
  static const String transcriptGenerationCompleted =
      'transcript_generation_completed';
  static const String transcriptGenerationFailed =
      'transcript_generation_failed';
  static const String dictionaryLookupPerformed = 'dictionary_lookup_performed';
  static const String translationRequested = 'translation_requested';
  static const String craftProjectCreated = 'craft_project_created';
  static const String craftPracticeCompleted = 'craft_practice_completed';
  static const String vocabularyReviewCompleted = 'vocabulary_review_completed';
  static const String subscriptionPurchaseStarted =
      'subscription_purchase_started';
  static const String subscriptionPurchaseCompleted =
      'subscription_purchase_completed';
  static const String creditsPackagePurchased = 'credits_package_purchased';

  /// All journey event names (the catalog — used by the sync test).
  static const List<String> all = [
    practiceSessionStarted,
    practiceSessionCompleted,
    transcriptGenerationRequested,
    transcriptGenerationCompleted,
    transcriptGenerationFailed,
    dictionaryLookupPerformed,
    translationRequested,
    craftProjectCreated,
    craftPracticeCompleted,
    vocabularyReviewCompleted,
    subscriptionPurchaseStarted,
    subscriptionPurchaseCompleted,
    creditsPackagePurchased,
  ];

  // --- Property keys -------------------------------------------------------

  static const String propSurface = 'surface';
  static const String propItemCount = 'item_count';
  static const String propDurationSeconds = 'duration_seconds';
  static const String propItemsCompleted = 'items_completed';
  static const String propSource = 'source';
  static const String propMediaKind = 'media_kind';
  static const String propReason = 'reason';
  static const String propCacheHit = 'cache_hit';
  static const String propKind = 'kind';
  static const String propMode = 'mode';
  static const String propReviewedCount = 'reviewed_count';
  static const String propCorrectCount = 'correct_count';
  static const String propTier = 'tier';
  static const String propPackageId = 'package_id';

  // --- Closed value vocabulary --------------------------------------------

  // `surface` (practice)
  static const String surfaceShadowReading = 'shadow_reading';
  static const String surfaceWordPractice = 'word_practice';
  static const String surfaceFlashcard = 'flashcard';

  // `source` (transcripts / lookup)
  static const String sourceAsr = 'asr';
  static const String sourceYoutube = 'youtube';
  static const String sourceLocalFile = 'local_file';
  static const String sourceSelection = 'selection';
  static const String sourceManual = 'manual';

  // `kind` (translation / craft practice style)
  static const String kindStandard = 'standard';
  static const String kindContextual = 'contextual';

  // `mode` (craft)
  static const String modeFromText = 'from_text';
  static const String modeCapture = 'capture';
  static const String modeImport = 'import';

  // Common context (super properties — registered once at init).
  static const String propDisplayLocale = 'display_locale';
  static const String propLearningLanguage = 'learning_language';
  static const String propDistributionChannel = 'distribution_channel';

  /// Every allowlisted property key — the full closed vocabulary. The
  /// vendor-side beforeSend guard drops events carrying anything else
  /// (structural FR-004 enforcement), and the catalog sync test asserts
  /// every builder stays inside this set.
  static const List<String> propertyKeys = [
    propSurface,
    propItemCount,
    propDurationSeconds,
    propItemsCompleted,
    propSource,
    propMediaKind,
    propReason,
    propCacheHit,
    propKind,
    propMode,
    propReviewedCount,
    propCorrectCount,
    propTier,
    propPackageId,
    propDisplayLocale,
    propLearningLanguage,
    propDistributionChannel,
  ];

  // --- Property builders (allowlists; values are tags/ints only) ----------

  static Map<String, Object> practiceStarted({
    required String surface,
    required int itemCount,
  }) => {propSurface: surface, propItemCount: itemCount};

  static Map<String, Object> practiceCompleted({
    required String surface,
    required int durationSeconds,
    required int itemsCompleted,
  }) => {
    propSurface: surface,
    propDurationSeconds: durationSeconds,
    propItemsCompleted: itemsCompleted,
  };

  static Map<String, Object> transcriptRequested({
    required String source,
    String? mediaKind,
  }) => {propSource: source, if (mediaKind != null) propMediaKind: mediaKind};

  static Map<String, Object> transcriptCompleted({
    required String source,
    required int durationSeconds,
  }) => {propSource: source, propDurationSeconds: durationSeconds};

  static Map<String, Object> transcriptFailed({
    required String source,
    required AnalyticsFailureReason reason,
  }) => {propSource: source, propReason: reason.name};

  static Map<String, Object> lookupPerformed({
    required String source,
    required bool cacheHit,
  }) => {propSource: source, propCacheHit: cacheHit};

  static Map<String, Object> translationRequestedProps({
    required String kind,
    required bool cacheHit,
  }) => {propKind: kind, propCacheHit: cacheHit};

  static Map<String, Object> craftCreated({required String mode}) => {
    propMode: mode,
  };

  static Map<String, Object> craftCompleted({required int durationSeconds}) => {
    propDurationSeconds: durationSeconds,
  };

  static Map<String, Object> vocabularyReview({
    required int reviewedCount,
    required int correctCount,
  }) => {propReviewedCount: reviewedCount, propCorrectCount: correctCount};

  static Map<String, Object> purchaseStarted({required String tier}) => {
    propTier: tier,
  };

  static Map<String, Object> purchaseCompleted({required String tier}) => {
    propTier: tier,
  };

  static Map<String, Object> creditsPurchased({required String packageId}) => {
    propPackageId: packageId,
  };
}
