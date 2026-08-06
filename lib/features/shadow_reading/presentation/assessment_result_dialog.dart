/// Detailed pronunciation assessment (ported from web `AssessmentResultDialog`).
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:azure_speech/azure_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/audio/recording_preview_player.dart';
import 'package:enjoy_player/core/audio/recording_preview_player_provider.dart';
import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/core/theme/widgets/sheet_drag_handle.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';
import 'package:enjoy_player/features/pronounce/presentation/pronounce_icon_button.dart';
import 'package:enjoy_player/features/shadow_reading/domain/assessment_word_timing.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import 'score_level.dart';

final _log = logNamed('assessmentResult');

/// Shows pronunciation assessment: [Dialog] when wide, modal bottom sheet when narrow.
///
/// Uses Enjoy modals (root navigator by default) so the result clears the
/// permanent player surface host on YouTube (ADR-0065).
///
/// Pass [recordingPath] (typically [RecordingRow.localPath]) to enable take
/// replay, karaoke highlight, and per-word clips.
Future<void> showAssessmentResultDialog({
  required BuildContext context,
  required AzurePronunciationAssessmentResult assessment,
  String? localeTag,
  String? recordingPath,
}) {
  final l10n = AppLocalizations.of(context)!;
  final nBest = assessment.nBest.isEmpty ? null : assessment.nBest.first;
  if (nBest == null) {
    return showEnjoyAlertDialog<void>(
      context: context,
      title: Text(l10n.assessmentTitle),
      content: Text(l10n.assessmentNoResultSummary),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
        ),
      ],
    );
  }

  final resolvedLocale = localeTag ?? kDefaultLearningLanguageTag;
  final tokens = EnjoyThemeTokens.of(context);
  final wide = MediaQuery.sizeOf(context).width >= tokens.breakpointRail;
  if (wide) {
    return showEnjoyDialog<void>(
      context: context,
      builder: (ctx) => AssessmentResultDialog(
        assessment: assessment,
        localeTag: resolvedLocale,
        recordingPath: recordingPath,
      ),
    );
  }
  return showEnjoySheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => AssessmentResultSheet(
      assessment: assessment,
      localeTag: resolvedLocale,
      recordingPath: recordingPath,
    ),
  );
}

class AssessmentResultDialog extends ConsumerStatefulWidget {
  const AssessmentResultDialog({
    required this.assessment,
    required this.localeTag,
    this.recordingPath,
    super.key,
  });

  final AzurePronunciationAssessmentResult assessment;
  final String localeTag;
  final String? recordingPath;

  @override
  ConsumerState<AssessmentResultDialog> createState() =>
      _AssessmentResultDialogState();
}

