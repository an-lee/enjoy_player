/// Shared assessment result body widget — owns selection, take / clip
/// playback, karaoke highlight, and the audio mutex with the
/// pronounce-playback controller.
///
/// Both the wide [AssessmentResultDialog] and the narrow [AssessmentResultSheet]
/// mount this widget as their content so playback state and lifecycle are
/// owned in exactly one place.
///
/// Renamed from the legacy `_AssessmentResultBody` because the widget is now
/// imported across library boundaries.
library;

import 'dart:async';
import 'dart:io';

import 'package:azure_speech/azure_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/audio/recording_preview_player.dart';
import 'package:enjoy_player/core/audio/recording_preview_player_provider.dart';
import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/shadow_reading/domain/assessment_word_timing.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import 'assessment_result_widgets.dart';

final _log = logNamed('assessmentResult');

enum _TakePlayMode { idle, fullTake, wordClip }

class AssessmentResultBody extends ConsumerStatefulWidget {
  const AssessmentResultBody({
    required this.nBest,
    required this.localeTag,
    required this.recordingPath,
    required this.layoutCompact,
    super.key,
  });

  final AzureNBestResult nBest;
  final String localeTag;
  final String? recordingPath;

  /// When `true`, the overall score ring stacks above the score bars
  /// (used by the narrow modal sheet); when `false`, ring and bars are
  /// laid out side-by-side (used by the wide Material dialog).
  final bool layoutCompact;

  @override
  ConsumerState<AssessmentResultBody> createState() =>
      _AssessmentResultBodyState();
}

class _AssessmentResultBodyState extends ConsumerState<AssessmentResultBody> {
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
        ScoreBar(
          label: l10n.assessmentAccuracy,
          value: accuracy,
          scheme: scheme,
        ),
        const SizedBox(height: 12),
        ScoreBar(
          label: l10n.assessmentCompleteness,
          value: completeness,
          scheme: scheme,
        ),
        const SizedBox(height: 12),
        ScoreBar(label: l10n.assessmentFluency, value: fluency, scheme: scheme),
        if (prosody != null) ...[
          const SizedBox(height: 12),
          ScoreBar(
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
            child: OverallScoreRing(
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
              OverallScoreRing(
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
              WordChip(
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
          SelectedWordPanel(
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
