/// Resolves [kSettingsRegistry] descriptors into localized, searchable
/// [SettingsSearchEntry] values.
///
/// Kept out of `domain/` (which must stay Flutter/l10n-free) but still a
/// pure function of `(descriptor, l10n)` — no `BuildContext` needed beyond
/// the already-resolved [AppLocalizations] instance, so callers just do
/// `localizedSettingsRegistry(AppLocalizations.of(context)!)`.
library;

import 'package:enjoy_player/features/settings/domain/settings_search_entry.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Title + search keywords for one [SettingsEntryDescriptor].
class _Localized {
  const _Localized(this.title, [this.keywords = const []]);
  final String title;
  final List<String> keywords;
}

_Localized _localize(SettingsEntryDescriptor d, AppLocalizations l10n) {
  switch (d.sectionId) {
    case SettingsSectionIds.account:
      return _Localized(l10n.settingsSectionAccount, [
        l10n.settingsSectionAccountHint,
      ]);
    case SettingsSectionIds.cloudSync:
      if (d.rowId == 'syncStatus') {
        return _Localized(l10n.syncSettingsTileTitle);
      }
      return _Localized(l10n.settingsSectionSync, [
        l10n.settingsSectionSyncHint,
      ]);
    case SettingsSectionIds.appearanceLanguage:
      switch (d.rowId) {
        case 'displayLanguage':
          return _Localized(l10n.settingsAppearanceDisplayLanguage);
        case 'learningLanguage':
          return _Localized(l10n.settingsAppearanceLearningLanguage);
        case 'nativeLanguage':
          return _Localized(l10n.settingsAppearanceNativeLanguage);
        default:
          return _Localized(l10n.settingsSectionAppearanceLanguage, [
            l10n.settingsSectionAppearanceLanguageHint,
          ]);
      }
    case SettingsSectionIds.aiProviders:
      if (d.rowId == 'aiProviders') {
        return _Localized(l10n.settingsAiProvidersTileTitle);
      }
      return _Localized(l10n.settingsSectionAi, [l10n.settingsSectionAiHint]);
    case SettingsSectionIds.recording:
      if (d.rowId == 'micPicker') {
        return _Localized(l10n.settingsRecordingMicTitle, const ['mic']);
      }
      return _Localized(l10n.settingsSectionRecording, [
        l10n.settingsSectionRecordingHint,
      ]);
    case SettingsSectionIds.keyboardShortcuts:
      switch (d.rowId) {
        case 'openCheatsheet':
          return _Localized(l10n.settingsKeyboardOpenCheatsheet);
        case 'customize':
          return _Localized(l10n.settingsKeyboardCustomizeTitle);
        default:
          return _Localized(l10n.hotkeysSectionKeyboard, [
            l10n.hotkeysSectionKeyboardHint,
          ]);
      }
    case SettingsSectionIds.developer:
      switch (d.rowId) {
        case 'apiBaseUrl':
          return _Localized(l10n.settingsApiBaseUrl);
        case 'aiApiBaseUrl':
          return _Localized(l10n.settingsAiApiBaseUrl);
        case 'aiPlayground':
          return _Localized(l10n.settingsAiPlaygroundTileTitle);
        default:
          return _Localized(l10n.settingsSectionDeveloper, [
            l10n.settingsSectionDeveloperHint,
          ]);
      }
    case SettingsSectionIds.about:
      if (d.rowId == 'contact') {
        return _Localized(l10n.settingsAboutContactTitle, const [
          'email',
          'wechat',
          'mixin',
          'feedback',
          'bug report',
        ]);
      }
      return _Localized(l10n.settingsSectionAbout, [
        l10n.settingsSectionAboutHint,
      ]);
    default:
      return const _Localized('');
  }
}

/// Builds the full localized, ordered list backing search/rail/collapse.
List<SettingsSearchEntry> localizedSettingsRegistry(AppLocalizations l10n) {
  return [
    for (final d in kSettingsRegistry)
      SettingsSearchEntry(
        descriptor: d,
        title: _localize(d, l10n).title,
        keywords: _localize(d, l10n).keywords,
      ),
  ];
}
