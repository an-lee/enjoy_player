# ADR-0083 — Paper / graphite dual theme (supersedes ADR-0011)

**Status**: Accepted  
**Date**: 2026-08-24

**Supersedes**: [ADR-0011](0011-dark-mode-only.md)

## Context

ADR-0011 locked the product to a single zinc OLED dark theme (`#09090B`) with no Settings appearance control. The Enjoy Player prototype specifies a warmer **paper** light surface and **graphite** dark ink, fill-versus-ink accents, and a System / Light / Dark appearance preference defaulting to follow the OS.

Maintaining one dark-only identity reduced contrast bugs historically, but it blocked the prototype visual language and users who need a light reading surface for transcripts.

## Decision

1. **Dual palettes** — `buildAppTheme(Brightness)` ships paper (light) and graphite (dark) `ColorScheme`s. Neutrals are warm paper / graphite ink, not zinc OLED. Logo seeds `#4797F5` / `#A855F7` remain **mark-only**.
2. **Fill vs ink** — Deep fills (white label, AA) for filled CTAs; brightness-aware inks for text/icons (violet primary, blue intelligence/lookup, warm Echo). Soft tints use alpha mixes, not extra hex ramps.
3. **Theme mode** — Persist `prefs.theme_mode` as `system` | `light` | `dark`. Default **`system`**. `MaterialApp.themeMode` follows the preference. Settings → Appearance exposes System / Light / Dark.
4. **Chrome** — Glass only on transport + bottom nav. Sidebar is tonal with an inset accent rule. One filled violet CTA per viewport. Video stage / YouTube letterbox stays theme-independent black.
5. **Type** — Newsreader display, Instrument Sans UI, Source Serif 4 + Noto CJK transcript, JetBrains Mono timestamps. Radii `8 / 12 / 16 / 20 / pill`. Artwork dynamic color (ADR-0007) still tints player chrome **on** these neutrals.

## Consequences

- ADR-0011 is superseded; light `ThemeData`, overlay styles, and glass tints are in scope again.
- Unsigned sessions keep the in-memory default (`system`) and do not open a user DB solely to persist theme.
- Feature screens may keep Material outlined icons this pass; shell / transport / settings chrome use the prototype SVG sprite (`EnjoyChromeIcon`).
- Contrast and hover rules: hover darkens **fill**, never fades the label.
