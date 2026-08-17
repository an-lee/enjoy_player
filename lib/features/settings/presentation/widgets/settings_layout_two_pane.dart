/// Two-pane Settings desktop layout (at/above the rail breakpoint).
///
/// Rail of [SettingsSectionRailItem]s + a detail pane rendering the selected
/// section's rows via the same `sections/*.dart` widgets used by
/// [SettingsLayoutSingleColumn]. Reads/writes
/// [settingsSelectedSectionProvider] so the selection survives a breakpoint
/// resize. Applies the same search-filtered visibility rules as the
/// single-column layout to the rail — see
/// specs/004-settings-redesign/contracts/settings-search.md §3.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/window/desktop_window.dart';
import 'package:enjoy_player/features/settings/application/settings_registry_localizer.dart';
import 'package:enjoy_player/features/settings/application/settings_search_query_provider.dart';
import 'package:enjoy_player/features/settings/application/settings_selected_section_provider.dart';
import 'package:enjoy_player/features/settings/domain/settings_search_entry.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/about_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/ai_providers_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/appearance_language_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/cloud_sync_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/developer_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/keyboard_shortcuts_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/recording_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_no_results.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_section_card.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_section_rail_item.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_section_visuals.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Ordered rail entries, gated by platform/build the same way the
/// single-column layout gates its sections (FR-005/FR-006).
List<String> _railSectionIds() {
  return [
    SettingsSectionIds.cloudSync,
    SettingsSectionIds.appearanceLanguage,
    SettingsSectionIds.aiProviders,
    SettingsSectionIds.recording,
    if (isDesktop) SettingsSectionIds.keyboardShortcuts,
    if (!kReleaseMode) SettingsSectionIds.developer,
    SettingsSectionIds.about,
  ];
}

Widget _sectionBody(String sectionId) {
  switch (sectionId) {
    case SettingsSectionIds.cloudSync:
      return const CloudSyncSectionBody();
    case SettingsSectionIds.appearanceLanguage:
      return const AppearanceLanguageSectionBody();
    case SettingsSectionIds.aiProviders:
      return const AiProvidersSectionBody();
    case SettingsSectionIds.recording:
      return const RecordingSectionBody();
    case SettingsSectionIds.keyboardShortcuts:
      return const KeyboardShortcutsSectionBody();
    case SettingsSectionIds.developer:
      return const DeveloperSectionBody();
    case SettingsSectionIds.about:
      return const AboutSectionBody();
    default:
      return const SizedBox.shrink();
  }
}

class SettingsLayoutTwoPane extends ConsumerWidget {
  const SettingsLayoutTwoPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final query = ref.watch(settingsSearchQueryProvider);
    final selected = ref.watch(settingsSelectedSectionProvider);

    final visibleIds = filterSettingsEntries(
      query,
      localizedSettingsRegistry(l10n),
    ).map((e) => e.sectionId).toSet();

    final searching = query.trim().isNotEmpty;
    final allRailIds = _railSectionIds();
    final railIds = searching
        ? allRailIds.where(visibleIds.contains).toList(growable: false)
        : allRailIds;

    if (railIds.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: t.space8),
          child: const SettingsNoResults(),
        ),
      );
    }

    final effectiveSelected = railIds.contains(selected)
        ? selected
        : railIds.first;
    if (effectiveSelected != selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(settingsSelectedSectionProvider.notifier)
            .select(effectiveSelected);
      });
    }

    final visual = settingsSectionVisual(effectiveSelected, l10n);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: t.sidebarWidth,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(top: t.space8, bottom: t.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final id in railIds)
                  SettingsSectionRailItem(
                    icon: settingsSectionVisual(id, l10n).icon,
                    label: settingsSectionVisual(id, l10n).title,
                    selected: id == effectiveSelected,
                    onTap: () => ref
                        .read(settingsSelectedSectionProvider.notifier)
                        .select(id),
                  ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: cs.outlineVariant.withValues(alpha: 0.18)),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              t.pageGutter,
              0,
              t.pageGutter,
              t.space32,
            ),
            child: _DetailPane(sectionId: effectiveSelected, visual: visual),
          ),
        ),
      ],
    );
  }
}

/// Renders the selected section's content in the two-pane detail pane.
/// Account and About supply their own bordered surface, so they skip the
/// shared [SettingsSectionCard] wrapper to avoid a card-inside-a-card look.
class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.sectionId, required this.visual});

  final String sectionId;
  final SettingsSectionVisual visual;

  @override
  Widget build(BuildContext context) {
    if (sectionId == SettingsSectionIds.about) {
      return _sectionBody(sectionId);
    }
    return SettingsSectionCard(
      title: visual.title,
      hint: visual.hint,
      icon: visual.icon,
      padding: EdgeInsets.zero,
      child: _sectionBody(sectionId),
    );
  }
}
