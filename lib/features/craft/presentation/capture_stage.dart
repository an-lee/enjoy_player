/// Capture stage: voice-first input for the Craft Express flow.
///
/// Owns the [AudioRecorder] instance (recreated after each stop, mirroring
/// the proven pattern from `ShadowReadingPanel`). Provides a large mic button
/// for recording and a "type instead" text fallback.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/utils/time_format.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/features/craft/application/craft_controller.dart';
import 'package:enjoy_player/features/craft/domain/craft_job_state.dart';
import 'package:enjoy_player/features/craft/presentation/widgets/craft_failure_card.dart';
import 'package:enjoy_player/features/craft/presentation/widgets/craft_loading_view.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Voice capture stage for the Express flow.
class CaptureStage extends ConsumerStatefulWidget {
  const CaptureStage({super.key});

  @override
  ConsumerState<CaptureStage> createState() => _CaptureStageState();
}

class _CaptureStageState extends ConsumerState<CaptureStage> {
  static final _log = logNamed('craft.capture');

  static const _maxAmplitudeBars = 40;

  /// Recreated after every `stop()` — `record` on Windows can keep stale
  /// Media Foundation state on the same instance.
  AudioRecorder _recorder = AudioRecorder();
  bool _recordingPending = false;
  bool _textMode = false;

  /// True while this widget owns an in-flight capture on [CraftController].
  /// Tracked locally so [dispose] can clear the session flag without [ref].
  bool _sessionCapturing = false;
  CraftController? _craft;

  DateTime? _recordingStartedAt;
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTimer;

