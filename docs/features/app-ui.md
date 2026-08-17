# App UI — Cinematic Editorial Design System

**Status**: Implemented (Phase 1-6 complete, 2026-05-09; premium foundation pass 2026-05-13)

## Design direction

**Style**: Cinematic Editorial — confident hero typography, generous whitespace, ambient artwork-derived color, selective glass only on the floating transport bar.

**Color**:
- **Neutrals** — zinc-style dark ramp only: base `#09090B`, containers through `#3F3F46` (see `AppColors` in `lib/core/theme/colors.dart`).
- **Brand** — premium purple `#7B61FF` (primary) elevating the logo gradient, with logo blue `#4797F5` (secondary) (Material `ColorScheme` roles).
- **Dynamic accent** — extracted per-media via `palette_generator`; applied to now-playing ring glow, transcript active-line rail, and ambient backdrop tint.
- **Echo accent** — `#E65100` orange kept for brand recognition, only on echo-mode affordances.

### Typography

**Typography**:
- Display / UI: **Inter** (Google Fonts), `w600` tight-tracked for hero titles.
- Transcript body: **Source Serif 4** (Google Fonts), default ON, toggleable.
- Transcript **secondary** (translation) track: **Noto Sans SC** (Google Fonts), upright (no italic), `w400` at 14pt serif / 13.5pt sans-serif reading mode.
- **CJK fallbacks**: transcript styles layer Noto **Serif** (KR / SC / JP) on the body when serif reading is on, and Noto **Sans** (KR / SC / JP) + Inter on the secondary track and UI. The fallbacks are appended via `fontFamilyFallback` so Windows stops substituting low-quality system CJK fonts for Chinese / Japanese / Korean text.
- Tabular figures everywhere on timestamps and durations via `FontFeature.tabularFigures()`.
- Type scale: `12 / 13 / 14 / 16 / 18 / 22 / 28 / 36 / 48`.

**Effects**:
- Glass: **transport bar only** (`GlassSurface`). Sidebar is flat tonal; content cards are flat.
- Elevation scale: `0 / 1 / 3 / 8` (cards / sheets / modals).
- Radius scale: `8 / 12 / 16 / 20 / ∞`. `20` is the new default for cards and hero artwork.
- Ambient backdrop: very-low-opacity (~7%) radial tint from artwork dominant color behind player content.
- Motion: 180ms fast, **220ms medium** (transport layout morphs), 260ms standard, 240ms enter, 160ms exit. `prefers-reduced-motion` respected via `MediaQuery.disableAnimations`.
- Global theme polish: tuned `splashColor` / `highlightColor` / `hoverColor` / `focusColor`, `scrollbarTheme`, `dialogTheme.insetPadding`, `NavigationBarTheme` height aligned to token (for any residual Material nav).
- Shared interaction kit: `EnjoyTappable*`, `Haptics`, `EnjoyButton` — see [ADR-0018](../decisions/0018-shared-interactive-primitives.md).

## Theme mode

Single dark `ThemeData` only (`buildAppTheme()`). No light theme and no Settings theme toggle. See [ADR-0011](../decisions/0011-dark-mode-only.md).

## Navigation

- **Mobile**: custom `EnjoyBottomNav` (68pt content height + system home-indicator inset via `SafeArea`). **Four** destinations: Home, Discover, Library, **Profile** (the signed-in profile tab — see [auth.md](auth.md) for the dedicated profile screen; Settings is reached from a tile inside the Profile tab, not as a top-level destination). Pill selection, editorial typography, keyboard focus ring on items; haptics on change. Implemented in `lib/core/theme/widgets/enjoy_bottom_nav.dart`, used from `RootShell`.
- **Library source switch**: Inside `LibraryScreen`, a compact **Local / Cloud** badge with swap icon sits inline beside the Library title; tap toggles source. Cloud mode uses `/library?source=cloud`; legacy `/cloud` redirects. Import + compact search on Local; Refresh on Cloud.
- **Desktop (≥ 900 px)**: `AppSidebar` — flat tonal panel (`surfaceContainerLow`), hairline right border, pill nav items with hover/splash/focus, `FocusTraversalGroup` for keyboard order; extra top breathing room on **macOS** desktop for traffic-light clearance. **Three** primary pills: Home, Discover, Library. Profile is reached via the bottom **`SidebarAccountChip`** (not a fourth nav pill). Library nav item covers both local and cloud sources (no separate Cloud row). The Settings hub is reached from inside the Profile tab (a tile that pushes `/settings`), not from the sidebar.
- **No glass on sidebar**: `EnjoyThemeTokens.useGlassOnSidebar = false`.
- Platform-adaptive transitions: Cupertino on iOS/macOS, ZoomPage on Android, FadeUpwards on Windows/Linux.