class _AssessmentResultDialogState
    extends ConsumerState<AssessmentResultDialog> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final nBest = widget.assessment.nBest.isEmpty
        ? null
        : widget.assessment.nBest.first;
    if (nBest == null) {
      return AlertDialog(
        title: Text(l10n.assessmentTitle),
        content: Text(l10n.assessmentNoResultSummary),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: math.min(640, MediaQuery.sizeOf(context).height * 0.88),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.assessmentTitle, style: tt.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          l10n.assessmentDescription,
                          style: tt.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: _AssessmentResultBody(
                  nBest: nBest,
                  localeTag: widget.localeTag,
                  recordingPath: widget.recordingPath,
                  layoutCompact: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AssessmentResultSheet extends ConsumerStatefulWidget {
  const AssessmentResultSheet({
    required this.assessment,
    required this.localeTag,
    this.recordingPath,
    super.key,
  });

  final AzurePronunciationAssessmentResult assessment;
  final String localeTag;
  final String? recordingPath;

  @override
  ConsumerState<AssessmentResultSheet> createState() =>
      _AssessmentResultSheetState();
}

class _AssessmentResultSheetState extends ConsumerState<AssessmentResultSheet> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = EnjoyThemeTokens.of(context);
    final nBest = widget.assessment.nBest.first;
    final padH = t.space16 + t.space4;
    final bottomInset = MediaQuery.paddingOf(context).bottom + t.space24;

    // Match dictionary / subtitle pickers: [showEnjoySheet] already passes
    // useSafeArea: true. Wrapping [DraggableScrollableSheet] in another
    // [SafeArea] fights the sheet's height fraction math on notched Android
    // devices and can make the sheet appear to "do nothing".
    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PaddedSheetDragHandle(),
            Padding(
              padding: EdgeInsets.fromLTRB(padH, t.space8, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.assessmentTitle, style: tt.titleLarge),
                        SizedBox(height: t.space4),
                        Text(
                          l10n.assessmentDescription,
                          style: tt.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      fixedSize: const Size(48, 48),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  padH,
                  t.space16,
                  padH,
                  bottomInset,
                ),
                children: [
                  _AssessmentResultBody(
                    nBest: nBest,
                    localeTag: widget.localeTag,
                    recordingPath: widget.recordingPath,
                    layoutCompact: true,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _TakePlayMode { idle, fullTake, wordClip }

/// Owns selection, take/clip playback, karaoke highlight, and audio mutex.
class _AssessmentResultBody extends ConsumerStatefulWidget {
  const _AssessmentResultBody({
    required this.nBest,
    required this.localeTag,
    required this.recordingPath,
    required this.layoutCompact,
  });

  final AzureNBestResult nBest;
  final String localeTag;
  final String? recordingPath;
  final bool layoutCompact;

  @override
  ConsumerState<_AssessmentResultBody> createState() =>
      _AssessmentResultBodyState();
}

class _AssessmentResultBodyState extends ConsumerState<_AssessmentResultBody> {
  AzureWordAssessment? _selected;
  PronouncePlaybackController? _pronounce;
  RecordingPreviewPlayback? _preview;
  _TakePlayMode _mode = _TakePlayMode.idle;
  int? _karaokeWordIndex;
  bool _recordingPlayable = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;

  @override
  void initState() {
    super.initState();
    final path = widget.recordingPath?.trim();
    _recordingPlayable =
        path != null && path.isNotEmpty && File(path).existsSync();
  }

  @override
  void dispose() {
    // Cancel subscriptions without awaiting (dispose must stay synchronous).
    unawaited(_positionSub?.cancel() ?? Future<void>.value());
    unawaited(_playingSub?.cancel() ?? Future<void>.value());
    _positionSub = null;
    _playingSub = null;
    final preview = _preview;
    if (preview != null) {
      unawaited(
        preview.stop().catchError((Object e, StackTrace st) {
          _log.fine('preview stop on dispose failed', e, st);
        }),
      );
    }
    final pronounce = _pronounce;
    if (pronounce != null) {
      unawaited(
        pronounce.stop().catchError((Object e, StackTrace st) {
          _log.fine('pronounce stop on dispose failed', e, st);
        }),
      );
    }
    super.dispose();
  }

  Future<void> _cancelPreviewSubs() async {
    await _positionSub?.cancel();
    _positionSub = null;
    await _playingSub?.cancel();
    _playingSub = null;
  }

  void _stopPronounce() {
    try {
      final ctrl = ref.read(pronouncePlaybackControllerProvider.notifier);
      _pronounce = ctrl;
      unawaited(
        ctrl.stop().catchError((Object e, StackTrace st) {
          _log.fine('pronounce stop failed', e, st);
        }),
      );
    } on Object catch (e, st) {
      _log.fine('pronounce stop skipped', e, st);
    }
  }

  Future<void> _stopPreviewPlayback({bool clearKaraoke = true}) async {
    await _cancelPreviewSubs();
    final preview = _preview;
    if (preview != null) {
      try {
        await preview.stop();
      } on Object catch (e, st) {
        _log.warning('preview stop failed', e, st);
      }
    }
    if (!mounted) return;
    setState(() {
      _mode = _TakePlayMode.idle;
      if (clearKaraoke) _karaokeWordIndex = null;
    });
  }

  void _listenPlayingEnded(RecordingPreviewPlayback preview) {
    unawaited(_playingSub?.cancel());
    _playingSub = preview.playing.listen((playing) {
      if (!mounted) return;
      if (!playing && _mode != _TakePlayMode.idle) {
        setState(() {
          _mode = _TakePlayMode.idle;
          _karaokeWordIndex = null;
        });
        unawaited(_cancelPreviewSubs());
      }
    });
  }

  Future<void> _toggleFullTake() async {
    final path = widget.recordingPath?.trim();
    final preview = _preview;
    if (path == null ||
        path.isEmpty ||
        !_recordingPlayable ||
        preview == null) {
      return;
    }

    if (_mode == _TakePlayMode.fullTake) {
      await _stopPreviewPlayback();
      return;
    }

    _stopPronounce();
    await _cancelPreviewSubs();
    try {
      await preview.play(path);
    } on Object catch (e, st) {
      _log.warning('full take play failed', e, st);
      if (!mounted) return;
      setState(() {
        _mode = _TakePlayMode.idle;
        _karaokeWordIndex = null;
        _recordingPlayable = File(path).existsSync();
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _mode = _TakePlayMode.fullTake;
      _karaokeWordIndex = activeWordIndex(widget.nBest.words, 0);
    });
    _positionSub = preview.position.listen((pos) {
      if (!mounted || _mode != _TakePlayMode.fullTake) return;
      final next = activeWordIndex(widget.nBest.words, pos.inMilliseconds);
      if (next != _karaokeWordIndex) {
        setState(() => _karaokeWordIndex = next);
      }
    });
    _listenPlayingEnded(preview);
  }

  Future<void> _toggleWordClip(AzureWordAssessment word) async {
    final path = widget.recordingPath?.trim();
    final bounds = wordClipBounds(word);
    final preview = _preview;
    if (path == null ||
        path.isEmpty ||
        !_recordingPlayable ||
        bounds == null ||
        preview == null) {
      return;
    }

    if (_mode == _TakePlayMode.wordClip) {
      await _stopPreviewPlayback();
      return;
    }

    _stopPronounce();
    await _cancelPreviewSubs();
    try {
      await preview.playClip(path, bounds.start, bounds.end);
    } on Object catch (e, st) {
      _log.warning('word clip play failed', e, st);
      if (!mounted) return;
      setState(() {
        _mode = _TakePlayMode.idle;
        _karaokeWordIndex = null;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _mode = _TakePlayMode.wordClip;
      _karaokeWordIndex = null;
    });
    _listenPlayingEnded(preview);
  }

  void _onToggleWord(AzureWordAssessment w) {
    // Stop take/clip immediately (spec: chip select ends full-take karaoke).
    _stopPronounce();
    final preview = _preview;
    if (preview != null) {
      unawaited(
        preview.stop().catchError((Object e, StackTrace st) {
          _log.fine('preview stop on chip select failed', e, st);
        }),
      );
    }
    unawaited(_cancelPreviewSubs());
    setState(() {
      _mode = _TakePlayMode.idle;
      _selected = identical(_selected, w) ? null : w;
      _karaokeWordIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    _pronounce ??= ref.read(pronouncePlaybackControllerProvider.notifier);
    _preview ??= ref.read(recordingPreviewPlayerProvider);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final scores = widget.nBest.pronunciationAssessment;
    final words = widget.nBest.words;

    final overall = scores.pronScore.round();
    final accuracy = scores.accuracyScore.round();
    final completeness = scores.completenessScore.round();
    final fluency = scores.fluencyScore.round();
    final prosody = scores.prosodyScore?.round();

    final takePlaying = _mode == _TakePlayMode.fullTake;
    final takeTooltip = !_recordingPlayable
        ? l10n.assessmentRecordingUnavailable
        : takePlaying
        ? l10n.assessmentStopMyRecording
        : l10n.assessmentPlayMyRecording;

    final scoreBars = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreBar(
          label: l10n.assessmentAccuracy,
          value: accuracy,
          scheme: scheme,
        ),
        const SizedBox(height: 12),
        _ScoreBar(
          label: l10n.assessmentCompleteness,
          value: completeness,
          scheme: scheme,
        ),
        const SizedBox(height: 12),
        _ScoreBar(
          label: l10n.assessmentFluency,
          value: fluency,
          scheme: scheme,
        ),
        if (prosody != null) ...[
          const SizedBox(height: 12),
          _ScoreBar(
            label: l10n.assessmentProsody,
            value: prosody,
            scheme: scheme,
          ),
        ],
      ],
    );

    final takeControl = EnjoyTappableIcon(
      tooltip: takeTooltip,
      semanticLabel: takeTooltip,
      iconSize: 22,
      icon: takePlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
      color: _recordingPlayable
          ? scheme.primary
          : scheme.onSurface.withValues(alpha: 0.38),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        fixedSize: const Size(44, 44),
      ),
      onPressed: _recordingPlayable
          ? () {
              unawaited(_toggleFullTake());
            }
          : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.layoutCompact) ...[
          Center(
            child: _OverallScoreRing(
              score: overall,
              label: l10n.assessmentOverallScore,
              scheme: scheme,
              tt: tt,
              trailing: takeControl,
            ),
          ),
          const SizedBox(height: 24),
          scoreBars,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OverallScoreRing(
                score: overall,
                label: l10n.assessmentOverallScore,
                scheme: scheme,
                tt: tt,
                trailing: takeControl,
              ),
              const SizedBox(width: 24),
              Expanded(child: scoreBars),
            ],
          ),
        const SizedBox(height: 24),
        Text(l10n.assessmentPronunciationAnalysis, style: tt.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < words.length; i++)
              _WordChip(
                word: words[i],
                selected: identical(_selected, words[i]),
                karaokeCurrent: _karaokeWordIndex == i,
                scheme: scheme,
                onTap: () => _onToggleWord(words[i]),
              ),
          ],
        ),
        if (_selected != null) ...[
          const SizedBox(height: 16),
          _SelectedWordPanel(
            word: _selected!,
            localeTag: widget.localeTag,
            l10n: l10n,
            scheme: scheme,
            tt: tt,
            recordingPlayable: _recordingPlayable,
            clipPlaying: _mode == _TakePlayMode.wordClip,
            onToggleClip: () => unawaited(_toggleWordClip(_selected!)),
            beforeModelPronounce: () => _stopPreviewPlayback(),
          ),
        ],
      ],
    );
  }
}

class _OverallScoreRing extends StatelessWidget {
  const _OverallScoreRing({
    required this.score,
    required this.label,
    required this.scheme,
    required this.tt,
    this.trailing,
  });

  final int score;
  final String label;
  final ColorScheme scheme;
  final TextTheme tt;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final level = assessmentScoreLevel(score);
    final tint = assessmentScoreColor(scheme, level);
    return Column(
      children: [
        Text(
          label,
          style: tt.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: (score / 100).clamp(0.0, 1.0),
                  strokeWidth: 10,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: tint,
                ),
              ),
              Text(
                '$score',
                style: tt.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(height: 4), trailing!],
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.label,
    required this.value,
    required this.scheme,
  });

  final String label;
  final int value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final level = assessmentScoreLevel(value);
    final tint = assessmentScoreColor(scheme, level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: tt.labelLarge),
            Text(
              '$value',
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: tint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            color: tint,
          ),
        ),
      ],
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.selected,
    required this.karaokeCurrent,
    required this.scheme,
    required this.onTap,
  });

  final AzureWordAssessment word;
  final bool selected;
  final bool karaokeCurrent;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pa = word.pronunciationAssessment;
    final score = pa.accuracyScore;
    final err = pa.errorType;
    final (Color fg, Color? bg, Color? border) = _wordColors(
      scheme,
      err,
      score,
    );

    final highlightBorder = karaokeCurrent
        ? scheme.tertiary
        : selected
        ? (border ?? scheme.primary)
        : Colors.transparent;
    final highlightWidth = karaokeCurrent || selected ? 2.0 : 0.0;

    return Material(
      color: karaokeCurrent
          ? scheme.tertiaryContainer.withValues(alpha: 0.55)
          : (bg ?? scheme.surfaceContainerHighest),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: highlightBorder, width: highlightWidth),
          ),
          child: Text(
            word.word,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: karaokeCurrent ? scheme.onTertiaryContainer : fg,
              decoration: err == 'Insertion'
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

(Color fg, Color? bg, Color? border) _wordColors(
  ColorScheme scheme,
  String errorType,
  double score,
) {
  switch (errorType) {
    case 'Insertion':
      return (scheme.error, scheme.error.withValues(alpha: 0.12), scheme.error);
    case 'Omission':
      return (
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        scheme.outline,
      );
    case 'Mispronunciation':
      return (scheme.error, scheme.error.withValues(alpha: 0.12), scheme.error);
    case 'UnexpectedBreak':
      return (
        scheme.secondary,
        scheme.secondary.withValues(alpha: 0.12),
        scheme.secondary,
      );
    case 'MissingBreak':
      return (
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
        scheme.outline,
      );
    case 'Monotone':
      return (
        scheme.tertiary,
        scheme.tertiary.withValues(alpha: 0.08),
        scheme.tertiary,
      );
    case 'None':
    default:
      final level = assessmentScoreLevel(score);
      final c = assessmentScoreColor(scheme, level);
      final bg = assessmentScoreBackground(scheme, level);
      return (c, bg, c);
  }
}

class _SelectedWordPanel extends StatelessWidget {
  const _SelectedWordPanel({
    required this.word,
    required this.localeTag,
    required this.l10n,
    required this.scheme,
    required this.tt,
    required this.recordingPlayable,
    required this.clipPlaying,
    required this.onToggleClip,
    required this.beforeModelPronounce,
  });

  final AzureWordAssessment word;
  final String localeTag;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final TextTheme tt;
  final bool recordingPlayable;
  final bool clipPlaying;
  final VoidCallback onToggleClip;
  final Future<void> Function() beforeModelPronounce;

  @override
  Widget build(BuildContext context) {
    final pa = word.pronunciationAssessment;
    final err = pa.errorType;
    final acc = pa.accuracyScore;
    final clipUsable = recordingPlayable && isWordClipUsable(word);
    final clipTooltip = !recordingPlayable
        ? l10n.assessmentRecordingUnavailable
        : !isWordClipUsable(word)
        ? l10n.assessmentClipUnavailable
        : clipPlaying
        ? l10n.assessmentStopMyClip
        : l10n.assessmentPlayMyClip;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    word.word,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PronounceIconButton(
                  text: word.word,
                  localeTag: localeTag,
                  surfaceId: PronounceSurfaceId.assessment,
                  compact: true,
                  beforePlay: beforeModelPronounce,
                ),
                EnjoyTappableIcon(
                  tooltip: clipTooltip,
                  semanticLabel: clipTooltip,
                  iconSize: 20,
                  icon: clipPlaying
                      ? Icons.stop_rounded
                      : Icons.record_voice_over_rounded,
                  color: clipUsable
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface.withValues(alpha: 0.38),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    fixedSize: const Size(40, 40),
                  ),
                  onPressed: clipUsable ? onToggleClip : null,
                ),
                if (err != 'None')
                  Text(
                    _errorTypeLabel(l10n, err),
                    style: tt.labelMedium?.copyWith(color: scheme.error),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.assessmentAccuracyScore, style: tt.labelLarge),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox.shrink(),
                Text(
                  '${acc.round()}%',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: assessmentScoreColor(
                      scheme,
                      assessmentScoreLevel(acc),
                    ),
                  ),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (acc / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                color: assessmentScoreColor(scheme, assessmentScoreLevel(acc)),
              ),
            ),
            if (word.syllables != null && word.syllables!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.assessmentSyllables, style: tt.labelLarge),
              const SizedBox(height: 4),
              Text(
                word.syllables!.map((s) => s.syllable).join(' · '),
                style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (word.phonemes != null && word.phonemes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.assessmentPhonemes, style: tt.labelLarge),
              const SizedBox(height: 4),
              Text(
                '/${word.phonemes!.map((p) => p.phoneme).join('')}/',
                style: tt.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            if (err != 'None') ...[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scheme.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _errorExplanation(l10n, err),
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _errorTypeLabel(AppLocalizations l10n, String errorType) {
  return switch (errorType) {
    'Omission' => l10n.assessmentErrorTypeOmission,
    'Insertion' => l10n.assessmentErrorTypeInsertion,
    'Mispronunciation' => l10n.assessmentErrorTypeMispronunciation,
    'UnexpectedBreak' => l10n.assessmentErrorTypeUnexpectedBreak,
    'MissingBreak' => l10n.assessmentErrorTypeMissingBreak,
    'Monotone' => l10n.assessmentErrorTypeMonotone,
    'None' => l10n.assessmentErrorTypeCorrect,
    _ => errorType,
  };
}

String _errorExplanation(AppLocalizations l10n, String errorType) {
  return switch (errorType) {
    'Omission' => l10n.assessmentErrorExplOmission,
    'Insertion' => l10n.assessmentErrorExplInsertion,
    'Mispronunciation' => l10n.assessmentErrorExplMispronunciation,
    'UnexpectedBreak' => l10n.assessmentErrorExplUnexpectedBreak,
    'MissingBreak' => l10n.assessmentErrorExplMissingBreak,
    'Monotone' => l10n.assessmentErrorExplMonotone,
    'None' => l10n.assessmentErrorExplCorrect,
    _ => l10n.assessmentErrorExplCorrect,
  };
}
