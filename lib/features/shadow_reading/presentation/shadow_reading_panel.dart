/// Shadow-reading stack below echo segment — mirrors web `ShadowReadingPanel`.
library;

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'package:enjoy_player/core/audio/recording_preview_player_provider.dart';
import 'package:enjoy_player/core/audio/wav_duration_ms.dart';
import 'package:enjoy_player/core/audio/wav_signal_peak.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/hotkeys/presentation/hotkey_tooltip_label.dart';
import 'package:enjoy_player/features/shadow_reading/application/recording_input_device_controller.dart';
import 'package:enjoy_player/features/shadow_reading/application/shadow_reading_hotkey_bus.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/recording_assessment_flow.dart';
import 'package:enjoy_player/features/share_poster/presentation/share_practice_poster_button.dart';
import 'package:enjoy_player/features/sync/application/sync_providers.dart';
import 'package:enjoy_player/features/sync/domain/sync_types.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import 'pitch_contour_section.dart';
import 'widgets/shadow_record_fab.dart';
import 'widgets/shadow_reading_toolbar_row.dart';
import 'widgets/shadow_recording_caption.dart';
import 'widgets/shadow_takes_toolbar_actions.dart';

final _log = logNamed('ShadowReadingPanel');

String _shortSaveError(Object e) {
  final s = e.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length <= 180) return s;
  return '${s.substring(0, 177)}…';
}

/// `@visibleForTesting` wrapper around the private [_shortSaveError] so
/// tests can exercise the helper without spinning up the full widget
/// tree. See `test/features/shadow_reading/presentation/shadow_reading_panel_helpers_test.dart`.
@visibleForTesting
String shortSaveErrorForTest(Object e) => _shortSaveError(e);

RecordingRow? _resolvedSelectedRow(
  List<RecordingRow> list,
  String? selectedId,
) {
  if (list.isEmpty) return null;
  if (selectedId != null) {
    for (final r in list) {
      if (r.id == selectedId) return r;
    }
  }
  return list.first;
}

/// `@visibleForTesting` wrapper around the private [_resolvedSelectedRow].
/// See `test/features/shadow_reading/presentation/shadow_reading_panel_helpers_test.dart`.
@visibleForTesting
RecordingRow? resolvedSelectedRowForTest(
  List<RecordingRow> list,
  String? selectedId,
) => _resolvedSelectedRow(list, selectedId);

class ShadowReadingPanel extends ConsumerStatefulWidget {
  const ShadowReadingPanel({
    required this.mediaId,
    required this.targetType,
    required this.language,
    required this.startSec,
    required this.endSec,
    required this.referenceText,
    required this.echoActive,
    this.currentTimeSec,
    super.key,
  });

  final String mediaId;
  final String targetType;
  final String language;
  final double startSec;
  final double endSec;
  final String referenceText;
  final bool echoActive;
  final double? currentTimeSec;

  @override
  ConsumerState<ShadowReadingPanel> createState() => _ShadowReadingPanelState();
}

/// Capture config aligned with the web client and Azure Speech expectations.
///
/// 16 kHz mono PCM16 WAV avoids stereo downmix loss (one mic channel + one
/// silent / out-of-phase channel cancelling each other to zero) and matches
/// what the Azure Speech SDK accepts directly without downstream re-encoding.
///
/// `device` is filled in at call site from
/// [recordingInputDeviceCtrlProvider] so we capture from the user's chosen
/// (or auto-picked, non-virtual) microphone — this is what stops Windows from
/// silently picking GlideX / VoiceMeeter / Stereo-Mix loopback devices.
RecordConfig _buildShadowRecordConfig(InputDevice? device) => RecordConfig(
  encoder: AudioEncoder.wav,
  sampleRate: 16000,
  numChannels: 1,
  device: device,
);

