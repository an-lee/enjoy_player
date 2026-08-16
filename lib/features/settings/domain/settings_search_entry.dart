/// Discoverable Settings entries — section registry, search matching.
///
/// Pure/UI-free: this file backs the search index, the two-pane rail, and
/// the single-column default-collapse state (see
/// specs/004-settings-redesign/contracts/settings-section-registry.md and
/// contracts/settings-search.md). Localized titles/keywords are resolved
/// separately in the application layer (`settings_registry_localizer.dart`)
/// so this file has no Flutter dependency and stays trivially unit-testable.
library;

/// Stable section identifiers, in Settings hub display order.
abstract final class SettingsSectionIds {
  static const account = 'account';
  static const cloudSync = 'cloudSync';
  static const appearanceLanguage = 'appearanceLanguage';
  static const aiProviders = 'aiProviders';
  static const recording = 'recording';
  static const transcript = 'transcript';
  static const keyboardShortcuts = 'keyboardShortcuts';
  static const developer = 'developer';
  static const about = 'about';
}

/// Identity of one section header or row, before localization.
class SettingsEntryDescriptor {
  const SettingsEntryDescriptor({
    required this.sectionId,
    this.rowId,
    this.collapsedByDefault = false,
  });

  /// Which section this belongs to (also the rail item id for a header).
  final String sectionId;

  /// `null` for the section header itself; otherwise a stable per-section id.
  final String? rowId;

  /// Whether the *section* starts collapsed in the single-column layout.
  /// Only meaningful on the header descriptor (`rowId == null`).
  final bool collapsedByDefault;

  bool get isSectionHeader => rowId == null;
}

/// A localized, searchable entry — one per [SettingsEntryDescriptor].
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.descriptor,
    required this.title,
    this.keywords = const [],
  });

  final SettingsEntryDescriptor descriptor;

  /// Resolved display title used both for rendering and for matching.
  final String title;

  /// Extra localized synonyms matched by search but not displayed
  /// (e.g. "mic" for the Recording row).
  final List<String> keywords;

  String get sectionId => descriptor.sectionId;
  String? get rowId => descriptor.rowId;
  bool get isSectionHeader => descriptor.isSectionHeader;
}

/// Case-insensitive substring match of [query] against each entry's title
/// and keywords. A blank [query] returns [entries] unfiltered — see
/// contracts/settings-search.md §1.
List<SettingsSearchEntry> filterSettingsEntries(
  String query,
  List<SettingsSearchEntry> entries,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return entries;
  return entries
      .where((e) {
        if (e.title.toLowerCase().contains(q)) return true;
        for (final k in e.keywords) {
          if (k.toLowerCase().contains(q)) return true;
        }
        return false;
      })
      .toList(growable: false);
}

/// The single source of truth for what's discoverable in Settings. The
/// two-pane rail, single-column ordering, default-collapse state, and
/// search index all derive from this list — see
/// specs/004-settings-redesign/contracts/settings-section-registry.md.
///
/// Keyboard shortcuts and Developer rows are included unconditionally here;
/// [SettingsSectionIds.keyboardShortcuts] is hidden on non-desktop platforms
/// and [SettingsSectionIds.developer] is hidden on release builds by the
/// presentation layer (FR-005/FR-006), not by this registry.
const List<SettingsEntryDescriptor> kSettingsRegistry = [
  SettingsEntryDescriptor(sectionId: SettingsSectionIds.cloudSync),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.cloudSync,
    rowId: 'syncStatus',
  ),
  SettingsEntryDescriptor(sectionId: SettingsSectionIds.appearanceLanguage),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.appearanceLanguage,
    rowId: 'displayLanguage',
  ),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.appearanceLanguage,
    rowId: 'learningLanguage',
  ),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.appearanceLanguage,
    rowId: 'nativeLanguage',
  ),
  SettingsEntryDescriptor(sectionId: SettingsSectionIds.aiProviders),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.aiProviders,
    rowId: 'aiProviders',
  ),
  SettingsEntryDescriptor(sectionId: SettingsSectionIds.recording),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.recording,
    rowId: 'micPicker',
  ),
  SettingsEntryDescriptor(sectionId: SettingsSectionIds.transcript),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.transcript,
    rowId: 'timelineEnrichment',
  ),
  SettingsEntryDescriptor(sectionId: SettingsSectionIds.keyboardShortcuts),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.keyboardShortcuts,
    rowId: 'openCheatsheet',
  ),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.keyboardShortcuts,
    rowId: 'customize',
  ),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.developer,
    collapsedByDefault: true,
  ),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.developer,
    rowId: 'apiBaseUrl',
  ),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.developer,
    rowId: 'aiApiBaseUrl',
  ),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.developer,
    rowId: 'aiPlayground',
  ),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.about,
    collapsedByDefault: true,
  ),
  SettingsEntryDescriptor(
    sectionId: SettingsSectionIds.about,
    rowId: 'contact',
  ),
];
