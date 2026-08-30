/// Rewrite stage: editable native transcript + editable target text +
/// style/voice + actions.
///
/// Learners can correct STT mistakes in "Your words", then re-translate
/// before generating audio. Target text remains editable for final polish.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/craft/application/craft_controller.dart';
import 'package:enjoy_player/features/craft/domain/azure_voice.dart';
import 'package:enjoy_player/features/craft/domain/craft_job_state.dart';
import 'package:enjoy_player/features/craft/domain/craft_request.dart';
import 'package:enjoy_player/features/craft/presentation/style_picker.dart';
import 'package:enjoy_player/features/craft/presentation/voice_picker.dart';
import 'package:enjoy_player/features/craft/presentation/widgets/craft_failure_card.dart';
import 'package:enjoy_player/features/craft/presentation/widgets/craft_loading_view.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Rewrite stage for the Express flow.
class RewriteStage extends ConsumerStatefulWidget {
  const RewriteStage({super.key});

  @override
  ConsumerState<RewriteStage> createState() => _RewriteStageState();
}

class _RewriteStageState extends ConsumerState<RewriteStage> {
  late final TextEditingController _targetCtrl;
  late final FocusNode _targetFocus;
  late final TextEditingController _nativeCtrl;
  late final FocusNode _nativeFocus;
  bool _controllersInitialized = false;
  String? _lastSyncedTarget;
  String? _lastSyncedNative;

