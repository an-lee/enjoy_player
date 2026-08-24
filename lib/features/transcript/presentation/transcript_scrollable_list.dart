/// Scrollable transcript list with auto-scroll (active cue, or echo block in echo mode).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/transcript/transcript_density.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_interactions.dart';
import 'package:enjoy_player/features/player/application/player_state_providers.dart';
import 'package:enjoy_player/features/transcript/application/active_transcript_provider.dart';
import 'package:enjoy_player/features/transcript/application/auto_translate_controller.dart';
import 'package:enjoy_player/features/transcript/application/auto_translate_resolved_text.dart';
import 'package:enjoy_player/features/transcript/domain/auto_translate.dart';
import 'package:enjoy_player/features/transcript/application/echo_region_bounds.dart';
import 'package:enjoy_player/features/transcript/application/transcript_line_alignment.dart';
import 'package:enjoy_player/features/transcript/application/transcript_line_recording_counts_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_playback_highlight_provider.dart';
import 'package:enjoy_player/features/lookup/application/transcript_lookup_open.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_echo_region_merged_card.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_tile.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Viewport alignment used by [Scrollable.ensureVisible] and the bootstrap
/// jump estimate so the active cue sits roughly 42 % from the top of the list.
const double kTranscriptScrollAlignment = 0.42;

/// Fraction of the viewport height subtracted from the jump estimate to avoid
/// overshoot when the active cue is bootstrapped via raw line index (single-line
/// tile height) rather than the actual widget height.
const double kTranscriptScrollEstimateFactor = 0.85;

sealed class _TranscriptVirtualItem {
  const _TranscriptVirtualItem();
}

class _VirtualEcho extends _TranscriptVirtualItem {
  const _VirtualEcho(this.startLineIndex, this.endLineIndex);
  final int startLineIndex;
  final int endLineIndex;
}

class _VirtualLine extends _TranscriptVirtualItem {
  const _VirtualLine(this.lineIndex);
  final int lineIndex;
}

List<_TranscriptVirtualItem> _buildVirtualItems(
  List<TranscriptLine> lines,
  EchoState echo,
) {
  final out = <_TranscriptVirtualItem>[];
  var i = 0;
  while (i < lines.length) {
    if (echo.active && i == echo.startLineIndex) {
      out.add(_VirtualEcho(echo.startLineIndex, echo.endLineIndex));
      i = echo.endLineIndex + 1;
      continue;
    }
    out.add(_VirtualLine(i));
    i++;
  }
  return out;
}

class TranscriptScrollableList extends ConsumerStatefulWidget {
  const TranscriptScrollableList({
    required this.mediaId,
    required this.lines,
    super.key,
  });

  final String mediaId;
  final List<TranscriptLine> lines;

  @override
  ConsumerState<TranscriptScrollableList> createState() =>
      _TranscriptScrollableListState();
}

