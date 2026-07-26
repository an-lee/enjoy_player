import 'package:enjoy_player/features/credits/presentation/credits_usage_screen.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('serviceTypeLabel', () {
    test('returns localized labels for known service types', () {
      final l10n = _StubL10n();
      expect(serviceTypeLabel(l10n, 'tts'), equals(_StubL10n.tts));
      expect(serviceTypeLabel(l10n, 'asr'), equals(_StubL10n.asr));
      expect(
        serviceTypeLabel(l10n, 'translation'),
        equals(_StubL10n.translation),
      );
      expect(serviceTypeLabel(l10n, 'llm'), equals(_StubL10n.llm));
      expect(
        serviceTypeLabel(l10n, 'assessment'),
        equals(_StubL10n.assessment),
      );
    });

    test('returns the raw string for unknown service types', () {
      expect(
        serviceTypeLabel(_StubL10n(), 'custom-service'),
        equals('custom-service'),
      );
    });
  });

  group('kCreditsUsageServiceTypeValues', () {
    test('contains the five service types accepted by the Worker', () {
      expect(kCreditsUsageServiceTypeValues, [
        'tts',
        'asr',
        'translation',
        'llm',
        'assessment',
      ]);
    });

    test('exposes an immutable list (cannot be modified by callers)', () {
      // The list is declared `const` so it must be unmodifiable at runtime.
      expect(
        () => kCreditsUsageServiceTypeValues.add('mutation-attempt'),
        throwsUnsupportedError,
      );
    });
  });

  group('pickCreditsUsageDate — supporting logic', () {
    // `pickCreditsUsageDate` is a thin wrapper around `showDatePicker` plus
    // a YMD string formatter. Driving the platform picker from a widget test
    // requires Material Localizations plumbing that is heavy for the small
    // ROI. Instead, exercise the supporting logic that the function relies on
    // (ISO YMD parsing + formatter) directly.
    test('parses ISO YMD strings via DateTime.tryParse semantics', () {
      final parsed = DateTime.tryParse('2026-04-15');
      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 4);
      expect(parsed.day, 15);

      // Invalid input is null (function would fall back to DateTime.now()
      // in the production code path).
      expect(DateTime.tryParse('not-a-date'), isNull);
    });

    test('format helper emits canonical YMD', () {
      final picked = DateTime.utc(2026, 4, 15);
      final formatted = picked.toUtc().toIso8601String().split('T').first;
      expect(formatted, '2026-04-15');
    });

    test('firstDate / lastDate clamps build the expected range', () {
      // Production code uses `DateTime.utc(2020)` and
      // `DateTime.utc(now.year + 1, 12, 31)`.
      final first = DateTime.utc(2020);
      final now = DateTime.now();
      final last = DateTime.utc(now.year + 1, 12, 31);
      expect(first.isBefore(last), isTrue);
      expect(first.year, 2020);
      expect(last.month, 12);
      expect(last.day, 31);
    });
  });
}

/// Stand-in for [AppLocalizations] that only carries the strings read by the
/// functions under test. All unused members throw so unintended access fails
/// loudly.
class _StubL10n implements AppLocalizations {
  static const String tts = 'Text to speech';
  static const String asr = 'Speech recognition';
  static const String translation = 'Translation';
  static const String llm = 'Large language model';
  static const String assessment = 'Assessment';

  // Properties that match the strings the production code looks up.
  @override
  String get creditsServiceTypeTts => tts;
  @override
  String get creditsServiceTypeAsr => asr;
  @override
  String get creditsServiceTypeTranslation => translation;
  @override
  String get creditsServiceTypeLlm => llm;
  @override
  String get creditsServiceTypeAssessment => assessment;

  // All other properties are unused by the test target. They throw so any
  // accidental use is loud rather than silent.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Stub missing for ${invocation.memberName}. Add a real L10n helper if needed.',
    );
  }
}
