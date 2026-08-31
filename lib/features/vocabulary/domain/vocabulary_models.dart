/// Domain models for the local-first vocabulary / SRS feature.
///
/// Wire values match Enjoy web (`apps/web/src/types/db/vocabulary-*.ts`).
library;

/// Word-level SRS status. Wire strings: `new` | `learning` | `reviewing` | `mastered`.
enum VocabularyStatus {
  /// Wire value `new`.
  new_('new'),
  learning('learning'),
  reviewing('reviewing'),
  mastered('mastered');

  const VocabularyStatus(this.wire);
  final String wire;

  static VocabularyStatus fromWire(String value) {
    for (final s in values) {
      if (s.wire == value) return s;
    }
    throw ArgumentError.value(value, 'value', 'Unknown VocabularyStatus');
  }
}

/// Flashcard rating: 0 don't know, 1 know, 2 know well.
enum VocabularyRating {
  dontKnow(0),
  know(1),
  knowWell(2);

  const VocabularyRating(this.value);
  final int value;

  static VocabularyRating fromValue(int value) {
    for (final r in values) {
      if (r.value == value) return r;
    }
    throw ArgumentError.value(value, 'value', 'VocabularyRating must be 0|1|2');
  }
}

/// Context source. Wire: `Video` | `Audio` | `Ebook`.
enum VocabularySourceType {
  video('Video'),
  audio('Audio'),
  ebook('Ebook');

  const VocabularySourceType(this.wire);
  final String wire;

  static VocabularySourceType fromWire(String value) {
    for (final s in values) {
      if (s.wire == value) return s;
    }
    throw ArgumentError.value(value, 'value', 'Unknown VocabularySourceType');
  }
}

/// Locator for video/audio content (milliseconds).
final class MediaLocator {
  const MediaLocator({required this.start, required this.duration});

