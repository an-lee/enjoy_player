// Pure-function coverage for lib/features/hotkeys/presentation/hotkey_format.dart.
//
// `hotkeyDisplayTokens` and `formatHotkeyForDisplay` translate raw binding
// strings (e.g. "ctrl+shift+a") into UI-readable chips ("Ctrl+Shift+A").
// The function has many branches (modifier aliases, special characters,
// uppercase fallback). We pin every branch so future refactors don't
// silently change a UI label.
import 'package:enjoy_player/features/hotkeys/presentation/hotkey_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hotkeyDisplayTokens (modifier aliases)', () {
    test('ctrl → Ctrl', () {
      expect(hotkeyDisplayTokens('ctrl+a'), ['Ctrl', 'A']);
    });

    test('control → Ctrl', () {
      expect(hotkeyDisplayTokens('control+b'), ['Ctrl', 'B']);
    });

    test('shift → Shift', () {
      expect(hotkeyDisplayTokens('shift+c'), ['Shift', 'C']);
    });

    test('alt → Alt', () {
      expect(hotkeyDisplayTokens('alt+d'), ['Alt', 'D']);
    });

    test('meta → Win', () {
      expect(hotkeyDisplayTokens('meta+e'), ['Win', 'E']);
    });

    test('cmd → Win (alias of meta)', () {
      expect(hotkeyDisplayTokens('cmd+f'), ['Win', 'F']);
    });
  });

  group('hotkeyDisplayTokens (named keys)', () {
    test('escape → Esc', () {
      expect(hotkeyDisplayTokens('escape'), ['Esc']);
    });

    test('enter / return → Enter (both spellings supported)', () {
      expect(hotkeyDisplayTokens('enter'), ['Enter']);
      expect(hotkeyDisplayTokens('return'), ['Enter']);
    });

    test('space → Space', () {
      expect(hotkeyDisplayTokens('space'), ['Space']);
    });

    test('tab → Tab', () {
      expect(hotkeyDisplayTokens('tab'), ['Tab']);
    });

    test('backspace → Backspace', () {
      expect(hotkeyDisplayTokens('backspace'), ['Backspace']);
    });

    test('delete → Del', () {
      expect(hotkeyDisplayTokens('delete'), ['Del']);
    });
  });

  group('hotkeyDisplayTokens (arrow keys → unicode glyphs)', () {
    test('ArrowLeft → ←', () {
      expect(hotkeyDisplayTokens('arrowleft'), ['←']);
    });

    test('ArrowRight → →', () {
      expect(hotkeyDisplayTokens('arrowright'), ['→']);
    });

    test('ArrowUp → ↑', () {
      expect(hotkeyDisplayTokens('arrowup'), ['↑']);
    });

    test('ArrowDown → ↓', () {
      expect(hotkeyDisplayTokens('arrowdown'), ['↓']);
    });
  });

  group('hotkeyDisplayTokens (punctuation aliases)', () {
    test('comma → ,', () {
      expect(hotkeyDisplayTokens('comma'), [',']);
    });

    test('period → .', () {
      expect(hotkeyDisplayTokens('period'), ['.']);
    });

    test('slash → / (non-bind-token context)', () {
      // Only "shift+slash" gets the special "?" mapping; bare "slash" → "/".
      expect(hotkeyDisplayTokens('slash'), ['/']);
    });
  });

  group('hotkeyDisplayTokens (special-case: shift+slash)', () {
    test('shift+slash → ? (regardless of modifier casing)', () {
      expect(hotkeyDisplayTokens('shift+slash'), const ['?']);
      expect(hotkeyDisplayTokens('Shift+Slash'), const ['?']);
    });
  });

  group('hotkeyDisplayTokens (brace literals)', () {
    test('{ → {', () {
      expect(hotkeyDisplayTokens('{'), ['{']);
    });

    test('} → }', () {
      expect(hotkeyDisplayTokens('}'), ['}']);
    });
  });

  group('hotkeyDisplayTokens (lowercase letter keys)', () {
    test('a → A (single-letter, alphabetic)', () {
      expect(hotkeyDisplayTokens('a'), ['A']);
    });

    test('z → Z', () {
      expect(hotkeyDisplayTokens('z'), ['Z']);
    });

    test('multi-binding: ctrl+shift+slash stays as [/] tokens', () {
      // Input is split on "+"; "/" is one of the symbols that should NOT be
      // uppercased because it's not a letter. So output is [Ctrl, Shift, /].
      expect(hotkeyDisplayTokens('ctrl+shift+slash'), ['Ctrl', 'Shift', '/']);
    });
  });

  group('hotkeyDisplayTokens (single-character edge cases)', () {
    test('[ → [ (square bracket passes through)', () {
      expect(hotkeyDisplayTokens('['), ['[']);
    });

    test('] → ] (square bracket passes through)', () {
      expect(hotkeyDisplayTokens(']'), [']']);
    });

    test('\\\\ → \\\\ (backslash passes through)', () {
      expect(hotkeyDisplayTokens('\\'), ['\\']);
    });

    test('/ → / (literal slash passes through)', () {
      expect(hotkeyDisplayTokens('/'), ['/']);
    });

    test('non-ASCII 1-char token passes through unchanged', () {
      expect(hotkeyDisplayTokens('日'), ['日']);
    });
  });

  group('hotkeyDisplayTokens (multi-char non-mapped tokens)', () {
    test('multi-char non-alphabetic token (e.g. function keys)', () {
      // "F1" is not in the switch and length is 2, so it passes through.
      expect(hotkeyDisplayTokens('F1'), ['f1']);
    });
  });

  group('hotkeyDisplayTokens (whitespace + empty handling)', () {
    test('trims surrounding whitespace', () {
      expect(hotkeyDisplayTokens('  ctrl + a  '), ['Ctrl', 'A']);
    });

    test('drops empty tokens (consecutive "+")', () {
      expect(hotkeyDisplayTokens('ctrl++a'), ['Ctrl', 'A']);
    });

    test(
      'empty binding returns the original string in a single-element list',
      () {
        // After split + filter, parts is empty → returns [binding].
        expect(hotkeyDisplayTokens(''), ['']);
      },
    );
  });

  group('formatHotkeyForDisplay', () {
    test('joins the tokens with "+"', () {
      expect(formatHotkeyForDisplay('ctrl+shift+a'), 'Ctrl+Shift+A');
    });

    test('passes through empty as empty string', () {
      expect(formatHotkeyForDisplay(''), '');
    });

    test('shift+slash special case joins to "?"', () {
      expect(formatHotkeyForDisplay('shift+slash'), '?');
    });
  });
}
