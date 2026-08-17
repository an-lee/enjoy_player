/// Single-column Settings hub layout (below the two-pane breakpoint).
///
/// Assembles every section via [SettingsSectionCard] (always expanded) or
/// [SettingsCollapsibleSection] (Developer/About, default-collapsed),
/// applies the search filter's visible-section rules, and auto-expands a
/// collapsed section that contains a match — see
/// specs/004-settings-redesign/contracts/settings-search.md.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/window/desktop_window.dart';
import 'package:enjoy_player/features/settings/application/settings_registry_localizer.dart';
import 'package:enjoy_player/features/settings/application/settings_search_query_provider.dart';
import 'package:enjoy_player/features/settings/application/settings_section_collapse_provider.dart';
import 'package:enjoy_player/features/settings/domain/settings_search_entry.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/about_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/ai_providers_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/appearance_language_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/cloud_sync_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/developer_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/keyboard_shortcuts_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/recording_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_collapsible_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_no_results.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_section_card.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_section_visuals.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class SettingsLayoutSingleColumn extends ConsumerWidget {
  const SettingsLayoutSingleColumn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final query = ref.watch(settingsSearchQueryProvider);
    final collapseState = ref.watch(settingsSectionCollapseProvider);
    final collapseNotifier = ref.read(settingsSectionCollapseProvider.notifier);

    final visibleIds = filterSettingsEntries(
      query,
      localizedSettingsRegistry(l10n),
    ).map((e) => e.sectionId).toSet();

    final searching = query.trim().isNotEmpty;
    bool effectiveCollapsed(String sectionId) =>
        searching ? false : (collapseState[sectionId] ?? false);
    bool visible(String sectionId) =>
        !searching || visibleIds.contains(sectionId);

    if (searching && visibleIds.isEmpty) {
      return const SettingsNoResults();
    }

    SettingsSectionVisual visual(String sectionId) =>
        settingsSectionVisual(sectionId, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (visible(SettingsSectionIds.cloudSync)) ...[
          SettingsSectionCard(
            title: visual(SettingsSectionIds.cloudSync).title,
            hint: visual(SettingsSectionIds.cloudSync).hint,
            icon: visual(SettingsSectionIds.cloudSync).icon,
            padding: EdgeInsets.zero,
            child: const CloudSyncSectionBody(),
          ),
          SizedBox(height: t.space8),
        ],
        if (visible(SettingsSectionIds.appearanceLanguage)) ...[
          SettingsSectionCard(
            title: visual(SettingsSectionIds.appearanceLanguage).title,
            hint: visual(SettingsSectionIds.appearanceLanguage).hint,
            icon: visual(SettingsSectionIds.appearanceLanguage).icon,
            padding: EdgeInsets.zero,
            child: const AppearanceLanguageSectionBody(),
          ),
          SizedBox(height: t.space8),
        ],
        if (visible(SettingsSectionIds.aiProviders)) ...[
          SettingsSectionCard(
            title: visual(SettingsSectionIds.aiProviders).title,
            hint: visual(SettingsSectionIds.aiProviders).hint,
            icon: visual(SettingsSectionIds.aiProviders).icon,
            padding: EdgeInsets.zero,
            child: const AiProvidersSectionBody(),
          ),
          SizedBox(height: t.space8),
        ],
        if (visible(SettingsSectionIds.recording)) ...[
          SettingsSectionCard(
            title: visual(SettingsSectionIds.recording).title,
            hint: visual(SettingsSectionIds.recording).hint,
            icon: visual(SettingsSectionIds.recording).icon,
            padding: EdgeInsets.zero,
            child: const RecordingSectionBody(),
          ),
          SizedBox(height: t.space8),
        ],
        if (isDesktop && visible(SettingsSectionIds.keyboardShortcuts)) ...[
          SettingsSectionCard(
            title: visual(SettingsSectionIds.keyboardShortcuts).title,
            hint: visual(SettingsSectionIds.keyboardShortcuts).hint,
            icon: visual(SettingsSectionIds.keyboardShortcuts).icon,
            padding: EdgeInsets.zero,
            child: const KeyboardShortcutsSectionBody(),
          ),
          SizedBox(height: t.space8),
        ],
        if (!kReleaseMode && visible(SettingsSectionIds.developer)) ...[
          SettingsCollapsibleSection(
            title: visual(SettingsSectionIds.developer).title,
            hint: visual(SettingsSectionIds.developer).hint,
            icon: visual(SettingsSectionIds.developer).icon,
            collapsed: effectiveCollapsed(SettingsSectionIds.developer),
            onToggle: () =>
                collapseNotifier.toggle(SettingsSectionIds.developer),
            child: const DeveloperSectionBody(),
          ),
          SizedBox(height: t.space8),
        ],
        if (visible(SettingsSectionIds.about)) ...[
          SettingsCollapsibleSection(
            title: visual(SettingsSectionIds.about).title,
            hint: visual(SettingsSectionIds.about).hint,
            icon: visual(SettingsSectionIds.about).icon,
            collapsed: effectiveCollapsed(SettingsSectionIds.about),
            onToggle: () => collapseNotifier.toggle(SettingsSectionIds.about),
            wrapInCard: false,
            child: const AboutSectionBody(),
          ),
        ],
        SizedBox(height: t.space32),
      ],
    );
  }
}