  factory MediaLocator.fromJson(Map<String, Object?> json) {
    if (json['type'] != type) {
      throw FormatException(
        'Expected MediaLocator type "media", got ${json['type']}',
      );
    }
    return MediaLocator(
      start: (json['start'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
    );
  }

  /// Always `"media"` on the wire.
  static const String type = 'media';

  /// Start offset in milliseconds.
  final int start;

  /// Duration in milliseconds.
  final int duration;

  Map<String, Object?> toJson() => {
    'type': type,
    'start': start,
    'duration': duration,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaLocator &&
          start == other.start &&
          duration == other.duration;

  @override
  int get hashCode => Object.hash(start, duration);
}

/// Readium-shaped ebook locator (schema-ready; UI deferred).
final class EbookLocator {
  const EbookLocator({
    required this.href,
    required this.locatorType,
    this.title,
    this.locations,
    this.text,
  });

  factory EbookLocator.fromJson(Map<String, Object?> json) {
    if (json['type'] != type) {
      throw FormatException(
        'Expected EbookLocator type "ebook", got ${json['type']}',
      );
    }
    final loc = json['locations'];
    return EbookLocator(
      href: json['href']! as String,
      locatorType: json['locatorType']! as String,
      title: json['title'] as String?,
      locations: loc is Map<String, Object?>
          ? EbookLocatorLocations.fromJson(loc)
          : loc is Map
          ? EbookLocatorLocations.fromJson(Map<String, Object?>.from(loc))
          : null,
      text: json['text'] as String?,
    );
  }

  static const String type = 'ebook';

  final String href;
  final String locatorType;
  final String? title;
  final EbookLocatorLocations? locations;
  final String? text;

  Map<String, Object?> toJson() => {
    'type': type,
    'href': href,
    'locatorType': locatorType,
    if (title != null) 'title': title,
    if (locations != null) 'locations': locations!.toJson(),
    if (text != null) 'text': text,
  };
}

final class EbookLocatorLocations {
  const EbookLocatorLocations({
    this.fragments,
    this.progression,
    this.totalProgression,
    this.position,
  });

  factory EbookLocatorLocations.fromJson(Map<String, Object?> json) {
    final frags = json['fragments'];
    return EbookLocatorLocations(
      fragments: frags is List ? frags.cast<String>() : null,
      progression: (json['progression'] as num?)?.toDouble(),
      totalProgression: (json['totalProgression'] as num?)?.toDouble(),
      position: (json['position'] as num?)?.toInt(),
    );
  }

  final List<String>? fragments;
  final double? progression;
  final double? totalProgression;
  final int? position;

  Map<String, Object?> toJson() => {
    if (fragments != null) 'fragments': fragments,
    if (progression != null) 'progression': progression,
    if (totalProgression != null) 'totalProgression': totalProgression,
    if (position != null) 'position': position,
  };
}

/// Word-level SRS entity. One row per `(normalizedWord, language, targetLanguage)`.
final class VocabularyItem {
  const VocabularyItem({
    required this.id,
    required this.word,
    required this.language,
    required this.targetLanguage,
    required this.status,
    required this.easeFactor,
    required this.interval,
    required this.nextReviewAt,
    required this.reviewsCount,
    this.lastReviewedAt,
    required this.contextsCount,
    this.explanation,
    this.syncStatus,
    this.serverUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String word;
  final String language;
  final String targetLanguage;
  final VocabularyStatus status;
  final double easeFactor;
  final int interval;
  final DateTime nextReviewAt;
  final int reviewsCount;
  final DateTime? lastReviewedAt;
  final int contextsCount;

  /// Cached dictionary JSON (opaque string for now).
  final String? explanation;
  final String? syncStatus;
  final DateTime? serverUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  VocabularyItem copyWith({
    String? id,
    String? word,
    String? language,
    String? targetLanguage,
    VocabularyStatus? status,
    double? easeFactor,
    int? interval,
    DateTime? nextReviewAt,
    int? reviewsCount,
    DateTime? lastReviewedAt,
    bool clearLastReviewedAt = false,
    int? contextsCount,
    String? explanation,
    String? syncStatus,
    DateTime? serverUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VocabularyItem(
      id: id ?? this.id,
      word: word ?? this.word,
      language: language ?? this.language,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      status: status ?? this.status,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      lastReviewedAt: clearLastReviewedAt
          ? null
          : (lastReviewedAt ?? this.lastReviewedAt),
      contextsCount: contextsCount ?? this.contextsCount,
      explanation: explanation ?? this.explanation,
      syncStatus: syncStatus ?? this.syncStatus,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VocabularyItem &&
          id == other.id &&
          word == other.word &&
          language == other.language &&
          targetLanguage == other.targetLanguage &&
          status == other.status &&
          easeFactor == other.easeFactor &&
          interval == other.interval &&
          nextReviewAt == other.nextReviewAt &&
          reviewsCount == other.reviewsCount &&
          lastReviewedAt == other.lastReviewedAt &&
          contextsCount == other.contextsCount &&
          explanation == other.explanation &&
          syncStatus == other.syncStatus &&
          serverUpdatedAt == other.serverUpdatedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    word,
    language,
    targetLanguage,
    status,
    easeFactor,
    interval,
    nextReviewAt,
    reviewsCount,
    lastReviewedAt,
    contextsCount,
    explanation,
    syncStatus,
    serverUpdatedAt,
    createdAt,
    updatedAt,
  );
}

/// Appearance of a word in media / ebook.
final class VocabularyContext {
  const VocabularyContext({
    required this.id,
    required this.vocabularyItemId,
    required this.text,
    required this.sourceType,
    required this.sourceId,
    required this.locator,
    this.ebookLocator,
    this.explanation,
    this.syncStatus,
    this.serverUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String vocabularyItemId;
  final String text;
  final VocabularySourceType sourceType;
  final String sourceId;

  /// Set when [sourceType] is video/audio.
  final MediaLocator? locator;

  /// Set when [sourceType] is ebook (schema-ready).
  final EbookLocator? ebookLocator;

  final String? explanation;
  final String? syncStatus;
  final DateTime? serverUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  VocabularyContext copyWith({
    String? id,
    String? vocabularyItemId,
    String? text,
    VocabularySourceType? sourceType,
    String? sourceId,
    MediaLocator? locator,
    EbookLocator? ebookLocator,
    String? explanation,
    bool clearExplanation = false,
    String? syncStatus,
    DateTime? serverUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VocabularyContext(
      id: id ?? this.id,
      vocabularyItemId: vocabularyItemId ?? this.vocabularyItemId,
      text: text ?? this.text,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      locator: locator ?? this.locator,
      ebookLocator: ebookLocator ?? this.ebookLocator,
      explanation: clearExplanation ? null : (explanation ?? this.explanation),
      syncStatus: syncStatus ?? this.syncStatus,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VocabularyContext &&
          id == other.id &&
          vocabularyItemId == other.vocabularyItemId &&
          text == other.text &&
          sourceType == other.sourceType &&
          sourceId == other.sourceId &&
          locator == other.locator &&
          ebookLocator == other.ebookLocator &&
          explanation == other.explanation &&
          syncStatus == other.syncStatus &&
          serverUpdatedAt == other.serverUpdatedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    vocabularyItemId,
    text,
    sourceType,
    sourceId,
    locator,
    ebookLocator,
    explanation,
    syncStatus,
    serverUpdatedAt,
    createdAt,
    updatedAt,
  );
}

/// Local review audit row (never synced).
final class VocabularyReview {
  const VocabularyReview({
    required this.id,
    required this.vocabularyItemId,
    required this.rating,
    required this.at,
    required this.easeFactorBefore,
    required this.intervalBefore,
    required this.statusBefore,
    required this.reviewsCountBefore,
    required this.nextReviewAtBefore,
    this.lastReviewedAtBefore,
    this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String vocabularyItemId;
  final VocabularyRating rating;
  final DateTime at;
  final double easeFactorBefore;
  final int intervalBefore;
  final VocabularyStatus statusBefore;
  final int reviewsCountBefore;
  final DateTime nextReviewAtBefore;
  final DateTime? lastReviewedAtBefore;
  final String? syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Result of [VocabularyRepository.addWithContext].
final class AddVocabularyResult {
  const AddVocabularyResult({
    required this.item,
    required this.context,
    required this.isNewContext,
  });

  final VocabularyItem item;
  final VocabularyContext context;
  final bool isNewContext;
}

/// Fields produced by [calculateNextReview] (web `ReviewUpdate`).
final class ReviewUpdate {
  const ReviewUpdate({
    required this.status,
    required this.easeFactor,
    required this.interval,
    required this.nextReviewAt,
    required this.reviewsCount,
    required this.lastReviewedAt,
  });

  final VocabularyStatus status;
  final double easeFactor;
  final int interval;
  final DateTime nextReviewAt;
  final int reviewsCount;
  final DateTime lastReviewedAt;
}
