import 'package:enjoy_player/features/craft/domain/translation_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TranslationStyle.promptSuffix', () {
    test('auto and custom return empty (no built-in instruction)', () {
      expect(TranslationStyle.auto.promptSuffix, isEmpty);
      expect(TranslationStyle.custom.promptSuffix, isEmpty);
    });

    test('literal preserves original sentence structure', () {
      expect(TranslationStyle.literal.promptSuffix, contains('literally'));
    });

    test('natural talks about fluency', () {
      expect(TranslationStyle.natural.promptSuffix, contains('naturally'));
    });

    test('casual talks about conversational tone', () {
      expect(TranslationStyle.casual.promptSuffix, contains('casual'));
    });

    test('formal talks about professional register', () {
      expect(TranslationStyle.formal.promptSuffix, contains('formal'));
    });

    test('simplified targets beginners', () {
      expect(TranslationStyle.simplified.promptSuffix, contains('simple'));
    });

    test('detailed adds context and nuance', () {
      expect(
        TranslationStyle.detailed.promptSuffix,
        contains('additional context'),
      );
    });
  });

  group('TranslationStyle.showsCustomPrompt', () {
    test('only custom and auto reveal the prompt input', () {
      expect(TranslationStyle.custom.showsCustomPrompt, isTrue);
      expect(TranslationStyle.auto.showsCustomPrompt, isTrue);
    });

    test('all other styles hide the custom prompt input', () {
      for (final style in TranslationStyle.values) {
        if (style == TranslationStyle.custom ||
            style == TranslationStyle.auto) {
          continue;
        }
        expect(style.showsCustomPrompt, isFalse, reason: 'style=$style');
      }
    });
  });

  group('TranslationStyle.l10nKey', () {
    test('every enum value has a unique craft-style l10n key', () {
      final keys = <String>{};
      for (final style in TranslationStyle.values) {
        expect(style.l10nKey, startsWith('craftStyle'));
        expect(
          keys.add(style.l10nKey),
          isTrue,
          reason: 'duplicate: ${style.l10nKey}',
        );
      }
    });

    test('specific keys match the ARB resource bundle', () {
      expect(TranslationStyle.auto.l10nKey, 'craftStyleAuto');
      expect(TranslationStyle.literal.l10nKey, 'craftStyleLiteral');
      expect(TranslationStyle.natural.l10nKey, 'craftStyleNatural');
      expect(TranslationStyle.casual.l10nKey, 'craftStyleCasual');
      expect(TranslationStyle.formal.l10nKey, 'craftStyleFormal');
      expect(TranslationStyle.simplified.l10nKey, 'craftStyleSimplified');
      expect(TranslationStyle.detailed.l10nKey, 'craftStyleDetailed');
      expect(TranslationStyle.custom.l10nKey, 'craftStyleCustom');
    });
  });

  group('TranslationStyle.values', () {
    test('contains every expected preset', () {
      expect(
        TranslationStyle.values,
        containsAll([
          TranslationStyle.auto,
          TranslationStyle.literal,
          TranslationStyle.natural,
          TranslationStyle.casual,
          TranslationStyle.formal,
          TranslationStyle.simplified,
          TranslationStyle.detailed,
          TranslationStyle.custom,
        ]),
      );
    });
  });
}