  /// Ring-buffer for amplitude samples — avoids per-tick list allocation.
  late final Float32List _amplitudeBuffer = Float32List(_maxAmplitudeBars);
  int _amplitudeWriteIndex = 0;
  int _amplitudeCount = 0;
  StreamSubscription? _amplitudeSub;

  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _craft ??= ref.read(craftControllerProvider.notifier);
  }

  @override
  void dispose() {
    _stopElapsedTimer();
    _cancelAmplitudeStream();
    _textController.dispose();
    _focusNode.dispose();
    // Leaving mid-record must clear the session-scoped isCapturing flag;
    // otherwise reopen shows a dead Stop UI that can never recover.
    // Do not use [ref] here — Riverpod forbids it during unmount.
    if (_sessionCapturing) {
      _craft?.cancelCapture();
      _sessionCapturing = false;
    }
    unawaited(() async {
      try {
        await _recorder.stop();
      } catch (_) {}
      try {
        await _recorder.dispose();
      } catch (_) {}
    }());
    super.dispose();
  }

  void _cancelAmplitudeStream() {
    unawaited(_amplitudeSub?.cancel());
    _amplitudeSub = null;
  }

  RecordConfig _buildConfig() => const RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(craftControllerProvider);

    if (state.isBusy) return;
    _recordingPending = true;

    // Permission check.
    bool granted;
    try {
      granted = await _recorder.hasPermission();
    } catch (e, st) {
      _log.warning('hasPermission failed', e, st);
      _recordingPending = false;
      if (mounted) setState(() {});
      return;
    }
    if (!granted) {
      _recordingPending = false;
      if (mounted) {
        AppNotice.warning(context, l10n.craftRecordingMicDenied);
      }
      return;
    }

    // Temp output path.
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/craft_recordings');
    await dir.create(recursive: true);
    final outPath =
        '${dir.path}/craft_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _recorder.start(_buildConfig(), path: outPath);
    } catch (e, st) {
      _log.warning('recorder.start failed', e, st);
      _recordingPending = false;
      await _resetRecorderInstance();
      if (mounted) setState(() {});
      return;
    }

    _recordingPending = false;
    _recordingStartedAt = DateTime.now();
    _elapsed = Duration.zero;
    _amplitudeWriteIndex = 0;
    _amplitudeCount = 0;
    _startElapsedTimer();
    _startAmplitudeStream();

    ref.read(craftControllerProvider.notifier).startCapture();
    _sessionCapturing = true;
    if (mounted) setState(() {});
  }

  Future<void> _stopRecording() async {
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e, st) {
      _log.warning('recorder.stop failed', e, st);
    }
    _stopElapsedTimer();
    _cancelAmplitudeStream();
    _recordingStartedAt = null;
    _amplitudeWriteIndex = 0;
    _amplitudeCount = 0;
    _recordingPending = false;

    await _resetRecorderInstance();

    if (path == null || path.isEmpty) {
      _log.warning('recorder.stop returned no path');
      // Defensive: clear stuck isCapturing when stop yields nothing
      // (e.g. reopen after ESC disposed the previous recorder).
      _sessionCapturing = false;
      ref.read(craftControllerProvider.notifier).cancelCapture();
      if (mounted) setState(() {});
      return;
    }

    // Read the WAV bytes.
    Uint8List? bytes;
    try {
      bytes = await File(path).readAsBytes();
      await File(path).delete();
    } catch (e, st) {
      _log.warning('read/delete recording file failed', e, st);
    }

    if (bytes != null && bytes.isNotEmpty) {
      _sessionCapturing = false;
      await ref.read(craftControllerProvider.notifier).stopCapture(bytes);
    } else {
      _sessionCapturing = false;
      ref.read(craftControllerProvider.notifier).cancelCapture();
    }
    if (mounted) setState(() {});
  }

  /// Stop the mic and discard any temp file. Does not touch controller state
  /// (used when [cancelCapture] already ran, e.g. via Escape).
  Future<void> _discardMicOnly() async {
    if (_recordingStartedAt == null && !_recordingPending) return;

    _stopElapsedTimer();
    _cancelAmplitudeStream();
    _recordingStartedAt = null;
    _amplitudeWriteIndex = 0;
    _amplitudeCount = 0;
    _recordingPending = false;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (e, st) {
      _log.warning('recorder.stop on cancel failed', e, st);
    }
    await _resetRecorderInstance();

    if (path != null && path.isNotEmpty) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  /// Discard the current recording without committing to ASR.
  Future<void> _cancelRecording() async {
    await _discardMicOnly();
    _sessionCapturing = false;
    ref.read(craftControllerProvider.notifier).cancelCapture();
  }

  Future<void> _resetRecorderInstance() async {
    final old = _recorder;
    _recorder = AudioRecorder();
    try {
      await old.dispose();
    } catch (e, st) {
      _log.fine('recorder dispose after stop', e, st);
    }
  }

  /// 1 Hz timer for the `m:ss` label — avoids 60 fps ticker rebuilds.
  void _startElapsedTimer() {
    _stopElapsedTimer();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_recordingStartedAt == null) return;
      final elapsed = DateTime.now().difference(_recordingStartedAt!);
      if (mounted) setState(() => _elapsed = elapsed);
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  void _startAmplitudeStream() {
    _cancelAmplitudeStream();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
          // Normalize dBFS to 0..1 range for bar visualization.
          // Typical speech is roughly -20 to 0 dBFS.
          final level = ((amp.current + 40) / 40).clamp(0.05, 1.0);
          if (mounted) {
            setState(() {
              _amplitudeBuffer[_amplitudeWriteIndex] = level;
              _amplitudeWriteIndex =
                  (_amplitudeWriteIndex + 1) % _maxAmplitudeBars;
              if (_amplitudeCount < _maxAmplitudeBars) _amplitudeCount++;
            });
          }
        });
  }

  Future<void> _submitText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    await ref.read(craftControllerProvider.notifier).useTextInput(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(craftControllerProvider);
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    // Escape / external cancelCapture: discard the live mic without re-entering
    // cancelCapture (avoids a captureCancelTick feedback loop).
    ref.listen<int>(
      craftControllerProvider.select((s) => s.captureCancelTick),
      (prev, next) {
        if (prev != null && next > prev) {
          _sessionCapturing = false;
          unawaited(_discardMicOnly());
        }
      },
    );

    // Show transcribing indicator.
    if (state.isTranscribing) {
      return CraftLoadingView(message: l10n.craftLoadingTranscribing);
    }

    // Show failure card if any.
    if (state.failure != null) {
      return CraftFailureCard(
        failure: state.failure!,
        l10n: l10n,
        onRetry: _startRecording,
      );
    }

    // Text fallback mode.
    if (_textMode) {
      return _TextFallback(
        controller: _textController,
        focusNode: _focusNode,
        l10n: l10n,
        onSubmit: _submitText,
        onBack: () => setState(() => _textMode = false),
      );
    }

    // Recording active.
    if (state.isCapturing) {
      return _RecordingView(
        elapsed: _elapsed,
        amplitudeBuffer: _amplitudeBuffer,
        amplitudeCount: _amplitudeCount,
        amplitudeWriteIndex: _amplitudeWriteIndex,
        l10n: l10n,
        theme: theme,
        onStop: _stopRecording,
        onCancel: _cancelRecording,
      );
    }

    // Recording pending (permission check).
    if (_recordingPending) {
      return const Center(child: CircularProgressIndicator());
    }

    // Idle state.
    return _IdleView(
      state: state,
      l10n: l10n,
      theme: theme,
      isTablet: isTablet,
      onMicTap: _startRecording,
      onTypeInstead: () => setState(() => _textMode = true),
    );
  }
}

// === Sub-widgets ===

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.state,
    required this.l10n,
    required this.theme,
    required this.isTablet,
    required this.onMicTap,
    required this.onTypeInstead,
  });

  final CraftJobState state;
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isTablet;
  final VoidCallback onMicTap;
  final VoidCallback onTypeInstead;

  @override
  Widget build(BuildContext context) {
    final buttonSize = isTablet ? 88.0 : 72.0;
    final sourceLang = state.sourceLanguage?.toUpperCase() ?? '—';
    final targetLang = state.targetLanguage.toUpperCase();
    final scheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              '$sourceLang  →  $targetLang',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            l10n.craftCaptureTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              l10n.craftCaptureSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 44),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onMicTap,
              customBorder: const CircleBorder(),
              child: Ink(
                width: buttonSize * 2.2,
                height: buttonSize * 2.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.28),
                      scheme.primaryContainer.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.35, 0.7, 1],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      size: buttonSize * 0.48,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          TextButton.icon(
            onPressed: onTypeInstead,
            icon: const Icon(Icons.keyboard_rounded, size: 18),
            label: Text(l10n.craftCaptureTypeInstead),
          ),
        ],
      ),
    );
  }
}

