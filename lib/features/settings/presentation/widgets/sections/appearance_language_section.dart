/// Appearance & Language row body — display/learning/native language pickers.
///
/// Extracted 1:1 from `settings_screen.dart`'s inline Appearance & Language
/// `Consumer`; preserves picker behavior and the native-language capability
/// gate (disabled with an explanatory subtitle when only one choice exists).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/presentation/language_labels.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_chrome_icon.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/library/presentation/widgets/content_language_picker.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/language_choice_sheet.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_row.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class AppearanceLanguageSectionBody extends ConsumerWidget {
  const AppearanceLanguageSectionBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(appPreferencesCtrlProvider);
    final auth = ref.watch(authCtrlProvider);
    final signedIn = auth.maybeWhen(
      data: (s) => s is AuthSignedIn,
      orElse: () => false,
    );
    final langSubtitle = signedIn
        ? l10n.settingsLanguageSubtitleSignedIn
        : l10n.settingsLanguageSubtitleDeviceOnly;

    return prefs.when(
      data: (state) {
        final displayLang = localeToBcp47(state.effectiveDisplayLocale);
        final learn = state.effectiveLearningLanguage;
        final native = state.effectiveNativeLanguage;
        final nativeChoices = allowedNativeTags(learn);
        String labelForTag(String tag) => focusLanguageLabel(l10n, tag);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              leading: EnjoyChromeIcon(switch (state.themeMode) {
                ThemeMode.light => EnjoyChromeGlyph.sun,
                ThemeMode.dark => EnjoyChromeGlyph.moon,
                ThemeMode.system => EnjoyChromeGlyph.monitor,
              }),
              title: l10n.settingsAppearanceTheme,
              valueBadge: SettingsValuePill(
                label: _themeModeLabel(l10n, state.themeMode),
              ),
              showChevron: true,
              onTap: () async {
                final picked = await showLanguageChoiceSheet(
                  context: context,
                  title: l10n.settingsAppearanceTheme,
                  options: [
                    LanguageChoiceOption(
                      value: 'system',
                      label: l10n.settingsAppearanceThemeSystem,
                    ),
                    LanguageChoiceOption(
                      value: 'light',
                      label: l10n.settingsAppearanceThemeLight,
                    ),
                    LanguageChoiceOption(
                      value: 'dark',
                      label: l10n.settingsAppearanceThemeDark,
                    ),
                  ],
                  selectedValue: themeModeToStorage(state.themeMode),
                );
                if (picked == null || !context.mounted) return;
                await ref
                    .read(appPreferencesCtrlProvider.notifier)
                    .setThemeMode(themeModeFromStorage(picked));
              },
            ),
            const SettingsRowDivider(),
            SettingsRow(
              leadingIcon: Icons.language_rounded,
              title: l10n.settingsAppearanceDisplayLanguage,
              subtitle: langSubtitle,
              valueBadge: SettingsValuePill(label: labelForTag(displayLang)),
              showChevron: true,
              onTap: () async {
                final opts = <LanguageChoiceOption>[
                  for (final loc in kAppDisplayLocales)
                    LanguageChoiceOption(
                      value: localeToBcp47(loc),
                      label: labelForTag(localeToBcp47(loc)),
                    ),
                ];
                final picked = await showLanguageChoiceSheet(
                  context: context,
                  title: l10n.settingsLanguagePickerTitleDisplay,
                  options: opts,
                  selectedValue: displayLang,
                );
                if (picked == null || !context.mounted) {
                  return;
                }
                await ref
                    .read(appPreferencesCtrlProvider.notifier)
                    .setLocale(displayLocaleFromRawOrDefault(picked));
              },
            ),
            const SettingsRowDivider(),
            SettingsRow(
              leadingIcon: Icons.translate_rounded,
              title: l10n.settingsAppearanceLearningLanguage,
              subtitle: l10n.settingsLearningLanguageSubtitle,
              valueBadge: SettingsValuePill(label: labelForTag(learn)),
              showChevron: true,
              onTap: () async {
                final picked = await showFocusLanguagePicker(
                  context: context,
                  selectedValue: learn,
                );
                if (picked == null || !context.mounted) return;
                await ref
                    .read(appPreferencesCtrlProvider.notifier)
                    .setLearningLanguage(picked);
              },
            ),
            const SettingsRowDivider(),
            SettingsRow(
              leadingIcon: Icons.record_voice_over_outlined,
              title: l10n.settingsAppearanceNativeLanguage,
              subtitle: langSubtitle,
              valueBadge: SettingsValuePill(label: labelForTag(native)),
              showChevron: nativeChoices.length > 1,
              onTap: nativeChoices.length > 1
                  ? () async {
                      final opts = <LanguageChoiceOption>[
                        for (final tag in nativeChoices)
                          LanguageChoiceOption(
                            value: tag,
                            label: labelForTag(tag),
                          ),
                      ];
                      final picked = await showLanguageChoiceSheet(
                        context: context,
                        title: l10n.settingsLanguagePickerTitleNative,
                        options: opts,
                        selectedValue: native,
                      );
                      if (picked == null || !context.mounted) {
                        return;
                      }
                      await ref
                          .read(appPreferencesCtrlProvider.notifier)
                          .setNativeLanguage(picked);
                    }
                  : null,
            ),
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Skeleton.line(width: double.infinity, height: 18),
            const SizedBox(height: 16),
            Skeleton.line(width: 220, height: 14),
            const SizedBox(height: 12),
            Skeleton.line(width: 180, height: 14),
          ],
        ),
      ),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}

String _themeModeLabel(AppLocalizations l10n, ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return l10n.settingsAppearanceThemeLight;
    case ThemeMode.dark:
      return l10n.settingsAppearanceThemeDark;
    case ThemeMode.system:
      return l10n.settingsAppearanceThemeSystem;
  }
}
