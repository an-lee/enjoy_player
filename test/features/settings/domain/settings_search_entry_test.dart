import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/settings/domain/settings_search_entry.dart';

SettingsSearchEntry _entry({
  required String sectionId,
  String? rowId,
  required String title,
  List<String> keywords = const [],
}) {
  return SettingsSearchEntry(
    descriptor: SettingsEntryDescriptor(sectionId: sectionId, rowId: rowId),
    title: title,
    keywords: keywords,
  );
}

void main() {
  group('filterSettingsEntries', () {
    final entries = [
      _entry(sectionId: 'account', title: 'Account'),
      _entry(
        sectionId: 'appearanceLanguage',
        rowId: 'displayLanguage',
        title: 'Display language',
        keywords: const ['locale', 'translation'],
      ),
      _entry(
        sectionId: 'recording',
        rowId: 'micPicker',
        title: 'Microphone',
        keywords: const ['mic', 'audio input'],
      ),
    ];

    test('empty query returns all entries unfiltered', () {
      expect(filterSettingsEntries('', entries), entries);
      expect(filterSettingsEntries('   ', entries), entries);
    });

    test('matches case-insensitively on title', () {
      final result = filterSettingsEntries('DISPLAY', entries);
      expect(result, hasLength(1));
      expect(result.single.title, 'Display language');
    });

    test('matches case-insensitively on keywords', () {
      final result = filterSettingsEntries('mic', entries);
      expect(result, hasLength(1));
      expect(result.single.title, 'Microphone');
    });

    test('substring match works mid-word', () {
      final result = filterSettingsEntries('lang', entries);
      expect(result.map((e) => e.title), contains('Display language'));
    });

    test('no match returns an empty list', () {
      expect(filterSettingsEntries('nonexistent-xyz', entries), isEmpty);
    });
  });

  group('kSettingsRegistry', () {
    test('includes Transcript section and timelineEnrichment row', () {
      expect(
        kSettingsRegistry.any(
          (d) =>
              d.sectionId == SettingsSectionIds.transcript && d.rowId == null,
        ),
        isTrue,
      );
      expect(
        kSettingsRegistry.any(
          (d) =>
              d.sectionId == SettingsSectionIds.transcript &&
              d.rowId == 'timelineEnrichment',
        ),
        isTrue,
      );
    });
  });
}