class _ShadowReadingPanelState extends ConsumerState<ShadowReadingPanel>
    with TickerProviderStateMixin {
  /// Recreated after every `stop()` — `record` on Windows can keep stale Media
  /// Foundation state on the same instance, so a second `start()` quietly
  /// produces a zero-sample WAV ("second take won't record").
  AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  bool _recordingPending = false;
  String? _selectedRecordingId;
  String? _mediaPath;
  Future<String?>? _mediaPathFuture;

  DateTime? _recordingStartedAt;
  Duration _elapsed = Duration.zero;
  Ticker? _elapsedTicker;
  Timer? _overPulseTimer;
  bool _overPulseHigh = false;

  bool _pitchExpanded = false;

  Future<String?> _mediaPathFutureOnce() {
    return _mediaPathFuture ??= () async {
      _mediaPath ??= await _resolveMediaPath();
      return _mediaPath;
    }();
  }

  @override
  void didUpdateWidget(covariant ShadowReadingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId) {
      _mediaPath = null;
      _mediaPathFuture = null;
    }
    if (oldWidget.mediaId != widget.mediaId ||
        oldWidget.startSec != widget.startSec ||
        oldWidget.endSec != widget.endSec ||
        oldWidget.language != widget.language ||
        oldWidget.targetType != widget.targetType) {
      _selectedRecordingId = null;
    }
  }

  void _stopElapsedTicker() {
    _elapsedTicker?.dispose();
    _elapsedTicker = null;
  }

  void _stopOverPulse() {
    _overPulseTimer?.cancel();
    _overPulseTimer = null;
    _overPulseHigh = false;
  }

  void _onElapsedTick(Duration _) {
    if (!mounted || !_recording || _recordingStartedAt == null) return;
    final elapsed = DateTime.now().difference(_recordingStartedAt!);
    final targetSec = widget.endSec - widget.startSec;
    final over = targetSec > 0 && elapsed.inMilliseconds / 1000.0 > targetSec;
    setState(() {
      _elapsed = elapsed;
    });
    if (over && _overPulseTimer == null) {
      _overPulseTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
        if (!mounted) return;
        setState(() => _overPulseHigh = !_overPulseHigh);
      });
    } else if (!over) {
      _stopOverPulse();
    }
  }

  void _startElapsedTicker() {
    _stopElapsedTicker();
    final ticker = createTicker(_onElapsedTick);
    unawaited(ticker.start());
    _elapsedTicker = ticker;
  }

  void _clearRecordingTiming() {
    _stopElapsedTicker();
    _stopOverPulse();
    _recordingStartedAt = null;
    _elapsed = Duration.zero;
  }

  void _setRecordingActiveOnBus(bool active) {
    ref
        .read(shadowReadingHotkeyBusProvider.notifier)
        .setRecordingActive(active);
  }

  /// Discard in-progress capture (Escape); does not persist to the library.
  Future<void> _cancelRecording() async {
    if (!_recording && !_recordingPending) return;
    if (_recordingPending && !_recording) {
      _recordingPending = false;
      _clearRecordingTiming();
      _setRecordingActiveOnBus(false);
      if (mounted) setState(() {});
      return;
    }
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e, st) {
      _log.warning('microphone stop (cancel recording) failed', e, st);
    }
    _recording = false;
    _recordingPending = false;
    _clearRecordingTiming();
    _setRecordingActiveOnBus(false);
    await _resetRecorderInstance();
    if (path != null && path.isNotEmpty) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (e, st) {
        _log.fine('delete cancelled recording wav failed', e, st);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final wasRecording = _recording;
    final wasPending = _recordingPending;
    _clearRecordingTiming();
    if (wasRecording || wasPending) {
      _recording = false;
      _recordingPending = false;
      _setRecordingActiveOnBus(false);
    }
    unawaited(() async {
      if (wasRecording) {
        try {
          final path = await _recorder.stop();
          if (path != null && path.isNotEmpty) {
            try {
              await File(path).delete();
            } catch (_) {}
          }
        } catch (e, st) {
          _log.fine('recorder stop on dispose', e, st);
        }
      }
      try {
        await _recorder.dispose();
      } catch (_) {}
    }());
    super.dispose();
  }

  Future<String?> _resolveMediaPath() async {
    final db = ref.read(appDatabaseProvider);
    final v = await db.videoDao.getById(widget.mediaId);
    final a = v == null ? await db.audioDao.getById(widget.mediaId) : null;
    final uri = v?.localUri ?? a?.localUri;
    if (uri == null || uri.isEmpty) return null;
    try {
      return Uri.parse(uri).toFilePath();
    } catch (_) {
      return uri;
    }
  }

  double? get _relativeSec {
    final t = widget.currentTimeSec;
    if (t == null) return null;
    return (t - widget.startSec).clamp(0.0, widget.endSec - widget.startSec);
  }

  Future<void> _resetRecorderInstance() async {
    final old = _recorder;
    _recorder = AudioRecorder();
    try {
      await old.dispose();
    } catch (e, st) {
      _log.fine('audio recorder dispose after stop failed', e, st);
    }
  }

  Future<void> _toggleRecord(AppLocalizations l10n) async {
    if (!widget.echoActive) return;
    if (_recording) {
      String? path;
      try {
        path = await _recorder.stop();
      } catch (e, st) {
        _log.warning('microphone stop failed', e, st);
        _recording = false;
        _recordingPending = false;
        _setRecordingActiveOnBus(false);
        _clearRecordingTiming();
        await _resetRecorderInstance();
        if (mounted) setState(() {});
        if (mounted) {
          AppNotice.error(
            context,
            l10n.shadowRecordingSaveFailed(_shortSaveError(e)),
          );
        }
        return;
      }
      _recording = false;
      _recordingPending = false;
      _setRecordingActiveOnBus(false);
      _clearRecordingTiming();
      await _resetRecorderInstance();
      setState(() {});
      if (path == null || path.isEmpty) {
        _log.warning('recorder.stop returned no path');
        return;
      }
      _log.fine('recorder.stop wrote $path');
      await _persistRecording(path, l10n);
      return;
    }

    await _mediaPathFutureOnce();

    _setRecordingActiveOnBus(true);
    _recordingPending = true;

    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'recordings'));
    await dir.create(recursive: true);
    final id = const Uuid().v4();
    final outPath = p.join(dir.path, '$id.wav');

    bool granted;
    try {
      granted = await _recorder.hasPermission();
    } catch (e, st) {
      _log.warning('recorder.hasPermission failed', e, st);
      _recordingPending = false;
      _setRecordingActiveOnBus(false);
      if (mounted) {
        AppNotice.error(
          context,
          l10n.shadowRecordingSaveFailed(_shortSaveError(e)),
        );
      }
      return;
    }
    if (!granted) {
      _recordingPending = false;
      _setRecordingActiveOnBus(false);
      if (mounted) {
        AppNotice.warning(context, l10n.shadowRecordingMicDenied);
      }
      return;
    }

    // Refresh so a USB mic plugged in since app start is considered by the
    // auto-pick heuristic (selection is then read from the provider state).
    await ref.read(recordingInputDeviceCtrlProvider.notifier).refresh();
    final deviceState = ref.read(recordingInputDeviceCtrlProvider).valueOrNull;
    final selectedDevice = deviceState?.selectedDevice;
    final config = _buildShadowRecordConfig(selectedDevice);

    try {
      await _recorder.start(config, path: outPath);
    } catch (e, st) {
      _log.warning('recorder.start failed at $outPath', e, st);
      _recordingPending = false;
      _setRecordingActiveOnBus(false);
      _clearRecordingTiming();
      await _resetRecorderInstance();
      if (mounted) setState(() {});
      if (mounted) {
        AppNotice.error(
          context,
          l10n.shadowRecordingSaveFailed(_shortSaveError(e)),
        );
      }
      return;
    }
    _log.fine(
      'recorder.start ok path=$outPath '
      'sampleRate=${config.sampleRate} numChannels=${config.numChannels} '
      'device="${selectedDevice?.label ?? "<os-default>"}"'
      '${deviceState?.autoPicked == false ? " (user)" : " (auto)"}',
    );
    _recording = true;
    _recordingPending = false;
    _pitchExpanded = false;
    _recordingStartedAt = DateTime.now();
    _elapsed = Duration.zero;
    _startElapsedTicker();
    setState(() {});
  }

  Future<void> _persistRecording(String wavPath, AppLocalizations l10n) async {
    try {
      final file = File(wavPath);
      if (!await file.exists()) {
        _log.warning('recording wav missing at path: $wavPath');
        if (mounted) {
          AppNotice.error(
            context,
            l10n.shadowRecordingSaveFailed(l10n.shadowRecordingFileNotFound),
          );
        }
        return;
      }
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      final parsedMs = wavDurationMsFromBytes(bytes);
      final durationMs = parsedMs ?? 0;
      if (parsedMs == null && bytes.isNotEmpty) {
        _log.warning(
          'could not parse WAV duration ($wavPath, ${bytes.length} bytes)',
        );
      }

      final peak = scanWavDataPeakFromBytes(bytes);
      if (peak != null) {
        _log.fine(
          'recording wav fmt=${peak.fmt.audioFormat} '
          'ch=${peak.fmt.numChannels} ${peak.fmt.sampleRate}Hz '
          '${peak.fmt.bitsPerSample}bit '
          'peak≈${peak.peakNormalized.toStringAsFixed(5)} '
          'rms≈${peak.rmsNormalized.toStringAsFixed(6)} '
          'nonZero=${(peak.nonZeroRatio * 100).toStringAsFixed(2)}% '
          'samples=${peak.totalSamples} '
          'bytes=${bytes.length} durMs=$durationMs',
        );
        // Real speech captured at moderate volume gives RMS in the rough
        // 0.02-0.3 range. RMS below ~0.001 with non-zero ratio under ~1% means
        // the WAV is essentially silent even when peak looks healthy.
        const minRms = 0.001;
        const minNonZeroRatio = 0.01;
        final looksSilent =
            peak.rmsNormalized < minRms || peak.nonZeroRatio < minNonZeroRatio;
        if (looksSilent) {
          _log.warning(
            'recording wav appears silent '
            '(peak≈${peak.peakNormalized.toStringAsFixed(6)} '
            'rms≈${peak.rmsNormalized.toStringAsFixed(6)} '
            'nonZero=${(peak.nonZeroRatio * 100).toStringAsFixed(2)}%). '
            'Check Windows microphone privacy / default input device.',
          );
          if (mounted) {
            AppNotice.warning(context, l10n.shadowRecordingSilentWarning);
          }
        }
      }

      final db = ref.read(appDatabaseProvider);
      final id = p.basenameWithoutExtension(wavPath);
      final now = DateTime.now();
      final startMs = (widget.startSec * 1000).round();
      final durMs = ((widget.endSec - widget.startSec) * 1000).round();
      final row = RecordingRow(
        id: id,
        targetType: widget.targetType,
        targetId: widget.mediaId,
        referenceStart: startMs,
        referenceDuration: durMs,
        referenceText: widget.referenceText,
        language: widget.language,
        duration: durationMs,
        md5: hash,
        audioUrl: null,
        pronunciationScore: null,
        assessmentJson: null,
        localPath: wavPath,
        syncStatus: 'local',
        serverUpdatedAt: null,
        createdAt: now,
        updatedAt: now,
      );
      await db.recordingDao.insertRow(row);
      await ref.read(syncEnqueueProvider)(
        SyncEntityType.recording,
        id,
        SyncAction.create,
      );
      if (mounted) {
        setState(() => _selectedRecordingId = id);
      }
    } catch (e, st) {
      _log.warning('save recording failed', e, st);
      if (mounted) {
        AppNotice.error(
          context,
          l10n.shadowRecordingSaveFailed(_shortSaveError(e)),
        );
      }
    }
  }

  Future<void> _playOrPauseTake(String path) async {
    try {
      await ref.read(recordingPreviewPlayerProvider).playOrPauseTake(path);
    } catch (e, st) {
      _log.warning('shadow take playback failed', e, st);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      AppNotice.error(context, l10n.shadowRecordingPlaybackFailed);
    }
  }

  Future<void> _deleteRecording(RecordingRow r) async {
    await ref.read(syncEnqueueProvider)(
      SyncEntityType.recording,
      r.id,
      SyncAction.delete,
    );
    final preview = ref.read(recordingPreviewPlayerProvider);
    final lp = r.localPath;
    if (lp != null && lp.isNotEmpty) {
      try {
        if (preview.loadedPath == File(lp).absolute.path) {
          await preview.stop();
        }
        await File(lp).delete();
      } catch (_) {}
    }
    await ref.read(appDatabaseProvider).recordingDao.deleteId(r.id);
    if (mounted) {
      setState(() => _selectedRecordingId = null);
    }
  }

  Future<void> _onHotkeyRecordingPulse(AppLocalizations l10n) async {
    if (!widget.echoActive) return;
    await _toggleRecord(l10n);
  }

  Future<void> _onHotkeyPlaybackPulse() async {
    if (!widget.echoActive) return;
    final db = ref.read(appDatabaseProvider);
    final list = await db.recordingDao.listByEchoRegion(
      targetType: widget.targetType,
      targetId: widget.mediaId,
      language: widget.language,
      echoStartMs: (widget.startSec * 1000).round(),
      echoEndMs: (widget.endSec * 1000).round(),
    );
    if (!mounted) return;
    if (list.isEmpty) return;
    final sel = _resolvedSelectedRow(list, _selectedRecordingId);
    final path = sel?.localPath;
    if (path != null && path.isNotEmpty) {
      await _playOrPauseTake(path);
    }
  }

  void _onHotkeyAssessmentPulse() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    unawaited(_onHotkeyAssessmentRun(l10n));
  }

  Future<void> _onHotkeyAssessmentRun(AppLocalizations l10n) async {
    if (!widget.echoActive) return;
    final db = ref.read(appDatabaseProvider);
    final list = await db.recordingDao.listByEchoRegion(
      targetType: widget.targetType,
      targetId: widget.mediaId,
      language: widget.language,
      echoStartMs: (widget.startSec * 1000).round(),
      echoEndMs: (widget.endSec * 1000).round(),
    );
    if (!mounted) return;
    if (list.isEmpty) return;
    final sel = _resolvedSelectedRow(list, _selectedRecordingId);
    if (sel == null) return;
    await triggerRecordingAssessment(
      context: context,
      ref: ref,
      l10n: l10n,
      row: sel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ttToggleRecording = hotkeyTooltipLabel(
      ref,
      'player.toggleRecording',
      _recording ? l10n.shadowRecordingStop : l10n.shadowRecordingRecord,
    );
    final pitchContourTooltip = hotkeyTooltipLabel(
      ref,
      'player.togglePitchContour',
      l10n.pitchContourTitle,
    );
    final recordFabTooltip = '$ttToggleRecording\n${l10n.shadowReadingHint}';
    ref.listen<int>(shadowReadingHotkeyBusProvider.select((s) => s.recording), (
      prev,
      next,
    ) {
      if (prev == next) return;
      unawaited(_onHotkeyRecordingPulse(l10n));
    });
    ref.listen<int>(
      shadowReadingHotkeyBusProvider.select((s) => s.recordingCancel),
      (prev, next) {
        if (prev == next) return;
        if (!_recording && !_recordingPending) return;
        unawaited(_cancelRecording());
      },
    );
    ref.listen<int>(shadowReadingHotkeyBusProvider.select((s) => s.playback), (
      prev,
      next,
    ) {
      if (prev == next) return;
      unawaited(_onHotkeyPlaybackPulse());
    });
    ref.listen<int>(
      shadowReadingHotkeyBusProvider.select((s) => s.assessment),
      (prev, next) {
        if (prev == next) return;
        _onHotkeyAssessmentPulse();
      },
    );

    final scheme = Theme.of(context).colorScheme;
    final tok = EnjoyThemeTokens.of(context);
    final tt = Theme.of(context).textTheme;

    final targetSec = (widget.endSec - widget.startSec).clamp(
      0.0,
      double.infinity,
    );
    final elapsedSec = _elapsed.inMicroseconds / 1e6;
    final ringProgress = targetSec > 0
        ? (elapsedSec / targetSec).clamp(0.0, 1.0)
        : 0.0;
    final overTarget = _recording && targetSec > 0 && elapsedSec > targetSec;
    final overBySec = overTarget ? elapsedSec - targetSec : 0.0;

    return FutureBuilder<String?>(
      future: _mediaPathFutureOnce(),
      builder: (context, snap) {
        final mediaPath = snap.data;
        final db = ref.watch(appDatabaseProvider);
        final echoStartMs = (widget.startSec * 1000).round();
        final echoEndMs = (widget.endSec * 1000).round();

        return StreamBuilder<List<RecordingRow>>(
          stream: db.recordingDao.watchByEchoRegion(
            targetType: widget.targetType,
            targetId: widget.mediaId,
            language: widget.language,
            echoStartMs: echoStartMs,
            echoEndMs: echoEndMs,
          ),
          builder: (context, recSnap) {
            final list = recSnap.data ?? [];
            final sel = _resolvedSelectedRow(list, _selectedRecordingId);
            final showProgressArc =
                _recording || overTarget || (ringProgress > 1e-6);

            if (_recording) {
              return Padding(
                padding: EdgeInsets.only(bottom: tok.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Tooltip(
                        message: ttToggleRecording,
                        child: ShadowRecordFab(
                          recording: true,
                          echoActive: widget.echoActive,
                          ringProgress: ringProgress,
                          overTarget: overTarget,
                          overPulseHigh: _overPulseHigh,
                          showProgressArc: showProgressArc,
                          onTap: () => _toggleRecord(l10n),
                          scheme: scheme,
                          tok: tok,
                        ),
                      ),
                    ),
                    SizedBox(height: tok.space4),
                    ShadowRecordingCaptionRow(
                      elapsedSec: elapsedSec,
                      targetSec: targetSec,
                      overTarget: overTarget,
                      overBySec: overBySec,
                      l10n: l10n,
                      tt: tt,
                      scheme: scheme,
                      tok: tok,
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: tok.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShadowReadingToolbarRow(
                    tok: tok,
                    scheme: scheme,
                    pitchExpanded: _pitchExpanded,
                    pitchTooltip: pitchContourTooltip,
                    hasMediaPath: mediaPath != null && mediaPath.isNotEmpty,
                    onPitchTap: () =>
                        setState(() => _pitchExpanded = !_pitchExpanded),
                    leadingShare: SharePracticePosterButton(
                      mediaId: widget.mediaId,
                      iconColor: scheme.onSurface,
                    ),
                    takesActions: list.isNotEmpty && sel != null
                        ? ShadowTakesToolbarActions(
                            row: sel,
                            list: list,
                            echoActive: widget.echoActive,
                            scheme: scheme,
                            tok: tok,
                            l10n: l10n,
                            onPlayOrPause: () {
                              final path = sel.localPath;
                              if (path != null && path.isNotEmpty) {
                                unawaited(_playOrPauseTake(path));
                              }
                            },
                            onDeleteCurrent: () =>
                                unawaited(_deleteRecording(sel)),
                            onChooseTake: (id) async {
                              await ref
                                  .read(recordingPreviewPlayerProvider)
                                  .stop();
                              if (mounted) {
                                setState(() => _selectedRecordingId = id);
                              }
                            },
                          )
                        : null,
                    recordFab: Tooltip(
                      message: recordFabTooltip,
                      child: ShadowRecordFab(
                        recording: false,
                        echoActive: widget.echoActive,
                        ringProgress: 0,
                        overTarget: false,
                        overPulseHigh: false,
                        showProgressArc: false,
                        onTap: () => _toggleRecord(l10n),
                        scheme: scheme,
                        tok: tok,
                      ),
                    ),
                  ),
                  if (mediaPath != null && mediaPath.isNotEmpty) ...[
                    if (_pitchExpanded) SizedBox(height: tok.space8),
                    PitchContourSection(
                      mediaPath: mediaPath,
                      startSec: widget.startSec,
                      endSec: widget.endSec,
                      currentTimeRelativeSec: _relativeSec,
                      selectedRecordingPath: sel?.localPath,
                      selectedRecordingDurationMs: sel?.duration,
                      expanded: _pitchExpanded,
                      onToggleExpanded: () =>
                          setState(() => _pitchExpanded = !_pitchExpanded),
                      showHeader: false,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
