// Tests for the Craft pipeline failure sealed hierarchy.
//
// Each subclass maps to (a) a typed `CraftFailureAction` and (b) a localized
// user-visible message via `AppLocalizations`. We assert both here so that
// adding/removing a subclass or renaming a l10n key surfaces as a test failure
// rather than a regression in the calm-error UX spec FR-022.
import 'package:enjoy_player/features/craft/domain/craft_failure.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:enjoy_player/l10n/app_localizations_en.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CraftFailure sealed hierarchy', () {
    test('CraftTranslateFailure uses retry and craftFailureTranslate', () {
      const f = CraftTranslateFailure();
      expect(f.action, CraftFailureAction.retry);
      // Action has no data; detail is intentionally a side-channel.
      expect(f.detail, isNull);
    });

    test('CraftTranslateFailure carries an optional detail', () {
      const f = CraftTranslateFailure(detail: 'http 500');
      expect(f.detail, 'http 500');
    });

    test('CraftTtsFailure defaults to retry', () {
      const f = CraftTtsFailure();
      expect(f.action, CraftFailureAction.retry);
      expect(f.detail, isNull);
    });

    test('CraftTtsFailure can be raised with openAiSettings', () {
      const f = CraftTtsFailure(action: CraftFailureAction.openAiSettings);
      expect(f.action, CraftFailureAction.openAiSettings);
    });

    test('CraftSaveFailure uses retry', () {
      const f = CraftSaveFailure(detail: 'disk full');
      expect(f.action, CraftFailureAction.retry);
      expect(f.detail, 'disk full');
    });

    test('CraftSignInRequiredFailure uses signIn', () {
      const f = CraftSignInRequiredFailure();
      expect(f.action, CraftFailureAction.signIn);
    });

    test('CraftOfflineFailure uses retry', () {
      const f = CraftOfflineFailure();
      expect(f.action, CraftFailureAction.retry);
    });

    test('CraftSameLanguageFailure uses switchToSpeakDirectly', () {
      const f = CraftSameLanguageFailure();
      expect(f.action, CraftFailureAction.switchToSpeakDirectly);
    });

    test('CraftVendorUnsupportedLanguageFailure carries a language', () {
      const f = CraftVendorUnsupportedLanguageFailure(language: 'fr');
      expect(f.action, CraftFailureAction.retry);
      expect(f.language, 'fr');
    });

    test('CraftAsrFailure uses retry', () {
      const f = CraftAsrFailure();
      expect(f.action, CraftFailureAction.retry);
    });

    test('CraftEmptyTranscriptFailure uses retry', () {
      const f = CraftEmptyTranscriptFailure();
      expect(f.action, CraftFailureAction.retry);
    });
  });

  group('CraftFailure.message()', () {
    // We assert the strings come from `AppLocalizations` rather than free-text
    // raw exception strings (FR-022 forbids raw exceptions in user-visible
    // text). Use the generated `AppLocalizationsEn` so we exercise the real
    // English message strings without spinning up a full app shell.
    late AppLocalizations l10n;

    setUpAll(() {
      l10n = AppLocalizationsEn();
    });

    test('every failure maps to a non-empty, non-raw-exception message', () {
      const failures = <CraftFailure>[
        CraftTranslateFailure(),
        CraftTtsFailure(),
        CraftSaveFailure(),
        CraftSignInRequiredFailure(),
        CraftOfflineFailure(),
        CraftSameLanguageFailure(),
        CraftVendorUnsupportedLanguageFailure(language: 'fr'),
        CraftAsrFailure(),
        CraftEmptyTranscriptFailure(),
      ];

      for (final f in failures) {
        final msg = f.message(l10n);
        expect(msg, isNotEmpty, reason: 'failure=$f must have a message');
        // Raw exception text must not leak.
        expect(msg, isNot(contains('Exception')));
        expect(msg, isNot(contains('Error:')));
      }
    });

    test('CraftSameLanguageFailure uses the same-language hint string', () {
      const f = CraftSameLanguageFailure();
      expect(f.message(l10n), l10n.craftSameLanguageHint);
    });
  });
}