## Page layout

Adaptive page families ([ADR-0055](../decisions/0055-adaptive-page-layout-system.md)):

| Kind | Width | Chrome | Examples |
|------|-------|--------|----------|
| `browse` | Full pane + `pageGutter` (16 / 24) | `EditorialHeader` (gutter-aligned) | Home, Discover, Library, channel feed |
| `hub` | Centered `hubMaxWidth` (840) | Editorial or `EnjoySubpageAppBar` | Profile, Settings, Subscription, Credits, Hotkeys, AI providers, Vocabulary |
| `form` | Centered `formMaxWidth` (680) | `EnjoySubpageAppBar` | Preferences, Edit Profile |
| `auth` | Centered `modalMaxWidth` (400) | Auth scaffold | Sign-in |
| `playerChrome` | Player-owned | Player chrome | Expanded player |

Use `EnjoyPage` + `EnjoyPageMetrics` (or `pageGutterOf`) — never invent per-screen max widths or stretch form Save buttons to the full desktop pane.

## System chrome

- **Mobile**: `MaterialApp.router` builder wraps content in `AnnotatedRegion<SystemUiOverlayStyle>` — transparent status bar, light status/nav icons, dark system navigation bar (`#09090B`).
- **Desktop**: `window_manager.setMinimumSize(880×560)` after init (Windows / macOS / Linux) for a usable minimum layout.

## Screen registry

