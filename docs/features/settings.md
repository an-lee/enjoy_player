# Feature: Settings

## Summary

The Settings hub is reached at `/settings` and groups every preference surface in one editorial screen. It's **searchable**, renders as a **single-column** list on narrow/mobile widths and a **two-pane** rail + detail layout at/above `EnjoyThemeTokens.breakpointRail` (900px) on desktop, and default-collapses the low-frequency Developer and About sections. It also hosts two **sub-screens** — `/settings/hotkeys` (keyboard shortcuts) and `/settings/sync` (cloud metadata sync status) — and the **About / update** entry.

Section content lives in one file per section under `lib/features/settings/presentation/widgets/sections/`, shared by both the single-column and two-pane layouts (see [Code map](#code-map)). See `specs/004-settings-redesign/` for the redesign spec/plan/tasks that produced this structure.

## Routes

| Path | Purpose |
|------|---------|
| `/settings` | Hub screen |
| `/settings/hotkeys` | Keyboard shortcuts editor (sub-screen) |
| `/settings/sync` | Cloud metadata sync status (sub-screen) |

## Search

`SettingsSearchField` writes to `settingsSearchQueryProvider` (a `@riverpod` string notifier). `filterSettingsEntries(query, entries)` (pure function, `lib/features/settings/domain/settings_search_entry.dart`) matches case-insensitively against each row's title and keywords in the static `SettingsSearchEntry` registry (one entry per section/row — Cloud sync, Appearance & Language ×3, AI providers, Recording, Keyboard shortcuts ×2, Developer ×3, About ×2 — the "Contact the developer" row matches keywords like "email"/"wechat"/"mixin"). Account is no longer in the registry: account management lives on the Profile tab, so the Settings search index is scoped to non-account surfaces.

- A match inside a currently-collapsed section (Developer/About) auto-expands that section so the match is visible.
- A query matching nothing shows a "no results" empty state with a clear affordance that restores the prior collapse state.
- In the two-pane layout, non-matching sections are hidden from the rail and the current selection auto-jumps to the first matching section if it no longer matches.

## Layout

`SettingsScreen` uses a `LayoutBuilder` keyed on `EnjoyThemeTokens.breakpointRail`:

- **Below the breakpoint** → `SettingsLayoutSingleColumn`: every section rendered in reading order via `SettingsSectionCard`/`SettingsCollapsibleSection`, applying default-collapse from `settingsSectionCollapseProvider` (`Map<String, bool>`, seeded `true` only for `developer` and `about`). Horizontal inset comes solely from `EnjoyPageMetrics` (`EnjoyPageKind.hub`) — the same hub gutter Profile uses — so cards align with Profile; section cards and `AboutSectionCard` do **not** add a second horizontal pad.
- **At/above the breakpoint** → `SettingsLayoutTwoPane`: a rail of `SettingsSectionRailItem`s (selected-state highlight matching `AppSidebar`) plus a detail pane rendering the selected section's rows via the *same* `sections/*.dart` widgets. Selection is tracked by `settingsSelectedSectionProvider` (defaults to the first rail entry — `cloudSync` — since Account is no longer in the rail) and survives repeated resizing across the breakpoint. The Account section was moved out of the rail entirely when the Profile tab was introduced; see [Account section](#account-section) below.

Every settings row is a `SettingsRow` (icon, title, subtitle, value badge, optional chevron) — shared by both layouts so a value badge is never clipped in a way that hides the current value, even at narrow widths (a long value wraps below the title instead of disappearing). Capability-gated rows (e.g. native language when the learning language leaves only one native choice) render with `onTap: null` and keep their explanatory subtitle instead of silently omitting the control.

## Sections

- **Cloud sync** (`sections/cloud_sync_section.dart`) — status pill (synced / queued / error) read from the sync queue snapshot; links to `/settings/sync`.
- **Appearance & Language** (`sections/appearance_language_section.dart`) — display, learning, and native language pickers (`language_choice_sheet.dart`). Each pick updates its row's value badge immediately with no need to leave the hub. Native language is capability-gated to the choices that remain after excluding the current learning language.
- **AI providers** (`sections/ai_providers_section.dart`) — per-modality BYOK provider configuration entry point.
- **Recording** (`sections/recording_section.dart`) — microphone picker dialog (auto + every input device returned by `AudioRecorder.listInputDevices()`; see [`echo-mode.md`](echo-mode.md) for the virtual-device skip list). An empty device list still renders an explanatory subtitle rather than a blank row.
- **Keyboard shortcuts** (`sections/keyboard_shortcuts_section.dart`) — link to `/settings/hotkeys` (full editor); desktop-only.
- **Developer** (`sections/developer_section.dart`) — API base URL editors for the **Worker** and the **AI gateway**, plus a link to the AI playground (see [`ai.md`](ai.md)); visible only in debug builds; default-collapsed.
- **About / update** (`sections/about_section.dart`, wrapping `about_section_card.dart`) — gradient About card, a link into the update prompt flow (see [`update.md`](update.md)), and a "Contact the developer" row that opens `developer_contact_sheet.dart`, a bottom sheet listing Email/WeChat/Mixin; tapping any row copies the value to the clipboard and shows an `AppNotice.success` confirmation. Default-collapsed.

## Sub-screens

### `/settings/hotkeys`

Full keyboard shortcut editor. Backed by `HotkeysService` (see [`hotkeys.md`](hotkeys.md)); the screen shows current bindings, surfaces conflicts, and offers a confirmation dialog on save. Restyled to `SettingsRow`/`SettingsSectionCard` for visual consistency with the hub (no change to hotkey domain logic).

### `/settings/sync`

Cloud metadata sync status (see [`sync.md`](sync.md)). Shows the queue, last sync time, per-target progress, and a manual sync button. Read-only; the user cannot change sync configuration from this screen (that's in the [ADR-0010](../decisions/0010-cloud-sync-mvp.md) cloud-sync MVP scope). Restyled to `SettingsRow`/`SettingsSectionCard` for visual consistency (no change to sync domain logic).

## Account section

Account management **no longer lives inside the Settings hub**. The signed-in profile is the dedicated `/profile` shell tab; Settings is reached from inside the Profile tab via a tile. The Settings hub therefore starts at the first post-account section (Cloud sync) and the previous `sections/account_hero_section.dart` widget — a compact identity card (avatar, name, email) or a sign-in prompt, with a shimmer skeleton and a retry affordance on load failure — is no longer wired into either layout. The widget is retained in the source tree because `test/features/settings/presentation/sections/settings_loading_states_test.dart` exercises its signed-in / signed-out / loading / error states in isolation; treat it as a **test-only fixture** until a future surface (e.g. an in-shell "switch account" sheet) reuses it.

Settings still requires a signed-in Enjoy account ([ADR-0031](../decisions/0031-login-only-access.md)) for the sync / AI / appearance surfaces to make sense; unsigned users are redirected to sign-in before reaching this screen, and the Profile tab's sign-out flow returns them there.

### Reach paths

- From the **Profile tab** — `ProfileContent` renders a Settings tile (`Icons.settings_outlined`, `l10n.settingsTitle` / `l10n.settingsSubtitle`) that pushes `/settings`.
- From the **`SidebarAccountChip`** on desktop — the chip subtitle links to `/profile` (the account row itself is the Profile tab entry, not a Settings shortcut).

## Sign-out flow

Confirmation dialog explains cloud-side consequences (per-target recordings will remain on the server, scoped to the account). On confirm: `authCtrlProvider.signOut()` clears the secure token store, closes the per-user SQLite, and routes back to `/sign-in`.

## Accessibility

- `SettingsCollapsibleSection` respects OS reduced-motion: expand/collapse still animates via `AnimatedSize`/`AnimatedRotation`, but with a near-instant (1ms, not a literal zero — see below) duration, and the toggle is always a real tap target rather than depending on the animation to complete.
- Every interactive row (`SettingsRow`) and rail item (`SettingsSectionRailItem`) is keyboard-focusable; `SettingsSectionRailItem` shows an explicit focus ring border when focused and not selected.
- A literal `Duration.zero` on `AnimatedSize` throws a Flutter framework assertion ("`RenderAnimatedSize` was mutated in its own `performLayout`") because the animation controller's listener re-dirties layout mid-pass — use a 1ms duration instead when reduced motion is enabled.

## Code map

| Area | Path |
|------|------|
| Hub screen (search + layout switch) | [`lib/features/settings/presentation/settings_screen.dart`](../../lib/features/settings/presentation/settings_screen.dart) |
| Search field | [`lib/features/settings/presentation/widgets/settings_search_field.dart`](../../lib/features/settings/presentation/widgets/settings_search_field.dart) |
| Single-column layout | [`lib/features/settings/presentation/widgets/settings_layout_single_column.dart`](../../lib/features/settings/presentation/widgets/settings_layout_single_column.dart) |
| Two-pane layout | [`lib/features/settings/presentation/widgets/settings_layout_two_pane.dart`](../../lib/features/settings/presentation/widgets/settings_layout_two_pane.dart) |
| Rail item | [`lib/features/settings/presentation/widgets/settings_section_rail_item.dart`](../../lib/features/settings/presentation/widgets/settings_section_rail_item.dart) |
| Row primitive | [`lib/features/settings/presentation/widgets/settings_row.dart`](../../lib/features/settings/presentation/widgets/settings_row.dart) |
| Collapsible section | [`lib/features/settings/presentation/widgets/settings_collapsible_section.dart`](../../lib/features/settings/presentation/widgets/settings_collapsible_section.dart) |
| Section card | [`lib/features/settings/presentation/widgets/settings_section_card.dart`](../../lib/features/settings/presentation/widgets/settings_section_card.dart) |
| Section content | [`lib/features/settings/presentation/widgets/sections/`](../../lib/features/settings/presentation/widgets/sections/) |
| Profile tab body (replaces the old in-Settings account section) | [`lib/features/auth/presentation/widgets/profile_content.dart`](../../lib/features/auth/presentation/widgets/profile_content.dart) |
| Profile preferences sub-screen | [`lib/features/auth/presentation/profile_preferences_screen.dart`](../../lib/features/auth/presentation/profile_preferences_screen.dart) |
| Account hero widget (test-only — no longer wired into the active UI) | [`lib/features/settings/presentation/widgets/sections/account_hero_section.dart`](../../lib/features/settings/presentation/widgets/sections/account_hero_section.dart) |
| Search registry + filter | [`lib/features/settings/domain/settings_search_entry.dart`](../../lib/features/settings/domain/settings_search_entry.dart) |
| Search/selection/collapse providers | [`lib/features/settings/application/`](../../lib/features/settings/application/) |
| Language picker sheet | [`lib/features/settings/presentation/widgets/language_choice_sheet.dart`](../../lib/features/settings/presentation/widgets/language_choice_sheet.dart) |
| About card | [`lib/features/settings/presentation/widgets/about_section_card.dart`](../../lib/features/settings/presentation/widgets/about_section_card.dart) |
| Developer contact sheet | [`lib/features/settings/presentation/widgets/developer_contact_sheet.dart`](../../lib/features/settings/presentation/widgets/developer_contact_sheet.dart) |
| Hotkeys sub-screen | [`lib/features/settings/presentation/hotkeys_settings_screen.dart`](../../lib/features/settings/presentation/hotkeys_settings_screen.dart) |
| Sync sub-screen | [`lib/features/settings/presentation/sync_status_screen.dart`](../../lib/features/settings/presentation/sync_status_screen.dart) |
| Tests | [`test/features/settings/`](../../test/features/settings/) |

## Related

- Auth: [`docs/features/auth.md`](auth.md)
- Hotkeys: [`docs/features/hotkeys.md`](hotkeys.md)
- Sync: [`docs/features/sync.md`](sync.md)
- App updates: [`docs/features/update.md`](update.md)
- Production diagnostics: [`docs/features/diagnostics.md`](diagnostics.md)
- Redesign spec/plan/tasks: [`specs/004-settings-redesign/`](../../specs/004-settings-redesign/)
