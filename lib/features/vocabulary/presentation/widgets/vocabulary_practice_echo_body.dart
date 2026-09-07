/// Echo recorder body for the vocabulary practice sheet.
///
/// Recorder-only: no [PlayerController], WebView, or global echo activation.
/// Shows the context sentence above the shadow-reading controls so the learner
/// can read while recording.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/analytics/analytics_events.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/shadow_reading_panel.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_text_style.dart';

@visibleForTesting
ShadowReadingPanel buildVocabularyEchoRecorder({
  required VocabularyContext contextItem,
  required String language,
}) {
  final locator = contextItem.locator!;
  final targetType = switch (contextItem.sourceType) {
    VocabularySourceType.audio => 'Audio',
    VocabularySourceType.video => 'Video',
    VocabularySourceType.ebook => 'Video',
  };
  return ShadowReadingPanel(
    mediaId: contextItem.sourceId,
    targetType: targetType,
    language: language,
    startSec: locator.start / 1000.0,
    endSec: (locator.start + locator.duration) / 1000.0,
    referenceText: contextItem.text,
    // Enables recorder/assessment actions; global player EchoMode remains off.
    echoActive: true,
    analyticsSurface: AnalyticsEvents.surfaceFlashcard,
  );
}

class VocabularyPracticeEchoBody extends ConsumerWidget {
  const VocabularyPracticeEchoBody({
    super.key,
    required this.contextItem,
    required this.language,
    required this.word,
  });

  final VocabularyContext contextItem;
  final String language;

  /// Vocabulary item word — highlighted inside the context sentence.
  final String word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final locator = contextItem.locator;
    if (locator == null) return const SizedBox.shrink();

    final readingBase = tt.bodyLarge?.copyWith(
      height: 1.55,
      color: cs.onSurface.withValues(alpha: 0.92),
    );
    final readingHighlight = readingBase?.copyWith(
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
      backgroundColor: cs.primary.withValues(alpha: 0.18),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: t.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VocabularyEchoReadingText(
            text: contextItem.text,
            word: word,
            baseStyle: readingBase ?? const TextStyle(),
            highlightStyle: readingHighlight ?? const TextStyle(),
          ),
          SizedBox(height: t.space16),
          buildVocabularyEchoRecorder(
            contextItem: contextItem,
            language: language,
          ),
        ],
      ),
    );
  }
}

/// Context sentence shown above the recorder for reading practice.
@visibleForTesting
class VocabularyEchoReadingText extends StatelessWidget {
  const VocabularyEchoReadingText({
    super.key,
    required this.text,
    required this.word,
    required this.baseStyle,
    required this.highlightStyle,
  });

  final String text;
  final String word;
  final TextStyle baseStyle;
  final TextStyle highlightStyle;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(width: 3, color: cs.primary.withValues(alpha: 0.45)),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: t.space16),
        child: Text.rich(
          TextSpan(
            children: highlightVocabularyWord(
              text: text,
              word: word,
              base: baseStyle,
              highlight: highlightStyle,
            ),
          ),
        ),
      ),
    );
  }
}
