/// Bottom sheet or wide dialog: translation, definition (dictionary), contextual translation.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/sheet_drag_handle.dart';
import 'package:enjoy_player/features/lookup/application/lookup_sheet_result_cache.dart';
import 'package:enjoy_player/features/lookup/application/lookup_target_languages.dart';
import 'package:enjoy_player/features/lookup/domain/lookup_request.dart';
import 'package:enjoy_player/features/lookup/presentation/sections/contextual_translation_lookup_section.dart';
import 'package:enjoy_player/features/lookup/presentation/sections/dictionary_lookup_section.dart';
import 'package:enjoy_player/features/lookup/presentation/sections/translation_lookup_section.dart';
import 'package:enjoy_player/features/lookup/presentation/widgets/lookup_language_picker_row.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';
import 'package:enjoy_player/features/pronounce/presentation/pronounce_icon_button.dart';
import 'package:enjoy_player/features/vocabulary/presentation/add_to_vocabulary_control.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// [bottomSheet] uses [DraggableScrollableSheet]; [dialog] uses a scroll view with bounded height.
enum DictionaryLookupPresentation { bottomSheet, dialog }

class DictionaryLookupSheet extends ConsumerStatefulWidget {
  const DictionaryLookupSheet({
    required this.request,
    this.presentation = DictionaryLookupPresentation.bottomSheet,
    super.key,
  });

  final LookupRequest request;
  final DictionaryLookupPresentation presentation;

  @override
  ConsumerState<DictionaryLookupSheet> createState() =>
      _DictionaryLookupSheetState();
}

class _DictionaryLookupSheetState extends ConsumerState<DictionaryLookupSheet> {
  late String _sourceLanguage;
  late String _targetLanguage;
  ScrollController? _dialogScroll;
  PronouncePlaybackController? _pronounce;

  static const double _hPad = 20;
  static final _log = logNamed('Lookup');

  String get _learningTag {
    final prefs = ref.read(appPreferencesCtrlProvider).valueOrNull;
    return prefs?.effectiveLearningLanguage ?? kDefaultLearningLanguageTag;
  }

  @override
  void initState() {
    super.initState();
    _sourceLanguage = widget.request.sourceLanguage;
    _targetLanguage = widget.request.targetLanguage;
    if (widget.presentation == DictionaryLookupPresentation.dialog) {
      _dialogScroll = ScrollController();
    }
  }

  @override
  void dispose() {
    // Cached notifier — ref is unsafe after unmount.
    unawaited(_pronounce?.stop() ?? Future<void>.value());
    _dialogScroll?.dispose();
    super.dispose();
  }

  void _changeSource(String next) {
    final l10n = AppLocalizations.of(context);
    final prev = _sourceLanguage;
    final override = resolveLookupSourceOverride(next);
    if (override != null) {
      if (tagsEqual(prev, override)) return;
      _evictPriorPair(prev, _targetLanguage);
      _stopPronounce();
      setState(() => _sourceLanguage = override);
      _log.info('lookup source $prev → $override');
      return;
    }
    AppNotice.info(context, l10n?.lookupSourceResetToLearning ?? '');
  }

  void _changeTarget(String next) {
    final prev = _targetLanguage;
    if (tagsEqual(prev, next)) return;
    _evictPriorPair(_sourceLanguage, prev);
    setState(() => _targetLanguage = next);
    _log.info('lookup target $prev → $next');
  }

  void _swapLanguages() {
    final prevSource = _sourceLanguage;
    final prevTarget = _targetLanguage;
    if (tagsEqual(prevSource, prevTarget)) return;
    _evictPriorPair(prevSource, prevTarget);
    _stopPronounce();
    setState(() {
      _sourceLanguage = prevTarget;
      _targetLanguage = prevSource;
    });
    _log.info('lookup swap $prevSource/$prevTarget → $prevTarget/$prevSource');
  }

  void _evictPriorPair(String source, String target) {
    if (source.isEmpty || target.isEmpty) return;
    if (tagsEqual(source, target)) return;
    unawaited(
      ref
          .read(lookupSheetResultCacheProvider)
          .evictForPair(sourceLanguage: source, targetLanguage: target),
    );
  }

  void _stopPronounce() {
    final ctrl = ref.read(pronouncePlaybackControllerProvider.notifier);
    _pronounce = ctrl;
    unawaited(ctrl.stop());
  }

  LookupRequest get _effectiveRequest => LookupRequest(
    selectedText: widget.request.selectedText,
    sourceLanguage: _sourceLanguage,
    targetLanguage: _targetLanguage,
    contextualContext: widget.request.contextualContext,
    mediaVocabularyContext: widget.request.mediaVocabularyContext,
  );

  Future<void> _copySelection(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: widget.request.selectedText));
    if (!context.mounted) return;
    AppNotice.success(context, l10n.lookupCopySuccess);
  }

  Widget _mainColumn(ScrollController scrollCtrl) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(
          constraints.maxWidth,
          t.contentMaxWidth + 2 * _hPad,
        );

        Widget constrain(Widget child) => Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: maxWidth, child: child),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.presentation == DictionaryLookupPresentation.bottomSheet)
              const PaddedSheetDragHandle()
            else
              SizedBox(height: t.space8),
            constrain(
              Padding(
                padding: const EdgeInsets.only(left: _hPad, right: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.lookupSheetTitle,
                        style: tt.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    AddToVocabularyControl(request: _effectiveRequest),
                    PronounceIconButton(
                      text: widget.request.selectedText,
                      localeTag: _sourceLanguage,
                      surfaceId: PronounceSurfaceId.lookup,
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        fixedSize: const Size(44, 44),
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                      tooltip: l10n.lookupCopy,
                      onPressed: () => _copySelection(context),
                      icon: const Icon(Icons.copy_all_rounded, size: 18),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        fixedSize: const Size(44, 44),
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                      tooltip: l10n.lookupClose,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            constrain(
              Padding(
                padding: const EdgeInsets.fromLTRB(_hPad, 2, _hPad, 8),
                child: SelectableText(
                  widget.request.selectedText,
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            constrain(
              Padding(
                padding: const EdgeInsets.fromLTRB(_hPad, 6, _hPad, 8),
                child: LookupLanguagePickerRow(
                  sourceLanguage: _sourceLanguage,
                  targetLanguage: _targetLanguage,
                  learningTag: _learningTag,
                  onSourceChanged: (v) => _changeSource(v),
                  onTargetChanged: (v) => _changeTarget(v),
                  onSwap: _swapLanguages,
                ),
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.2),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                  _hPad,
                  t.space12,
                  _hPad,
                  t.space24,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: t.contentMaxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TranslationLookupSection(request: _effectiveRequest),
                          SizedBox(height: t.space8),
                          DictionaryLookupSection(request: _effectiveRequest),
                          SizedBox(height: t.space8),
                          ContextualTranslationLookupSection(
                            request: _effectiveRequest,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _pronounce ??= ref.read(pronouncePlaybackControllerProvider.notifier);
    if (widget.presentation == DictionaryLookupPresentation.dialog) {
      return _mainColumn(_dialogScroll!);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => _mainColumn(scrollCtrl),
    );
  }
}
