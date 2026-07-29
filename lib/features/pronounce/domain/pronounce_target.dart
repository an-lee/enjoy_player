/// In-memory pronounce request identity and playback phases.
library;

import 'package:enjoy_player/features/pronounce/domain/pronounce_locale.dart';

enum PronounceSurfaceId { lookup, flashcard, assessment }

enum PronouncePlaybackPhase { idle, loading, playing, error }

/// What a surface asks to speak.
final class PronounceTarget {
  const PronounceTarget({
    required this.text,
    required this.localeTag,
    required this.resolvedLocale,
    required this.surfaceId,
  });

  /// Builds a target when [localeTag] resolves; otherwise returns `null`.
  static PronounceTarget? tryCreate({
    required String text,
    required String localeTag,
    required PronounceSurfaceId surfaceId,
  }) {
    final trimmed = text.trim();
    if (!isPronounceTextEligible(trimmed)) return null;
    final resolved = resolvePronounceLocale(localeTag);
    if (resolved == null) return null;
    return PronounceTarget(
      text: trimmed,
      localeTag: localeTag,
      resolvedLocale: resolved,
      surfaceId: surfaceId,
    );
  }

  final String text;
  final String localeTag;
  final String resolvedLocale;
  final PronounceSurfaceId surfaceId;

  String get cacheKey => '$resolvedLocale\u0000$text';

  bool sameUtteranceAs(PronounceTarget? other) {
    if (other == null) return false;
    return text == other.text && resolvedLocale == other.resolvedLocale;
  }
}

/// App-wide pronounce session snapshot.
final class PronouncePlaybackState {
  const PronouncePlaybackState({
    required this.phase,
    this.target,
    this.errorMessage,
  });

  const PronouncePlaybackState.idle()
    : phase = PronouncePlaybackPhase.idle,
      target = null,
      errorMessage = null;

  final PronouncePlaybackPhase phase;
  final PronounceTarget? target;
  final String? errorMessage;

  bool get isIdle => phase == PronouncePlaybackPhase.idle;
  bool get isLoading => phase == PronouncePlaybackPhase.loading;
  bool get isPlaying => phase == PronouncePlaybackPhase.playing;

  bool isLoadingFor(PronounceTarget t) =>
      isLoading && target != null && target!.sameUtteranceAs(t);

  bool isPlayingFor(PronounceTarget t) =>
      isPlaying && target != null && target!.sameUtteranceAs(t);
}