class _TranscriptScrollableListState
    extends ConsumerState<TranscriptScrollableList> {
  final ScrollController _scrollController = ScrollController();
  int _lastScrolledIndex = -1;
  int _lastEchoScrollStart = -999;
  int _lastEchoScrollEnd = -999;

  /// Bumped on each scroll request and in [dispose] to drop stale callbacks.
  int _scrollGeneration = 0;

  /// Scroll-target keys are rotated when the target line/echo bounds change so
  /// the same [GlobalKey] is never reparented across [ListView] slots.
  GlobalKey? _echoRegionScrollKey;
  (int start, int end)? _echoRegionScrollKeyBounds;
  GlobalKey? _activeLineScrollKey;
  int _activeLineScrollKeyIndex = -1;

  /// When true, the user is manually scrolling and auto-follow should not
  /// force-scroll the viewport back to the active cue.
  bool _suppressAutoScroll = false;

  List<_TranscriptVirtualItem> _cachedVirtualItems = const [];
  List<TranscriptLine>? _cachedLinesRef;
  EchoState? _cachedEchoForItems;

  TranscriptSecondaryMatcher? _secondaryMatcher;
  List<TranscriptLine>? _cachedSecondaryRef;

  @override
  void dispose() {
    _scrollGeneration++;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TranscriptScrollableList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId) {
      _lastScrolledIndex = -1;
      _lastEchoScrollStart = -999;
      _lastEchoScrollEnd = -999;
      _scrollGeneration++;
      _resetScrollTargetKeys();
      _cachedVirtualItems = const [];
      _cachedLinesRef = null;
      _cachedEchoForItems = null;
      _secondaryMatcher = null;
      _cachedSecondaryRef = null;
    }
  }

  void _resetScrollTargetKeys() {
    _echoRegionScrollKey = null;
    _echoRegionScrollKeyBounds = null;
    _activeLineScrollKey = null;
    _activeLineScrollKeyIndex = -1;
  }

  GlobalKey _scrollKeyForEcho(EchoState echo) {
    final bounds = (echo.startLineIndex, echo.endLineIndex);
    if (_echoRegionScrollKeyBounds != bounds) {
      _echoRegionScrollKeyBounds = bounds;
      _echoRegionScrollKey = GlobalKey();
    }
    return _echoRegionScrollKey!;
  }

  GlobalKey _scrollKeyForActiveLine(int lineIndex) {
    if (_activeLineScrollKeyIndex != lineIndex) {
      _activeLineScrollKeyIndex = lineIndex;
      _activeLineScrollKey = GlobalKey();
    }
    return _activeLineScrollKey!;
  }

  List<_TranscriptVirtualItem> _virtualItems(EchoState echo) {
    if (!identical(widget.lines, _cachedLinesRef) ||
        _cachedEchoForItems == null ||
        _cachedEchoForItems! != echo) {
      _cachedLinesRef = widget.lines;
      _cachedEchoForItems = echo;
      _cachedVirtualItems = _buildVirtualItems(widget.lines, echo);
    }
    return _cachedVirtualItems;
  }

  TranscriptSecondaryMatcher _matcherFor(List<TranscriptLine> secondary) {
    if (!identical(secondary, _cachedSecondaryRef) ||
        _secondaryMatcher == null) {
      _cachedSecondaryRef = secondary;
      _secondaryMatcher = TranscriptSecondaryMatcher.from(secondary);
    }
    return _secondaryMatcher!;
  }

  /// Estimated cue index at the current scroll offset (manual scroll focus).
  int _scrollFocusLineIndex() {
    final lineCount = widget.lines.length;
    if (lineCount <= 0) return 0;
    if (!_scrollController.hasClients) return 0;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return 0;
    final ratio = (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    return (ratio * (lineCount - 1)).round();
  }

  /// Whether the active cue line is roughly within the visible viewport.
  bool _isActiveCueVisible(int activeLineIndex) {
    if (!_scrollController.hasClients) return true;
    final focus = _scrollFocusLineIndex();
    return (activeLineIndex - focus).abs() <= 2;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.idle) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final activeIdx = ref
              .read(transcriptPlaybackHighlightProvider(widget.mediaId))
              .cueIndex;
          if (!_isActiveCueVisible(activeIdx)) {
            _suppressAutoScroll = false;
          }
        });
      } else {
        _suppressAutoScroll = true;
      }
    }
    return false;
  }

  bool _shouldRequestAutoTranslate(int lineIndex, int playbackHighlight) {
    final highlight = playbackHighlight >= 0 ? playbackHighlight : 0;
    final scrollFocus = _scrollFocusLineIndex();
    return (lineIndex - highlight).abs() <= kAutoTranslateViewportWindow ||
        (lineIndex - scrollFocus).abs() <= kAutoTranslateViewportWindow;
  }

  /// Conservative bootstrap scroll before the scroll-target widget is built.
  ///
  /// Uses raw line index (single-line tile height) so tall echo cards do not
  /// inflate the estimate and overshoot off-screen.
  void _jumpToLineIndexEstimate(int lineIndex, {required double alignment}) {
    if (!_scrollController.hasClients || lineIndex < 0) return;

    final lineCount = widget.lines.length;
    if (lineCount <= 0) return;

    final pos = _scrollController.position;
    final ratio = lineIndex / lineCount;
    final estimated = ratio * pos.maxScrollExtent;
    final alignmentAdjust =
        alignment * pos.viewportDimension * kTranscriptScrollEstimateFactor;
    _scrollController.jumpTo(
      (estimated - alignmentAdjust).clamp(0.0, pos.maxScrollExtent),
    );
  }

  void _ensureVisible(
    BuildContext ctx, {
    required double alignment,
    required Duration duration,
    required Curve curve,
    required int generation,
  }) {
    if (!mounted || generation != _scrollGeneration) return;
    try {
      unawaited(
        Scrollable.ensureVisible(
          ctx,
          alignment: alignment,
          duration: duration,
          curve: curve,
        ),
      );
    } catch (_) {
      // Target may detach during route pop while animation is in flight.
    }
  }

  void _performTranscriptScroll({required int generation}) {
    if (!mounted || generation != _scrollGeneration) return;

    final echo =
        activeEchoForTranscript(
          ref.read(echoModeProvider),
          widget.lines.length,
        ) ??
        EchoState.inactive;
    final tok = EnjoyThemeTokens.of(context);

    if (echo.active) {
      final echoKey = _scrollKeyForEcho(echo);
      final ctx = echoKey.currentContext;
      if (ctx != null) {
        _ensureVisible(
          ctx,
          alignment: 0.0,
          duration: tok.motionStandard,
          curve: Curves.easeOutCubic,
          generation: generation,
        );
        return;
      }

      _jumpToLineIndexEstimate(echo.startLineIndex, alignment: 0.0);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _scrollGeneration) return;
        final ctx2 = echoKey.currentContext;
        if (ctx2 == null) return;
        _ensureVisible(
          ctx2,
          alignment: 0.0,
          duration: tok.motionStandard,
          curve: Curves.easeOutCubic,
          generation: generation,
        );
      });
      return;
    }

    final active = ref
        .read(transcriptPlaybackHighlightProvider(widget.mediaId))
        .cueIndex;
    if (active < 0) return;

    final activeKey = _scrollKeyForActiveLine(active);
    final ctx = activeKey.currentContext;
    if (ctx != null) {
      _ensureVisible(
        ctx,
        alignment: kTranscriptScrollAlignment,
        duration: tok.motionStandard,
        curve: Curves.easeOutCubic,
        generation: generation,
      );
      return;
    }

    _jumpToLineIndexEstimate(active, alignment: kTranscriptScrollAlignment);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _scrollGeneration) return;
      final ctx2 = activeKey.currentContext;
      if (ctx2 == null) return;
      _ensureVisible(
        ctx2,
        alignment: kTranscriptScrollAlignment,
        duration: tok.motionStandard,
        curve: Curves.easeOutCubic,
        generation: generation,
      );
    });
  }

  void _scheduleTranscriptScrollIntoView({bool force = false}) {
    final playingAsync = ref.read(playerIsPlayingProvider);
    final playing = switch (playingAsync) {
      AsyncData(:final value) => value,
      _ => false,
    };
    if (!playing) return;

    final echo =
        activeEchoForTranscript(
          ref.read(echoModeProvider),
          widget.lines.length,
        ) ??
        EchoState.inactive;
    final activeForUi = ref
        .read(transcriptPlaybackHighlightProvider(widget.mediaId))
        .cueIndex;

    if (echo.active) {
      if (!force &&
          echo.startLineIndex == _lastEchoScrollStart &&
          echo.endLineIndex == _lastEchoScrollEnd) {
        return;
      }
      _lastEchoScrollStart = echo.startLineIndex;
      _lastEchoScrollEnd = echo.endLineIndex;
    } else {
      if (activeForUi < 0) return;
      if (!force && activeForUi == _lastScrolledIndex) return;
      _lastScrolledIndex = activeForUi;
    }

    if (force && _suppressAutoScroll) return;

    _scrollGeneration++;
    final generation = _scrollGeneration;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _scrollGeneration) return;
      _performTranscriptScroll(generation: generation);
    });
  }

  @override
  Widget build(BuildContext context) {
    final echo =
        activeEchoForTranscript(
          ref.watch(echoModeProvider),
          widget.lines.length,
        ) ??
        EchoState.inactive;
    final activeForUi = ref.watch(
      transcriptPlaybackHighlightProvider(
        widget.mediaId,
      ).select((h) => h.cueIndex),
    );
    final density = TranscriptDensity.of(context);
    final secondaryAsync = ref.watch(
      secondaryTranscriptLinesForMediaProvider(widget.mediaId),
    );
    final secondaryLines = secondaryAsync.value ?? <TranscriptLine>[];
    final secondaryMatcher = _matcherFor(secondaryLines);
    final autoTranslateMode = ref.watch(
      autoTranslateCtrlProvider(widget.mediaId).select(
        (s) => (
          isActive: s.isActive,
          aiTranscriptId: s.aiTranscriptId,
          sourceLanguage: s.sourceLanguage,
          targetLanguage: s.targetLanguage,
        ),
      ),
    );
    final secondaryId = ref
        .watch(secondaryTranscriptIdProvider(widget.mediaId))
        .value;
    final autoTranslateActive =
        autoTranslateMode.isActive &&
        autoTranslateMode.aiTranscriptId != null &&
        secondaryId == autoTranslateMode.aiTranscriptId;
    final l10n = AppLocalizations.of(context);
    final items = _virtualItems(echo);
    final lineRecordingCounts = ref.watch(
      transcriptLineRecordingCountsProvider(widget.mediaId),
    );

    final autoTranslateCtrl = ref.read(
      autoTranslateCtrlProvider(widget.mediaId),
    );

    ref.listen(
      transcriptPlaybackHighlightProvider(
        widget.mediaId,
      ).select((h) => h.cueIndex),
      (prev, next) {
        if (prev == next) return;
        final echoNow = ref.read(echoModeProvider);
        if (echoNow.active &&
            (next < echoNow.startLineIndex || next > echoNow.endLineIndex)) {
          return;
        }
        if (prev == null || (next - prev).abs() > 1) {
          _suppressAutoScroll = false;
        }
        _scheduleTranscriptScrollIntoView(force: true);
      },
    );
    ref.listen(playerIsPlayingProvider, (_, _) {
      _scheduleTranscriptScrollIntoView(force: true);
    });
    ref.listen(
      echoModeProvider.select(
        (e) => (e.active, e.startLineIndex, e.endLineIndex),
      ),
      (prev, next) {
        if (prev == next) return;
        _suppressAutoScroll = false;
        _scheduleTranscriptScrollIntoView(force: true);
      },
    );

    return Semantics(
      explicitChildNodes: true,
      label:
          AppLocalizations.of(context)?.transcriptAccessibilityTranscriptList ??
          'Transcript',
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: ListView.builder(
          scrollCacheExtent: const ScrollCacheExtent.pixels(1400),
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            density.listHorizontalPadding,
            density.listVerticalPadding,
            density.listHorizontalPadding,
            density.listVerticalPadding + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            switch (item) {
              case _VirtualEcho e:
                return Padding(
                  key: ValueKey<String>(
                    'echo-${e.startLineIndex}-${e.endLineIndex}',
                  ),
                  padding: EdgeInsets.only(bottom: density.lineInterGap),
                  child: KeyedSubtree(
                    key: _scrollKeyForEcho(echo),
                    child: EchoRegionMergedCard(
                      mediaId: widget.mediaId,
                      lines: widget.lines,
                      echo: echo,
                      activeCueIndex: activeForUi,
                      secondaryLines: secondaryLines,
                      secondaryMatcher: secondaryMatcher,
                    ),
                  ),
                );
              case _VirtualLine vl:
                final lineIndex = vl.lineIndex;
                final line = widget.lines[lineIndex];
                final isActive = lineIndex == activeForUi;
                final inEcho =
                    echo.active &&
                    lineIndex >= echo.startLineIndex &&
                    lineIndex <= echo.endLineIndex;
                final resolved = resolveAutoTranslateTextForDisplay(
                  autoTranslateActive: autoTranslateActive,
                  primaryLines: widget.lines,
                  aiLines: secondaryLines,
                  lineIndex: lineIndex,
                  sourceLanguage: autoTranslateMode.sourceLanguage,
                  targetLanguage: autoTranslateMode.targetLanguage,
                  matcher: secondaryMatcher,
                  line: line,
                  isLineFailed: autoTranslateCtrl.isLineFailed,
                  isLineInFlight: autoTranslateCtrl.isLineInFlight,
                  l10nLineFailed: l10n?.subtitlesAutoTranslateLineFailed,
                  l10nLinePending: l10n?.subtitlesAutoTranslatePendingLine,
                );
                final secondaryText = resolved.secondaryText;
                final canRetranslateLine = resolved.canRetranslate;
                final lineFailed = resolved.isFailed;

                if (autoTranslateActive &&
                    (secondaryText == null || secondaryText.trim().isEmpty) &&
                    !lineFailed &&
                    _shouldRequestAutoTranslate(lineIndex, activeForUi)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final highlight = ref
                        .read(
                          transcriptPlaybackHighlightProvider(widget.mediaId),
                        )
                        .cueIndex;
                    if (!_shouldRequestAutoTranslate(lineIndex, highlight)) {
                      return;
                    }
                    ref
                        .read(
                          autoTranslateCtrlProvider(widget.mediaId).notifier,
                        )
                        .requestTranslateLine(lineIndex);
                  });
                }

                final selectable = isActive;
                Widget tile = TranscriptLineTile(
                  line: line,
                  lineIndex: lineIndex,
                  mediaId: widget.mediaId,
                  secondaryText: secondaryText,
                  isActive: isActive,
                  inEcho: inEcho,
                  groupedInEcho: false,
                  selectable: selectable,
                  recordingCount: lineRecordingCounts?[lineIndex],
                  onLookupRequested: selectable
                      ? (t) => openTranscriptLookup(
                          ref: ref,
                          context: context,
                          selectedText: t,
                          lines: widget.lines,
                        )
                      : null,
                  onRetranslateSecondary: canRetranslateLine
                      ? () => unawaited(
                          ref
                              .read(
                                autoTranslateCtrlProvider(
                                  widget.mediaId,
                                ).notifier,
                              )
                              .retranslateLine(lineIndex),
                        )
                      : null,
                  onTap: () => ref
                      .read(playerInteractionsProvider.notifier)
                      .seekToLine(line, lineIndex),
                );

                if (isActive) {
                  tile = KeyedSubtree(
                    key: _scrollKeyForActiveLine(lineIndex),
                    child: tile,
                  );
                }

                return Padding(
                  key: ValueKey<String>('line-$lineIndex'),
                  padding: EdgeInsets.only(bottom: density.lineInterGap),
                  child: tile,
                );
            }
          },
        ),
      ),
    );
  }
}
