import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/craft/domain/craft_preferences.dart';
import 'package:enjoy_player/features/craft/domain/craft_screen_mode.dart';
import 'package:enjoy_player/features/craft/domain/translation_style.dart';

void main() {
  group('CraftPreferences defaults', () {
    test('toJson emits v1 with defaults and omits empty fields', () {
      final json = CraftPreferences.defaults.toJson();
      expect(json['v'], 1);
      expect(json['screenMode'], 'express');
      expect(json['expressStyle'], 'auto');
      expect(json['advancedStyle'], 'natural');
      expect(json.containsKey('customPrompt'), isFalse);
      expect(json.containsKey('voices'), isFalse);
    });

    test('fromJson of an empty map yields defaults', () {
      expect(CraftPreferences.fromJson(const {}), CraftPreferences.defaults);
    });
  });

  group('CraftPreferences round-trip', () {
    test('preserves every field', () {
      const prefs = CraftPreferences(
        screenMode: CraftScreenMode.advanced,
        expressStyle: TranslationStyle.casual,
        advancedStyle: TranslationStyle.formal,
        customPrompt: 'keep it short',
        voices: {'en': 'en-US-GuyNeural', 'ja': 'ja-JP-NanamiNeural'},
      );
      final decoded = CraftPreferences.fromJson(prefs.toJson());
      expect(decoded, prefs);
    });

    test('drops an empty customPrompt on encode', () {
      final json = const CraftPreferences(customPrompt: '').toJson();
      expect(json.containsKey('customPrompt'), isFalse);
      expect(CraftPreferences.fromJson(json).customPrompt, isNull);
    });

    test('drops an empty voices map on encode', () {
      final json = const CraftPreferences(voices: {}).toJson();
      expect(json.containsKey('voices'), isFalse);
    });
  });

  group('CraftPreferences.fromJson fallbacks', () {
    test('foreign schema version ignores the whole blob', () {
      expect(
        CraftPreferences.fromJson(const {
          'v': 2,
          'screenMode': 'advanced',
          'expressStyle': 'casual',
          'advancedStyle': 'formal',
          'customPrompt': 'x',
          'voices': {'en': 'en-US-GuyNeural'},
        }),
        CraftPreferences.defaults,
      );
      expect(
        CraftPreferences.fromJson(const {'screenMode': 'advanced'}),
        CraftPreferences.defaults,
      );
    });

    test('unknown style names fall back per field', () {
      final prefs = CraftPreferences.fromJson(const {
        'v': 1,
        'expressStyle': 'nope',
        'advancedStyle': 'formal',
      });
      expect(prefs.expressStyle, TranslationStyle.auto);
      expect(prefs.advancedStyle, TranslationStyle.formal);
    });

    test('unknown screenMode falls back to express', () {
      expect(
        CraftPreferences.fromJson(const {
          'v': 1,
          'screenMode': 'wizard',
        }).screenMode,
        CraftScreenMode.express,
      );
    });

    test('ill-typed fields fall back instead of throwing', () {
      final prefs = CraftPreferences.fromJson(const {
        'v': 1,
        'screenMode': 42,
        'expressStyle': true,
        'customPrompt': 7,
        'voices': 'nope',
      });
      expect(prefs, CraftPreferences.defaults);
    });

    test('empty customPrompt decodes to null', () {
      expect(
        CraftPreferences.fromJson(const {
          'v': 1,
          'customPrompt': '',
        }).customPrompt,
        isNull,
      );
    });
  });

  group('CraftPreferences voice validation', () {
    test('keeps entries whose voice exists and matches the key', () {
      final prefs = CraftPreferences.fromJson(const {
        'v': 1,
        'voices': {'en': 'en-US-GuyNeural', 'ja': 'ja-JP-NanamiNeural'},
      });
      expect(prefs.voices, {
        'en': 'en-US-GuyNeural',
        'ja': 'ja-JP-NanamiNeural',
      });
    });

    test('drops unknown voice ids and base-lang mismatches', () {
      final prefs = CraftPreferences.fromJson(const {
        'v': 1,
        'voices': {
          'en': 'xx-UnknownNeural', // not in the catalog
          'ja': 'en-US-GuyNeural', // wrong language for the key
        },
      });
      expect(prefs.voices, isEmpty);
    });

    test('normalizes uppercase keys to lowercase', () {
      final prefs = CraftPreferences.fromJson(const {
        'v': 1,
        'voices': {'EN': 'en-US-GuyNeural'},
      });
      expect(prefs.voices, {'en': 'en-US-GuyNeural'});
    });

    test('ignores non-string entries', () {
      final prefs = CraftPreferences.fromJson(const {
        'v': 1,
        'voices': {'en': 42, 7: 'en-US-GuyNeural'},
      });
      expect(prefs.voices, isEmpty);
    });
  });
}