| Screen | Key change |
|--------|-----------|
| `SignInScreen` | Editorial centered hero; no glass card |
| `HomeScreen` | `EditorialHeader` + media grid via `MediaCardTile` |
| `LibraryScreen` | `EditorialHeader` + `SegmentedButton` + `MediaCardRow` / `MediaCardTile` |
| `ExpandedPlayerScreen` | `PlayerAmbientBackdrop` around scaffold; video: no AppBar (stage overlay); audio: no AppBar — collapse chevron in `AudioPlayerLayout` ([ADR-0077](../decisions/0077-audio-reserved-collapse-chrome.md)) |
| `AudioPlayerLayout` | Compact top-left collapse chevron + transcript-first body (`contentMaxWidth`); no HeroArtwork stage |
| `VideoPlayerLayout` | Side-by-side when layout is landscape (`width > height`); stacked 16:9 video over transcript in portrait/square ([ADR-0059](../decisions/0059-phone-tablet-orientation-and-player-aspect-layout.md)). Split: draggable transcript column (**≥360** px min, max 50% width), persisted `splitPx` preference, dark zinc panel, 1px left border; top **SafeArea** on video when expanded chrome hides the app bar. Transport packing still uses `breakpointTranscriptSideBySide` (720). |
| `GlobalTransportBar` | Glass kept; dynamic-accent play ring; tabular timestamps; narrow ≤720px: prev/next always when transcript loaded (replay via line tap) |
| `TranscriptPanel` | Source Serif 4 body; editorial left-rail active line; neutral echo card with 8px orange rail |
| `ShadowReadingPanel` | Idle: three-zone bar (pitch icon, centered 44pt FAB / 56pt hit, play + more; delete in menu); recording: centered FAB + countdown |
| `SettingsScreen` | iOS-style grouped `_SettingsCard`; **Appearance & Language** rows open pickers for display + native language (learning fixed en-US); guest vs signed-in copy for language sync |
| `ProfileScreen` | Editorial profile hub; 4th mobile bottom-nav tab; desktop entry via `SidebarAccountChip`; tier chip mirrors `UserProfile.subscriptionTier`; chrome-free body uses hub max width; hosts hero card, practice stats, credits/subscription nav, unlabeled Vocabulary (due-count pill) + config (**Edit profile** + Preferences + Settings) section cards, and sign out. The **Edit profile** tile pushes `/profile/edit` (`ProfileEditScreen`) for username + avatar (read-only Enjoy ID / email / Mixin ID). The **Preferences** tile pushes `/profile/preferences` (`ProfilePreferencesScreen`) for daily goal and display / learning / native language. Tapping the hero card also opens Edit profile. Preferences / Edit Profile are `form` pages at `formMaxWidth`. See [auth.md](auth.md#profile). |
| `NotFoundScreen` | `errorBuilder` fallback at the router root for unknown `go_router` locations; localized en / zh / zh-CN, shows the attempted URI, single primary "Back to Home" action to `/` |

## Design token reference (`EnjoyThemeTokens`)

```
Spacing:  4 / 8 / 12 / 16 / 20 / 24 / 32 / 40
Radii:    8 / 12 / 16 / 20 / 999
Elevation: 0 / 1 / 3 / 8
Motion:   180ms fast / 260ms standard / 240ms enter / 160ms exit
Sidebar:  248px wide, useGlassOnSidebar: false
Transport: 88px height
ContentMaxWidth: 720px (reading column / empty states)
FormMaxWidth: 680px
HubMaxWidth: 840px
PageGutter: 24px (default) / PageGutterCompact: 16px (< breakpointCompact 600)
BreakpointRail: 900px
BreakpointCompact: 600px
BottomNav: 68px content height (+ safe area)
DesktopGutter: 24px (alias rhythm; prefer pageGutter)
Modal max: 400px (alerts / auth) / 560px (wide pickers)
Focus ring: 2px (custom nav / sidebars)
```

## Widgets reference

| Widget | File | Purpose |
|--------|------|---------|
| `AppBackground` | `core/theme/widgets/app_background.dart` | Dark gradient scaffold BG |
| `PlayerAmbientBackdrop` | same | Artwork color tint overlay (player only) |
| `EnjoyPage` / `EnjoyPageKind` | `core/theme/widgets/enjoy_page.dart`, `core/layout/enjoy_page_kind.dart` | Adaptive page scaffold + width metrics |
| `EnjoySubpageAppBar` | `core/theme/widgets/enjoy_subpage_app_bar.dart` | Push-route back + title chrome |
| `EditorialHeader` | `core/theme/widgets/editorial_header.dart` | Large title + subtitle + trailing; gutter or column width mode; optional `compact` |
| `EnjoyBottomNav` | `core/theme/widgets/enjoy_bottom_nav.dart` | Mobile shell bottom navigation (replaces stock `NavigationBar`) |
| `showEnjoySheet` / `showEnjoyAlertDialog` / `showEnjoyDialog` | `core/theme/widgets/enjoy_modal.dart` | Shared modal scrim + sheet shape; alert content max width |
| `MediaCardTile` | `core/theme/widgets/media_card.dart` (barrel → `media_card/`) | Grid tile (video/home) |
| `MediaCardRow` | `core/theme/widgets/media_card.dart` (barrel → `media_card/`) | List row (audio) |
| `HeroArtwork` | `core/theme/widgets/hero_artwork.dart` | Artwork + rim light + shadow |
| `EmptyState` | `core/theme/widgets/empty_state.dart` | Editorial empty state |
| `GlassSurface` | `core/theme/widgets/glass_surface.dart` | **Transport bar only** |
| `Skeleton` (+ `.box` / `.line` / `.circle`) | `core/theme/widgets/skeleton.dart` | Single shimmer placeholder primitive; see [skeleton-loading.md](skeleton-loading.md) |
| `SkeletonAppBootstrap` | same | Full-viewport app-bootstrap loading shell |
| `SkeletonMediaList` / `SkeletonMediaGrid` | same | Library / Home tab body loading states (sliver-safe) |
| `SkeletonSettingsList` | same | Settings hub loading state (sliver-safe) |
| `SkeletonTranscript` | same | Transcript panel loading state (own `ScrollView`) |
| `SkeletonProfile` | same | Profile screen loading state |
| `LoadingIcon` | `core/presentation/loading_icon.dart` | Compact 18×18 `CircularProgressIndicator` placeholder for inline busy affordances (buttons, list rows, chips); replaces 30+ ad-hoc `SizedBox` + `CircularProgressIndicator` pairs across 20 files. Configure via `size`, `strokeWidth`, `color`. |
| `SectionLabel` | `core/presentation/section_label.dart` | Header row for in-card sections (`Icon` + `space8` + bold `labelLarge` text). Centralizes the heading style used by BYOK forms and other settings surfaces. |
| `NavItemPill` | `core/theme/widgets/nav_item_pill.dart` | Pill-shaped nav item: icon + label inside a focus-ringable, hover-able, selected-tinted container. Shared by `AppSidebar`'s desktop nav row and the Settings two-pane rail. Per [ADR-0018](../decisions/0018-shared-interactive-primitives.md) — prefer this over ad-hoc `InkWell` + `GestureDetector` islands for new rail-style navigation surfaces. Supports `selectedIcon` fallback, configurable `iconSize`, and `maxLines`/`overflow` for label ellipsis. |
| `AppSidebar` | `features/player/presentation/widgets/app_sidebar.dart` | Flat tonal sidebar |
| `SidebarAccountChip` | `features/auth/presentation/widgets/sidebar_account_chip.dart` | Account row at the bottom of `AppSidebar`: signed-out → **Sign in** → `/sign-in`; awaiting OTP → progress + resume → `/sign-in` or `/sign-in/email`; signed-in → avatar + name + Pro badge + **Open profile** subtitle → `/profile`; Free users also get an inline **Upgrade** pill that routes to `/subscription` |

## Dynamic color module

`lib/core/theme/dynamic_color/`
- `artwork_palette.dart` — `extractArtworkPalette(path)` extracts an `ArtworkPalette { dominant, accent, onAccent, vibrant }` from a local thumbnail via `palette_generator`. Results are held in a process-wide **LRU cache** (cap = 32) keyed by `(path, size, mtime)`; lookups re-`stat` the file and evict any prior entry for the same path whose `(size, mtime)` no longer matches the live stat, so re-thumbnailing or rewriting the file in place correctly invalidates the cache. `ArtworkPalette` has value-equality on its four `Color` fields. `@visibleForTesting` seams (`debugResetArtworkPaletteCache`, `debugArtworkPaletteCacheSize`, `debugArtworkPaletteCacheContainsPath`, `debugLookupArtworkPalette`, `debugPutArtworkPalette`) are the only supported access path for tests.
- `dynamic_color_provider.dart` — Riverpod providers: `currentArtworkPaletteProvider` (active player, watches `playerControllerProvider`'s `thumbnailUrl`), `artworkPaletteProvider(path)` (per-path family).

See ADR-0007 for rationale.

## ADRs

- [ADR-0007](../decisions/0007-dynamic-color-from-artwork.md) — Dynamic color from artwork
- [ADR-0008](../decisions/0008-light-mode-parity.md) — Light mode parity (superseded by 0011)
- [ADR-0009](../decisions/0009-platform-adaptive-shell.md) — Platform-adaptive shell
- [ADR-0011](../decisions/0011-dark-mode-only.md) — Dark mode only + logo-aligned brand
- [ADR-0055](../decisions/0055-adaptive-page-layout-system.md) — Adaptive page layout system
