# ADR-0011 — Dark mode only + logo-aligned brand

**Status**: Superseded by [ADR-0083](0083-paper-graphite-light-dark.md)  
**Date**: 2026-05-09

**Supersedes**: [ADR-0008](0008-light-mode-parity.md)

## Context

The product now ships with a single visual identity anchored to the Enjoy logo gradient (blue `#4797F5` → purple `#A855F7` in `assets/logo-light.svg`). Maintaining full light/dark parity increases surface area for contrast bugs and splits brand expression. Users asked for one polished dark theme aligned with the logo.

## Decision

1. **Dark only** — Remove `Brightness.light` `ThemeData`, `darkTheme` / `themeMode` wiring, and persisted `prefs.theme_mode`. The app always uses the dark `ColorScheme` + `ThemeData`.

2. **Brand colors** — Primary seed and accents use a premium purple (`#7B61FF`) to elevate the logo's purple, with the logo's blue as secondary. Surfaces use a neutral zinc-style dark ramp (not warm amber chrome).

3. **Settings** — Remove the System / Light / Dark appearance control; no theme preference is stored.

## Consequences

- ADR-0008 is superseded; light-mode-specific audits and glass tuning for light are no longer in scope.
- Any code assuming `ThemeMode.system` or light `ColorScheme` must use `Theme.of(context).colorScheme` only (always dark).
- Existing DB rows for `prefs.theme_mode` are ignored (harmless orphans until a future cleanup migration if desired).
