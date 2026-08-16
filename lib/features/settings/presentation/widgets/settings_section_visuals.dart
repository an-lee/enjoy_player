/// Icon + localized title/hint for each top-level Settings section.
///
/// Single place shared by [SettingsLayoutSingleColumn] and
/// [SettingsLayoutTwoPane] so the rail, the single-column headers, and the
/// two-pane detail pane header never drift out of sync.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/features/settings/domain/settings_search_entry.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class SettingsSectionVisual {
  const SettingsSectionVisual({
    required this.icon,
    required this.title,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String hint;
}

SettingsSectionVisual settingsSectionVisual(
  String sectionId,
  AppLocalizations l10n,
) {
  switch (sectionId) {
    case SettingsSectionIds.account:
      return SettingsSectionVisual(
        icon: Icons.person_outline_rounded,
        title: l10n.settingsSectionAccount,
        hint: l10n.settingsSectionAccountHint,
      );
    case SettingsSectionIds.cloudSync:
      return SettingsSectionVisual(
        icon: Icons.cloud_sync_outlined,
        title: l10n.settingsSectionSync,
        hint: l10n.settingsSectionSyncHint,
      );
    case SettingsSectionIds.appearanceLanguage:
      return SettingsSectionVisual(
        icon: Icons.palette_outlined,
        title: l10n.settingsSectionAppearanceLanguage,
        hint: l10n.settingsSectionAppearanceLanguageHint,
      );
    case SettingsSectionIds.aiProviders:
      return SettingsSectionVisual(
        icon: Icons.auto_awesome_outlined,
        title: l10n.settingsSectionAi,
        hint: l10n.settingsSectionAiHint,
      );
    case SettingsSectionIds.recording:
      return SettingsSectionVisual(
        icon: Icons.mic_none_rounded,
        title: l10n.settingsSectionRecording,
        hint: l10n.settingsSectionRecordingHint,
      );
    case SettingsSectionIds.transcript:
      return SettingsSectionVisual(
        icon: Icons.subtitles_outlined,
        title: l10n.settingsSectionTranscript,
        hint: l10n.settingsSectionTranscriptHint,
      );
    case SettingsSectionIds.keyboardShortcuts:
      return SettingsSectionVisual(
        icon: Icons.keyboard_outlined,
        title: l10n.hotkeysSectionKeyboard,
        hint: l10n.hotkeysSectionKeyboardHint,
      );
    case SettingsSectionIds.developer:
      return SettingsSectionVisual(
        icon: Icons.developer_mode_outlined,
        title: l10n.settingsSectionDeveloper,
        hint: l10n.settingsSectionDeveloperHint,
      );
    case SettingsSectionIds.about:
      return SettingsSectionVisual(
        icon: Icons.info_outline_rounded,
        title: l10n.settingsSectionAbout,
        hint: l10n.settingsSectionAboutHint,
      );
    default:
      return SettingsSectionVisual(
        icon: Icons.settings_outlined,
        title: sectionId,
        hint: '',
      );
  }
}
