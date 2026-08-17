import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/settings/application/settings_section_collapse_provider.dart';
import 'package:enjoy_player/features/settings/domain/settings_search_entry.dart';

void main() {
  group('settingsSectionCollapseProvider', () {
    test('seeds collapsed state from the registry defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(settingsSectionCollapseProvider);

      expect(state[SettingsSectionIds.developer], isTrue);
      expect(state[SettingsSectionIds.about], isTrue);
      expect(state[SettingsSectionIds.cloudSync], isFalse);
      expect(state[SettingsSectionIds.appearanceLanguage], isFalse);
      expect(state.containsKey(SettingsSectionIds.transcript), isFalse);
    });

    test('toggle flips only the targeted section', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(settingsSectionCollapseProvider.notifier);

      notifier.toggle(SettingsSectionIds.developer);

      final state = container.read(settingsSectionCollapseProvider);
      expect(state[SettingsSectionIds.developer], isFalse);
      expect(state[SettingsSectionIds.about], isTrue);
    });

    test('setCollapsed is idempotent and only notifies on change', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(settingsSectionCollapseProvider.notifier);

      var notifications = 0;
      container.listen(
        settingsSectionCollapseProvider,
        (previous, next) => notifications++,
      );

      notifier.setCollapsed(SettingsSectionIds.about, true);
      expect(notifications, 0);

      notifier.setCollapsed(SettingsSectionIds.about, false);
      expect(notifications, 1);
      expect(notifier.isCollapsed(SettingsSectionIds.about), isFalse);
    });
  });
}
