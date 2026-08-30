/// Translate tool panel for the Craft screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/presentation/loading_icon.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';
import 'package:enjoy_player/features/craft/application/craft_controller.dart';
import 'package:enjoy_player/features/craft/domain/craft_failure.dart';
import 'package:enjoy_player/features/subscription/presentation/credits_failure_actions.dart';
import 'package:enjoy_player/features/craft/domain/craft_request.dart';
import 'package:enjoy_player/features/craft/domain/translation_style.dart';
import 'package:enjoy_player/features/craft/presentation/style_picker.dart';
import 'package:enjoy_player/features/library/presentation/widgets/content_language_picker.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class TranslateTool extends ConsumerStatefulWidget {
  const TranslateTool({super.key});

  @override
  ConsumerState<TranslateTool> createState() => _TranslateToolState();
}

class _TranslateToolState extends ConsumerState<TranslateTool> {
  late final TextEditingController _sourceCtrl;
  late final TextEditingController _resultCtrl;

  @override
  void initState() {
    super.initState();
    _sourceCtrl = TextEditingController();
    _resultCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prefs = ref.read(appPreferencesCtrlProvider);
      final prefsState = prefs.whenOrNull(data: (s) => s);
      final nativeLang = canonicalMediaLanguageTag(
        prefsState?.effectiveNativeLanguage ?? 'en',
      );
      final learnLang = canonicalMediaLanguageTag(
        prefsState?.effectiveLearningLanguage ?? 'en',
      );
      ref.read(craftControllerProvider.notifier)
        ..setSourceLanguage(nativeLang)
        ..setTargetLanguage(learnLang);
    });
  }

  @override
  void dispose() {
    _sourceCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(craftControllerProvider);
    final controller = ref.read(craftControllerProvider.notifier);
    final theme = Theme.of(context);

    // Sync result controller with state.
    if (state.translatedText != null &&
        _resultCtrl.text != state.translatedText &&
        !_resultCtrl.selection.isValid) {
      _resultCtrl.text = state.translatedText!;
    }

    final tokens = EnjoyThemeTokens.of(context);
    final canTranslate =
        !state.isTranslating &&
        normalizeCraftText(state.sourceText).length >= craftMinTextLength;

    return EnjoyCard(
      padding: EdgeInsets.all(tokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.craftTranslateTool,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.space16),
          _LanguageRow(
            sourceLabel: l10n.craftSourceLanguageLabel,
            targetLabel: l10n.craftTargetLanguageLabel,
            sourceValue: state.sourceLanguage ?? '—',
            targetValue: state.targetLanguage,
            onSwap: controller.swapLanguages,
            onPickSource: () =>
                _pickLanguage(isSource: true, current: state.sourceLanguage),
            onPickTarget: () =>
                _pickLanguage(isSource: false, current: state.targetLanguage),
          ),
          SizedBox(height: tokens.space16),
          StylePicker(value: state.style, onChanged: controller.setStyle),
          if (state.style == TranslationStyle.custom) ...[
            SizedBox(height: tokens.space8),
            TextField(
              decoration: InputDecoration(
                hintText: l10n.craftCustomPromptHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              onChanged: controller.setCustomPrompt,
            ),
          ],
          SizedBox(height: tokens.space16),
          TextField(
            controller: _sourceCtrl,
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              labelText: l10n.craftSourceText,
              hintText: l10n.craftTextInputHint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste_rounded, size: 18),
                tooltip: l10n.craftPasteFromClipboard,
                onPressed: () => _paste(_sourceCtrl, controller.setSourceText),
              ),
            ),
            onChanged: controller.setSourceText,
          ),
          SizedBox(height: tokens.space16),
          EnjoyButton.primary(
            onPressed: canTranslate ? controller.translate : null,
            icon: state.isTranslating ? null : Icons.translate_rounded,
            child: state.isTranslating
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LoadingIcon(size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.craftLoadingRewriting),
                    ],
                  )
                : Text(
                    state.translatedText != null
                        ? l10n.craftReTranslateButton
                        : l10n.craftTranslateButton,
                  ),
          ),
          if (state.translatedText != null) ...[
            SizedBox(height: tokens.space20),
            Text(
              l10n.craftTranslatedText,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: tokens.space8),
            TextField(
              controller: _resultCtrl,
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: controller.setTranslatedText,
            ),
            SizedBox(height: tokens.space12),
            Row(
              children: [
                Expanded(
                  child: EnjoyButton.ghost(
                    onPressed: () => _copy(state.translatedText!, l10n),
                    icon: Icons.copy_rounded,
                    child: Text(l10n.craftCopyTranslation),
                  ),
                ),
                SizedBox(width: tokens.space8),
                Expanded(
                  child: EnjoyButton.secondary(
                    onPressed: controller.useTranslatedText,
                    icon: Icons.arrow_downward_rounded,
                    child: Text(l10n.craftUseTranslatedText),
                  ),
                ),
              ],
            ),
          ],
          if (state.failure != null)
            Padding(
              padding: EdgeInsets.only(top: tokens.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.failure!.message(l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  // One-tap recovery for credits rejections (spec 045).
                  if (state.failure is CraftCreditsFailure)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => unawaited(context.push('/subscription')),
                      child: Text(creditsCtaLabel(l10n)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage({
    required bool isSource,
    required String? current,
  }) async {
    final picked = await showContentLanguagePicker(
      context: context,
      ref: ref,
      selectedValue: current,
    );
    if (picked != null) {
      final controller = ref.read(craftControllerProvider.notifier);
      if (isSource) {
        controller.setSourceLanguage(picked);
      } else {
        controller.setTargetLanguage(picked);
      }
    }
  }

  Future<void> _paste(
    TextEditingController ctrl,
    void Function(String) onChanged,
  ) async {
    final clip = await Clipboard.getData('text/plain');
    final t = clip?.text;
    if (t != null && t.isNotEmpty) {
      ctrl.text = t;
      onChanged(t);
    }
  }

  void _copy(String text, AppLocalizations l10n) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    if (!mounted) return;
    AppNotice.success(context, l10n.craftCopiedToClipboard);
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.sourceLabel,
    required this.targetLabel,
    required this.sourceValue,
    required this.targetValue,
    required this.onSwap,
    required this.onPickSource,
    required this.onPickTarget,
  });

  final String sourceLabel;
  final String targetLabel;
  final String sourceValue;
  final String targetValue;
  final VoidCallback onSwap;
  final VoidCallback onPickSource;
  final VoidCallback onPickTarget;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LangTile(
            label: sourceLabel,
            value: sourceValue.toUpperCase(),
            onTap: onPickSource,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.swap_horiz_rounded),
          tooltip: AppLocalizations.of(context)!.craftSwapLanguages,
          onPressed: onSwap,
        ),
        Expanded(
          child: _LangTile(
            label: targetLabel,
            value: targetValue.toUpperCase(),
            onTap: onPickTarget,
          ),
        ),
      ],
    );
  }
}

class _LangTile extends StatelessWidget {
  const _LangTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(t.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(t.radiusMd),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.space12,
            vertical: t.space8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
