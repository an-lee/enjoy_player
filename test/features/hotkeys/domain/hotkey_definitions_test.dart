// Invariants for the static `hotkey_definitions.dart` lookup tables.
//
// The definitions file is the source of truth for every shortcut the app
// ships, and it feeds the Settings UI, the global keyboard listener, and
// (via `hotkeyDefinitionMap`) per-action lookups. Guarding it with tests
// means:
//   * adding a duplicate `id` or `descriptionKey` triggers a CI failure,
//   * the four `[`, `]`, `{`, `}` cursor-bound defaults remain `useKey: true`
//     (so Settings renders a key-picker rather than text-input),
//   * `hotkeyDefinitionMap` / `hotkeysByScope` stay in sync with the list.
//
// This file deliberately does not test dispatcher behaviour — that lives in
// `hotkey_format_test.dart` and friends.
import 'package:enjoy_player/features/hotkeys/domain/hotkey_definition.dart';
import 'package:enjoy_player/features/hotkeys/domain/hotkey_definitions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hotkey_definitions', () {
    test('every definition has a non-empty id and defaultKeys', () {
      expect(hotkeyDefinitions, isNotEmpty);
      for (final d in hotkeyDefinitions) {
        expect(d.id, isNotEmpty, reason: 'definition has blank id');
        expect(
          d.defaultKeys,
          isNotEmpty,
          reason: '$d.id has blank defaultKeys',
        );
        expect(
          d.descriptionKey,
          isNotEmpty,
          reason: '$d.id has blank descriptionKey',
        );
        expect(
          d.description == null || d.description!.isNotEmpty,
          isTrue,
          reason: '$d.id has blank description override',
        );
      }
    });

    test('ids are unique across the catalogue', () {
      final seen = <String>{};
      for (final d in hotkeyDefinitions) {
        expect(seen.add(d.id), isTrue, reason: 'duplicate id: ${d.id}');
      }
      expect(seen.length, hotkeyDefinitions.length);
    });

    test('descriptionKeys are unique within each scope', () {
      final byScope = <HotkeyScope, List<String>>{};
      for (final d in hotkeyDefinitions) {
        byScope.putIfAbsent(d.scope, () => []).add(d.descriptionKey);
      }
      for (final entry in byScope.entries) {
        final seen = <String>{};
        for (final key in entry.value) {
          expect(
            seen.add(key),
            isTrue,
            reason: 'duplicate descriptionKey "$key" in ${entry.key.name}',
          );
        }
        expect(seen.length, entry.value.length);
      }
    });

    test('the four echo expand/shrink defaults use useKey=true', () {
      const echoKeys = {
        'player.expandEchoBackward',
        'player.expandEchoForward',
        'player.shrinkEchoBackward',
        'player.shrinkEchoForward',
      };
      for (final id in echoKeys) {
        final def = hotkeyDefinitionMap[id];
        expect(def, isNotNull, reason: 'missing definition: $id');
        expect(
          def!.useKey,
          isTrue,
          reason: 'echo defaults must use KeyPicker: $id',
        );
      }
    });

    test('modal.close is non-customizable and bound to escape', () {
      final def = hotkeyDefinitionMap['modal.close'];
      expect(def, isNotNull);
      expect(def!.defaultKeys, 'escape');
      expect(def.customizable, isFalse);
      expect(def.scope, HotkeyScope.modal);
    });

    test('hotkeyDefinitionMap exposes every definition', () {
      expect(hotkeyDefinitionMap.length, hotkeyDefinitions.length);
      for (final d in hotkeyDefinitions) {
        expect(
          hotkeyDefinitionMap[d.id],
          same(d),
          reason: 'hotkeyDefinitionMap missing ${d.id}',
        );
      }
    });

    test('hotkeysByScope returns only that scope and stays in order', () {
      for (final scope in HotkeyScope.values) {
        final picked = hotkeysByScope(scope);
        for (final def in picked) {
          expect(
            def.scope,
            scope,
            reason: '${def.id} does not belong to ${scope.name}',
          );
        }
        // Order within scope mirrors the source list — the Settings list
        // view depends on this order to keep grouping stable.
        final expected = hotkeyDefinitions.where((d) => d.scope == scope);
        expect(picked, equals(expected));
      }
    });

    test('kHotkeysCustomBindingsKey is a non-empty settings kv key', () {
      // The string is consumed by SettingsRepo (JSON map of action id →
      // binding string). Changing it silently migrates user customizations
      // away forever — keep the test around as a tripwire.
      expect(kHotkeysCustomBindingsKey, isNotEmpty);
      expect(kHotkeysCustomBindingsKey, isNot(equals('')));
    });
  });
}
