import 'package:enjoy_player/features/ai/domain/byok_config_validator.dart';
import 'package:enjoy_player/features/ai/presentation/settings/byok_validation_messages.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('ByokValidationErrorL10n.message', () {
    test('apiKeyRequired maps to "API key is required."', () {
      expect(
        ByokValidationError.apiKeyRequired.message(l10n),
        'API key is required.',
      );
    });

    test('baseUrlRequired maps to "Base URL is required."', () {
      expect(
        ByokValidationError.baseUrlRequired.message(l10n),
        'Base URL is required.',
      );
    });

    test('baseUrlInvalid maps to public HTTPS error', () {
      expect(
        ByokValidationError.baseUrlInvalid.message(l10n),
        'Base URL must be a public HTTPS endpoint.',
      );
    });

    test('modelRequired maps to "Model is required."', () {
      expect(
        ByokValidationError.modelRequired.message(l10n),
        'Model is required.',
      );
    });

    test('regionRequired maps to Azure region error', () {
      expect(
        ByokValidationError.regionRequired.message(l10n),
        'Azure region is required.',
      );
    });

    test('apiSpecRequired maps to "Protocol configuration is incomplete."', () {
      expect(
        ByokValidationError.apiSpecRequired.message(l10n),
        'Protocol configuration is incomplete.',
      );
    });

    test('azureKindRequired maps to "Azure Speech required" error', () {
      expect(
        ByokValidationError.azureKindRequired.message(l10n),
        contains('Azure Speech'),
      );
    });
  });

  group('formatByokValidationErrors', () {
    test('returns empty string for empty error list', () {
      expect(formatByokValidationErrors(l10n, const []), '');
    });

    test('joins single error message', () {
      final result = formatByokValidationErrors(l10n, [
        ByokValidationError.apiKeyRequired,
      ]);
      expect(result, 'API key is required.');
      expect(result, isNot(contains('\n')));
    });

    test('joins multiple errors with newline', () {
      final result = formatByokValidationErrors(l10n, [
        ByokValidationError.apiKeyRequired,
        ByokValidationError.baseUrlRequired,
      ]);
      expect(result, 'API key is required.\nBase URL is required.');
    });

    test('preserves order of input errors', () {
      final result = formatByokValidationErrors(l10n, [
        ByokValidationError.modelRequired,
        ByokValidationError.baseUrlInvalid,
        ByokValidationError.regionRequired,
      ]);
      expect(
        result,
        'Model is required.\n'
        'Base URL must be a public HTTPS endpoint.\n'
        'Azure region is required.',
      );
    });

    test('handles all 7 enum values without truncation', () {
      final result = formatByokValidationErrors(l10n, [
        ByokValidationError.apiKeyRequired,
        ByokValidationError.baseUrlRequired,
        ByokValidationError.baseUrlInvalid,
        ByokValidationError.modelRequired,
        ByokValidationError.regionRequired,
        ByokValidationError.apiSpecRequired,
        ByokValidationError.azureKindRequired,
      ]);
      // Expect 6 newline separators (7 messages → 6 newlines).
      expect('\n'.allMatches(result).length, 6);
      expect(result.split('\n'), hasLength(7));
    });
  });
}