  @override
  void dispose() {
    if (_controllersInitialized) {
      _targetCtrl.dispose();
      _targetFocus.dispose();
      _nativeCtrl.dispose();
      _nativeFocus.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(CraftJobState state) {
    if (_controllersInitialized) return;
    _targetCtrl = TextEditingController(text: state.translatedText ?? '');
    _targetFocus = FocusNode();
    _nativeCtrl = TextEditingController(text: state.rawTranscript ?? '');
    _nativeFocus = FocusNode();
    _lastSyncedTarget = state.translatedText;
    _lastSyncedNative = state.rawTranscript;
    _controllersInitialized = true;
  }

  void _seedVoiceIfNeeded(CraftJobState state) {
    if (state.selectedVoice != null) return;
    final defaultVoice = defaultVoiceForLanguage(
      state.targetLanguage.split('-').first.toLowerCase(),
    );
    if (defaultVoice == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(craftControllerProvider);
      if (current.selectedVoice == null) {
        ref
            .read(craftControllerProvider.notifier)
            .setSelectedVoice(
              defaultVoice.id,
              forLanguage: current.targetLanguage,
            );
      }
    });
  }

  void _flushNativeToController() {
    if (!_controllersInitialized) return;
    ref
        .read(craftControllerProvider.notifier)
        .setRawTranscript(_nativeCtrl.text);
  }

  Future<void> _regenerate() async {
    _flushNativeToController();
    await ref.read(craftControllerProvider.notifier).regenerate();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(craftControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    _ensureControllers(state);

    final currentTranslated = state.translatedText ?? '';
    if (_lastSyncedTarget != currentTranslated && !_targetFocus.hasFocus) {
      _targetCtrl.text = currentTranslated;
      _lastSyncedTarget = currentTranslated;
    }

    final currentNative = state.rawTranscript ?? '';
    if (_lastSyncedNative != currentNative && !_nativeFocus.hasFocus) {
      _nativeCtrl.text = currentNative;
      _lastSyncedNative = currentNative;
    }

    // First rewrite (no target yet): keep the full-screen loading hint.
    // Re-translate / regenerate: keep the form visible with inline progress.
    if (state.isTranslating && !state.hasTranslation) {
      return CraftLoadingView(message: l10n.craftLoadingRewriting);
    }

    if (state.failure != null) {
      return CraftFailureCard(
        failure: state.failure!,
        l10n: l10n,
        onRetry: () => unawaited(_regenerate()),
      );
    }

    _seedVoiceIfNeeded(state);

    final targetBase = state.targetLanguage.split('-').first.toUpperCase();
    final raw = state.rawTranscript;
    final hasRaw = raw != null && raw.isNotEmpty;
    final isRetranslating = state.isTranslating && state.hasTranslation;
    final canRegenerate =
        hasRaw &&
        normalizeCraftText(raw).length >= craftMinTextLength &&
        !state.isBusy;
    final showReTranslate =
        hasRaw && state.isRawTranscriptDirty && !isRetranslating;

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 28),
      children: [
        if (hasRaw) ...[
          _NativeTextCard(
            controller: _nativeCtrl,
            focusNode: _nativeFocus,
            l10n: l10n,
            theme: theme,
            enabled: !state.isBusy,
            showReTranslate: showReTranslate,
            isRetranslating: isRetranslating,
            onChanged: (v) {
              _lastSyncedNative = v;
              ref.read(craftControllerProvider.notifier).setRawTranscript(v);
            },
            onReTranslate: canRegenerate
                ? () => unawaited(_regenerate())
                : null,
          ),
          const SizedBox(height: 14),
        ],
        _TargetTextCard(
          controller: _targetCtrl,
          focusNode: _targetFocus,
          targetLabel: l10n.craftRewriteTargetLabel,
          targetBase: targetBase,
          theme: theme,
          enabled: !state.isBusy,
          onChanged: (v) {
            _lastSyncedTarget = v;
            ref.read(craftControllerProvider.notifier).setTranslatedText(v);
          },
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StylePicker(
                  value: state.style,
                  onChanged: (s) {
                    if (state.isBusy) return;
                    ref.read(craftControllerProvider.notifier).setStyle(s);
                  },
                ),
                Divider(
                  height: 20,
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
                VoicePicker(
                  language: state.targetLanguage,
                  selectedVoice: state.selectedVoice,
                  onChanged: (voice) {
                    if (state.isBusy) return;
                    ref
                        .read(craftControllerProvider.notifier)
                        .setSelectedVoice(
                          voice,
                          forLanguage: state.targetLanguage,
                        );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _ActionButtons(
          state: state,
          l10n: l10n,
          isRetranslating: isRetranslating,
          onReRecord: state.isBusy
              ? null
              : () => ref
                    .read(craftControllerProvider.notifier)
                    .resetForNextCapture(),
          onRegenerate: canRegenerate ? () => unawaited(_regenerate()) : null,
          onGenerateAudio:
              !state.isBusy &&
                  state.translatedText != null &&
                  state.translatedText!.trim().isNotEmpty
              ? () => ref.read(craftControllerProvider.notifier).generateAudio()
              : null,
        ),
      ],
    );
  }
}

// === Sub-widgets ===

class _NativeTextCard extends StatelessWidget {
  const _NativeTextCard({
    required this.controller,
    required this.focusNode,
    required this.l10n,
    required this.theme,
    required this.enabled,
    required this.showReTranslate,
    required this.isRetranslating,
    required this.onChanged,
    required this.onReTranslate,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool enabled;
  final bool showReTranslate;
  final bool isRetranslating;
  final ValueChanged<String> onChanged;
  final VoidCallback? onReTranslate;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final scheme = theme.colorScheme;
    final fieldRadius = BorderRadius.circular(t.radiusMd);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space16,
              t.space16,
              t.space12,
              t.space12,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                SizedBox(width: t.space8),
                Expanded(
                  child: Text(
                    l10n.craftRewriteYourWords,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (isRetranslating)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (showReTranslate)
                  TextButton(
                    onPressed: onReTranslate,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.symmetric(horizontal: t.space8),
                    ),
                    child: Text(l10n.craftReTranslateButton),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(t.space12, 0, t.space12, t.space12),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 3,
              maxLines: 10,
              textInputAction: TextInputAction.newline,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
              onChanged: onChanged,
              decoration: InputDecoration(
                filled: true,
                fillColor: scheme.surface.withValues(alpha: 0.55),
                isDense: false,
                contentPadding: EdgeInsets.all(t.space16),
                border: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.65),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.65),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(color: scheme.primary, width: 1.5),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetTextCard extends StatelessWidget {
  const _TargetTextCard({
    required this.controller,
    required this.focusNode,
    required this.targetLabel,
    required this.targetBase,
    required this.theme,
    required this.onChanged,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String targetLabel;
  final String targetBase;
  final ThemeData theme;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final scheme = theme.colorScheme;
    final fieldRadius = BorderRadius.circular(t.radiusMd);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space16,
              t.space16,
              t.space16,
              t.space12,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(t.radiusSm),
                  ),
                  child: Text(
                    targetBase,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: t.space8),
                Expanded(
                  child: Text(
                    targetLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(t.space12, 0, t.space12, t.space12),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 4,
              maxLines: 10,
              textInputAction: TextInputAction.newline,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
              onChanged: onChanged,
              decoration: InputDecoration(
                filled: true,
                fillColor: scheme.surface.withValues(alpha: 0.55),
                isDense: false,
                contentPadding: EdgeInsets.all(t.space16),
                border: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.65),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.65),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(color: scheme.primary, width: 1.5),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.state,
    required this.l10n,
    required this.isRetranslating,
    required this.onReRecord,
    required this.onRegenerate,
    required this.onGenerateAudio,
  });

  final CraftJobState state;
  final AppLocalizations l10n;
  final bool isRetranslating;
  final VoidCallback? onReRecord;
  final VoidCallback? onRegenerate;
  final VoidCallback? onGenerateAudio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onGenerateAudio,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.graphic_eq_rounded),
          label: Text(l10n.craftRewriteGenerateAudio),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReRecord,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.mic_rounded, size: 18),
                label: Text(l10n.craftRewriteReRecord),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRegenerate,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: isRetranslating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.craftRewriteRegenerate),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
