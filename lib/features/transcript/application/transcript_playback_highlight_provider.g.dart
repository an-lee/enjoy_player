// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_playback_highlight_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Current cue index (echo-aware) and karaoke current-word index.
///
/// `cueIndex` is `-1` when there are no lines. `wordIndex` is null when
/// karaoke is off / still loading, `karaokeSwitchEnabled` is false (no timed
/// words on owned media), the cue is out of range, or the position is in a
/// gap.
///
/// The 50 ms karaoke position stream is watched **only after** the karaoke
/// gate passes, so karaoke-off transcripts never subscribe to the word tick
/// stream. Consumers that only need the cue index must use
/// `.select((h) => h.cueIndex)` (or select on a listener) so they are not
/// rebuilt on the 50 ms word ticks; only the active transcript tile should
/// watch the full record.

@ProviderFor(transcriptPlaybackHighlight)
final transcriptPlaybackHighlightProvider =
    TranscriptPlaybackHighlightFamily._();

/// Current cue index (echo-aware) and karaoke current-word index.
///
/// `cueIndex` is `-1` when there are no lines. `wordIndex` is null when
/// karaoke is off / still loading, `karaokeSwitchEnabled` is false (no timed
/// words on owned media), the cue is out of range, or the position is in a
/// gap.
///
/// The 50 ms karaoke position stream is watched **only after** the karaoke
/// gate passes, so karaoke-off transcripts never subscribe to the word tick
/// stream. Consumers that only need the cue index must use
/// `.select((h) => h.cueIndex)` (or select on a listener) so they are not
/// rebuilt on the 50 ms word ticks; only the active transcript tile should
/// watch the full record.

final class TranscriptPlaybackHighlightProvider
    extends
        $FunctionalProvider<
          TranscriptPlaybackHighlight,
          TranscriptPlaybackHighlight,
          TranscriptPlaybackHighlight
        >
    with $Provider<TranscriptPlaybackHighlight> {
  /// Current cue index (echo-aware) and karaoke current-word index.
  ///
  /// `cueIndex` is `-1` when there are no lines. `wordIndex` is null when
  /// karaoke is off / still loading, `karaokeSwitchEnabled` is false (no timed
  /// words on owned media), the cue is out of range, or the position is in a
  /// gap.
  ///
  /// The 50 ms karaoke position stream is watched **only after** the karaoke
  /// gate passes, so karaoke-off transcripts never subscribe to the word tick
  /// stream. Consumers that only need the cue index must use
  /// `.select((h) => h.cueIndex)` (or select on a listener) so they are not
  /// rebuilt on the 50 ms word ticks; only the active transcript tile should
  /// watch the full record.
  TranscriptPlaybackHighlightProvider._({
    required TranscriptPlaybackHighlightFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transcriptPlaybackHighlightProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transcriptPlaybackHighlightHash();

  @override
  String toString() {
    return r'transcriptPlaybackHighlightProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TranscriptPlaybackHighlight> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TranscriptPlaybackHighlight create(Ref ref) {
    final argument = this.argument as String;
    return transcriptPlaybackHighlight(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptPlaybackHighlight value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptPlaybackHighlight>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptPlaybackHighlightProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transcriptPlaybackHighlightHash() =>
    r'c20a240bc47917a567bfeddb0ab9bb7ef5b0f2f5';

/// Current cue index (echo-aware) and karaoke current-word index.
///
/// `cueIndex` is `-1` when there are no lines. `wordIndex` is null when
/// karaoke is off / still loading, `karaokeSwitchEnabled` is false (no timed
/// words on owned media), the cue is out of range, or the position is in a
/// gap.
///
/// The 50 ms karaoke position stream is watched **only after** the karaoke
/// gate passes, so karaoke-off transcripts never subscribe to the word tick
/// stream. Consumers that only need the cue index must use
/// `.select((h) => h.cueIndex)` (or select on a listener) so they are not
/// rebuilt on the 50 ms word ticks; only the active transcript tile should
/// watch the full record.

final class TranscriptPlaybackHighlightFamily extends $Family
    with $FunctionalFamilyOverride<TranscriptPlaybackHighlight, String> {
  TranscriptPlaybackHighlightFamily._()
    : super(
        retry: null,
        name: r'transcriptPlaybackHighlightProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Current cue index (echo-aware) and karaoke current-word index.
  ///
  /// `cueIndex` is `-1` when there are no lines. `wordIndex` is null when
  /// karaoke is off / still loading, `karaokeSwitchEnabled` is false (no timed
  /// words on owned media), the cue is out of range, or the position is in a
  /// gap.
  ///
  /// The 50 ms karaoke position stream is watched **only after** the karaoke
  /// gate passes, so karaoke-off transcripts never subscribe to the word tick
  /// stream. Consumers that only need the cue index must use
  /// `.select((h) => h.cueIndex)` (or select on a listener) so they are not
  /// rebuilt on the 50 ms word ticks; only the active transcript tile should
  /// watch the full record.

  TranscriptPlaybackHighlightProvider call(String mediaId) =>
      TranscriptPlaybackHighlightProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'transcriptPlaybackHighlightProvider';
}
