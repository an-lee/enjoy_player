/// Audio stage: preview player + save/loop/practice actions.
///
/// Shows the full learning-language script (scrollable when long) so the
/// learner can follow along while previewing, an inline audio preview player,
/// a collapsible voice chip, an unsaved-preview hint, and two save CTAs:
/// "Save & practice" (navigate to player) and "Save & say another" (loop).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/routing/player_navigation.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/features/craft/application/craft_controller.dart';
import 'package:enjoy_player/features/craft/domain/azure_voice.dart';
import 'package:enjoy_player/features/craft/presentation/craft_solid_transcript_stt_hint.dart';
import 'package:enjoy_player/features/craft/presentation/voice_picker.dart';
import 'package:enjoy_player/features/craft/presentation/widgets/craft_failure_card.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Audio stage for the Express flow.
class AudioStage extends ConsumerStatefulWidget {
  const AudioStage({super.key});

  @override
  ConsumerState<AudioStage> createState() => _AudioStageState();
}

class _AudioStageState extends ConsumerState<AudioStage> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _completeSub;
  bool _voiceExpanded = false;

  @override
  void dispose() {
    _cancelStreams();
    unawaited(_player?.dispose());
    super.dispose();
  }

  void _cancelStreams() {
    unawaited(_positionSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(_completeSub?.cancel());
    _positionSub = null;
    _durationSub = null;
    _completeSub = null;
  }

  Future<void> _togglePlay() async {
    final bytes = ref.read(craftControllerProvider).previewAudioBytes;
    if (bytes == null) return;

    _player ??= AudioPlayer();

    if (_isPlaying) {
      await _player!.pause();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      // Subscribe to streams on first play.
      if (_positionSub == null) {
        _positionSub = _player!.onPositionChanged.listen((pos) {
          if (!mounted) return;
          setState(() {
            // Clamp: player callbacks can report position past duration.
            _position = _duration > Duration.zero && pos > _duration
                ? _duration
                : pos;
          });
        });
        _durationSub = _player!.onDurationChanged.listen((dur) {
          if (!mounted) return;
          setState(() {
            _duration = dur;
            if (_position > dur) _position = dur;
          });
        });
        _completeSub = _player!.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _position = Duration.zero;
            });
          }
        });
      }

      if (_position == _duration && _duration > Duration.zero) {
        await _player!.seek(Duration.zero);
      }
      await _player!.play(BytesSource(bytes));
      if (mounted) setState(() => _isPlaying = true);
    }
  }

  Future<void> _saveAndCaptureNext() async {
    final result = await ref
        .read(craftControllerProvider.notifier)
        .saveAndCaptureNext();
    if (!mounted) return;
    // If save failed, don't show success snackbar or tear down the player —
    // the failure card will be shown by the build method instead.
    if (result == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.craftSavedToLibrary),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    maybeShowCraftSolidTranscriptSttHint(
      context,
      savedSolidTimeline: result.wroteSolidTranscript,
    );
    // Reset playback state for the next capture.
    _cancelStreams();
    unawaited(_player?.dispose());
    _player = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
  }

  Future<void> _saveAndPractice() async {
    final result = await ref
        .read(craftControllerProvider.notifier)
        .saveAndPractice();
    if (!mounted || result == null) return;

    maybeShowCraftSolidTranscriptSttHint(
      context,
      savedSolidTimeline: result.wroteSolidTranscript,
    );
    final state = ref.read(craftControllerProvider);
    final targetId = state.dedupedExistingId ?? result.mediaId;
    if (mounted) openPlayerRoute(context, targetId);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(craftControllerProvider);
    final theme = Theme.of(context);
    final t = EnjoyThemeTokens.of(context);

    // Re-synth (voice change) replaces preview bytes — reset the local player.
    ref.listen<Uint8List?>(
      craftControllerProvider.select((s) => s.previewAudioBytes),
      (prev, next) {
        if (prev == next) return;
        _cancelStreams();
        unawaited(_player?.dispose());
        _player = null;
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
            _duration = Duration.zero;
          });
        }
      },
    );

    if (state.isSynthesizing) {
      return _LoadingView(l10n: l10n);
    }

    if (state.failure != null) {
      return CraftFailureCard(
        failure: state.failure!,
        l10n: l10n,
        onRetry: () =>
            ref.read(craftControllerProvider.notifier).generateAudio(),
      );
    }

    if (!state.hasPreview) {
      // No audio — shouldn't normally happen, but show a fallback.
      return Center(
        child: Padding(
          padding: EdgeInsets.all(t.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.craftAudioPreview, style: theme.textTheme.bodyLarge),
              SizedBox(height: t.space16),
              EnjoyButton.primary(
                onPressed: () =>
                    ref.read(craftControllerProvider.notifier).generateAudio(),
                child: Text(l10n.craftRewriteGenerateAudio),
              ),
            ],
          ),
        ),
      );
    }

    final sourceLang = state.sourceLanguage?.toUpperCase() ?? '—';
    final targetLang = state.targetLanguage.toUpperCase();
    final previewText = state.translatedText ?? state.synthText;
    final voiceLabel = _voiceDisplayLabel(state.selectedVoice);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: t.space8, vertical: t.space8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ScriptBlock(
                sourceLang: sourceLang,
                targetLang: targetLang,
                text: previewText,
                theme: theme,
              ),
              SizedBox(height: t.space20),
              _PreviewPlayer(
                isPlaying: _isPlaying,
                position: _position,
                duration: _duration,
                onToggle: _togglePlay,
                onSeek: (pos) async {
                  await _player?.seek(pos);
                  if (mounted) setState(() => _position = pos);
                },
                fmt: _fmt,
                theme: theme,
              ),
              SizedBox(height: t.space16),
              _VoiceChip(
                expanded: _voiceExpanded,
                synthLanguage: state.synthLanguage,
                selectedVoice: state.selectedVoice,
                voiceLabel: voiceLabel,
                theme: theme,
                onToggle: () {
                  setState(() => _voiceExpanded = !_voiceExpanded);
                },
                onVoiceChanged: (voice) {
                  ref
                      .read(craftControllerProvider.notifier)
                      .setSelectedVoice(voice);
                  unawaited(
                    ref.read(craftControllerProvider.notifier).generateAudio(),
                  );
                },
              ),
              SizedBox(height: t.space20),
              if (state.hasUnsavedPreview) ...[
                _UnsavedPreviewHint(message: l10n.craftAudioUnsavedHint),
                SizedBox(height: t.space16),
              ],
              if (state.isSaving)
                const Center(child: CircularProgressIndicator())
              else
                _AudioActions(
                  practiceLabel: l10n.craftAudioPracticeNow,
                  sayAnotherLabel: l10n.craftAudioSaySomethingElse,
                  onPractice: _saveAndPractice,
                  onSayAnother: _saveAndCaptureNext,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _voiceDisplayLabel(String? voiceId) {
  if (voiceId == null || voiceId.isEmpty) return null;
  for (final v in kAzureVoices) {
    if (v.id == voiceId) return v.label;
  }
  return voiceId;
}

// === Sub-widgets ===

class _UnsavedPreviewHint extends StatelessWidget {
  const _UnsavedPreviewHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.space12,
          vertical: t.space8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: scheme.onTertiaryContainer,
            ),
            SizedBox(width: t.space8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioActions extends StatelessWidget {
  const _AudioActions({
    required this.practiceLabel,
    required this.sayAnotherLabel,
    required this.onPractice,
    required this.onSayAnother,
  });

  final String practiceLabel;
  final String sayAnotherLabel;
  final VoidCallback onPractice;
  final VoidCallback onSayAnother;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EnjoyButton.primary(
          onPressed: onPractice,
          icon: Icons.library_add_check_rounded,
          child: Text(practiceLabel),
        ),
        SizedBox(height: t.space8),
        OutlinedButton.icon(
          onPressed: onSayAnother,
          icon: const Icon(Icons.mic_none_rounded, size: 18),
          label: Text(sayAnotherLabel),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            l10n.craftLoadingSynthesizing,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full script for follow-along listening. Short text sizes naturally; long
/// text scrolls inside a capped viewport so the preview player stays nearby.
class _ScriptBlock extends StatefulWidget {
  const _ScriptBlock({
    required this.sourceLang,
    required this.targetLang,
    required this.text,
    required this.theme,
  });

  /// Soft cap so very long scripts don't push actions off-screen.
  static const double maxScriptHeight = 240;

  final String sourceLang;
  final String targetLang;
  final String text;
  final ThemeData theme;

  @override
  State<_ScriptBlock> createState() => _ScriptBlockState();
}

class _ScriptBlockState extends State<_ScriptBlock> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final scheme = theme.colorScheme;
    final scriptStyle = theme.textTheme.bodyLarge?.copyWith(
      color: scheme.onSurface,
      height: 1.55,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.sourceLang}  →  ${widget.targetLang}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: _ScriptBlock.maxScriptHeight,
            ),
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                primary: false,
                child: SelectableText(widget.text, style: scriptStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceChip extends StatelessWidget {
  const _VoiceChip({
    required this.expanded,
    required this.synthLanguage,
    required this.selectedVoice,
    required this.voiceLabel,
    required this.theme,
    required this.onToggle,
    required this.onVoiceChanged,
  });

  final bool expanded;
  final String synthLanguage;
  final String? selectedVoice;
  final String? voiceLabel;
  final ThemeData theme;
  final VoidCallback onToggle;
  final void Function(String) onVoiceChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.record_voice_over_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.craftVoiceLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      voiceLabel ?? l10n.craftVoiceLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            VoicePicker(
              language: synthLanguage,
              selectedVoice: selectedVoice,
              onChanged: onVoiceChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewPlayer extends StatelessWidget {
  const _PreviewPlayer({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onToggle,
    required this.onSeek,
    required this.fmt,
    required this.theme,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;
  final String Function(Duration) fmt;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final timeStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final clampedPosition = position > duration && duration > Duration.zero
        ? duration
        : position;
    // Position can briefly overshoot duration from the player stream;
    // Slider asserts if value > max.
    final maxMs = duration.inMilliseconds.toDouble().clamp(
      1.0,
      double.infinity,
    );
    final valueMs = clampedPosition.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              customBorder: const CircleBorder(),
              child: Ink(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 32,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(fmt(clampedPosition), style: timeStyle),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: valueMs,
                max: maxMs,
                onChanged: duration > Duration.zero
                    ? (v) => onSeek(Duration(milliseconds: v.round()))
                    : null,
              ),
            ),
          ),
          Text(fmt(duration), style: timeStyle),
        ],
      ),
    );
  }
}