class _RecordingView extends StatefulWidget {
  const _RecordingView({
    required this.elapsed,
    required this.amplitudeBuffer,
    required this.amplitudeCount,
    required this.amplitudeWriteIndex,
    required this.l10n,
    required this.theme,
    required this.onStop,
    required this.onCancel,
  });

  final Duration elapsed;
  final Float32List amplitudeBuffer;
  final int amplitudeCount;
  final int amplitudeWriteIndex;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  State<_RecordingView> createState() => _RecordingViewState();
}

class _RecordingViewState extends State<_RecordingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    unawaited(_pulse.repeat(reverse: true));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final scheme = theme.colorScheme;
    final count = widget.amplitudeCount;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            formatDurationHms(widget.elapsed),
            style: theme.textTheme.displaySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
              color: scheme.error,
            ),
          ),
          const SizedBox(height: 28),
          // Fixed-width track so bars stay centered with the timer / stop
          // control (CustomPaint alone expands to max width and left-aligns).
          Center(
            child: SizedBox(
              width: _AmplitudeBarsPainter.trackWidthFor(
                widget.amplitudeBuffer.length,
              ),
              height: 56,
              child: CustomPaint(
                painter: _AmplitudeBarsPainter(
                  buffer: widget.amplitudeBuffer,
                  count: count,
                  writeIndex: widget.amplitudeWriteIndex,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = _pulse.value;
              return Container(
                width: 96 + t * 8,
                height: 96 + t * 8,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.error.withValues(alpha: 0.12 + t * 0.08),
                ),
                child: child,
              );
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onStop,
                customBorder: const CircleBorder(),
                child: Ink(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.error,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.error.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.stop_rounded,
                    size: 40,
                    color: scheme.onError,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.l10n.craftCaptureStop,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onCancel,
            child: Text(widget.l10n.craftCaptureCancel),
          ),
        ],
      ),
    );
  }
}

class _AmplitudeBarsPainter extends CustomPainter {
  const _AmplitudeBarsPainter({
    required this.buffer,
    required this.count,
    required this.writeIndex,
    required this.color,
  });

  static const double _barWidth = 3.5;
  static const double _spacing = 3.0;

  /// Width of a fixed [barCount]-slot amplitude track.
  static double trackWidthFor(int barCount) =>
      barCount * _barWidth + (barCount - 1) * _spacing;

  final Float32List buffer;
  final int count;
  final int writeIndex;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const minHeight = 6.0;
    final maxHeight = size.height;
    final radius = const Radius.circular(2);
    // Keep the full buffer-length track centered; samples fill L→R inside it
    // so the waveform never drifts as amplitude arrives.
    final trackWidth = trackWidthFor(buffer.length);
    final startX = (size.width - trackWidth) / 2;

    if (count == 0) {
      // Placeholder bars centered in the track.
      const placeholderCount = 12;
      final placeholderWidth = trackWidthFor(placeholderCount);
      final placeholderStart = startX + (trackWidth - placeholderWidth) / 2;
      for (var i = 0; i < placeholderCount; i++) {
        final h = 10 + (i % 3) * 6.0;
        final x = placeholderStart + i * (_barWidth + _spacing);
        paint.color = color.withValues(alpha: 0.25);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, (maxHeight - h) / 2, _barWidth, h),
            radius,
          ),
          paint,
        );
      }
      return;
    }

    // Render oldest-to-newest from the ring buffer.
    for (var i = 0; i < count; i++) {
      final readIndex =
          (writeIndex - count + i + buffer.length) % buffer.length;
      final level = buffer[readIndex];
      final h = (level * maxHeight).clamp(minHeight, maxHeight);
      final x = startX + i * (_barWidth + _spacing);
      paint.color = Color.lerp(color.withValues(alpha: 0.45), color, level)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (maxHeight - h) / 2, _barWidth, h),
          radius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AmplitudeBarsPainter old) {
    return old.count != count ||
        old.writeIndex != writeIndex ||
        old.color != color;
  }
}

class _TextFallback extends StatelessWidget {
  const _TextFallback({
    required this.controller,
    required this.focusNode,
    required this.l10n,
    required this.onSubmit,
    required this.onBack,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final AppLocalizations l10n;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.mic_rounded, size: 18),
              label: Text(l10n.craftCaptureTitle),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          maxLines: 5,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            hintText: l10n.craftTextInputHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(l10n.craftRewriteGenerateAudio),
        ),
      ],
    );
  }
}
