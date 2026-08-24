# Feature: Skeleton loading

The app's loading placeholders all come from a single module:
[`lib/core/theme/widgets/skeleton.dart`](../../lib/core/theme/widgets/skeleton.dart).
A `Skeleton` paints a tinted, shimmering shape that respects the OS reduced-motion
setting and reads its colors from the active `ThemeData.colorScheme`.

This page is the canonical reference for new placeholders and for fixing layout
crashes when a placeholder is dropped into a sliver parent.

## The `Skeleton` widget

```dart
const Skeleton({
  required double width,
  required double height,
  BorderRadius? borderRadius,
});

Skeleton.box({required double width, required double height, BorderRadius? borderRadius})
Skeleton.line({required double width, double height = 14, BorderRadius? borderRadius})
Skeleton.circle({required double diameter})
```

- `.box` is a square-ish fillable rectangle (defaults to a zero radius).
- `.line` is a short row of text-like fill (defaults to `radius 6`, height `14`).
- `.circle` derives both dimensions from `diameter` and rounds to a half-radius.
- When `borderRadius` is omitted, the constructor falls back to a pill if the
  shape is square (`width == height`) and to `radius 8` otherwise. Pre-built
  placeholder widgets below use these defaults intentionally — match them in new
  placeholders so the visual language stays consistent.

### Reduced motion

`Skeleton` reads `MediaQuery.disableAnimationsOf(context)` in both
`initState` (via post-frame) and `didChangeDependencies`. With reduced motion on,
the animation never starts; the widget renders a flat tinted rectangle in the
shape's color and the shimmer painter is bypassed entirely. Don't
re-implement motion handling around `Skeleton` — the widget already does it.

### Colors

`Skeleton` reads from `Theme.of(context).colorScheme`:

- Base → `surfaceContainerHighest` at `alpha 0.55`.
- Highlight → `surfaceContainerHigh` at `alpha 0.95`.

Both colors are theme-derived, so paper/graphite theme changes ([ADR-0083](../decisions/0083-paper-graphite-light-dark.md))
flow through automatically. New placeholders should not introduce their own
colors.

## Pre-built placeholders

Each placeholder is a `StatelessWidget` that composes `Skeleton.line` / `.box` /
`.circle` with `EnjoyThemeTokens` spacing. Reuse these first; only build a new
placeholder when a feature has a layout that none of these cover.

| Widget | Use when | Underlying structure |
|--------|----------|----------------------|
| `SkeletonAppBootstrap` | Full-viewport app bootstrap (no router yet). | `Center` + `Column` (circle + two lines). |
| `SkeletonMediaList` | Library / Home tab body while Drift streams are pending. | `Padding` + `Column` of `itemCount` (default `8`) audio-row placeholders. |
| `SkeletonMediaGrid` | Library / Home grid tab body while Drift streams are pending. | `GridView.builder` with `shrinkWrap: true`, `NeverScrollableScrollPhysics()`, `crossAxisCount: 2`, `childAspectRatio: 0.72`. |
| `SkeletonSettingsList` | Settings hub loading state. | `Padding` + `Column` of `rowCount` (default `10`) settings-row placeholders. |
| `SkeletonTranscript` | Transcript panel loading state (typically wrapped in its own scroll view). | `ListView.separated` with `AlwaysScrollableScrollPhysics` (default) — pass a `ScrollController` to share the parent's scroll. |
| `SkeletonProfile` | Profile screen loading state. | `SingleChildScrollView` + `Column` (circle avatar + name + handle + 3 stat tiles). |

All placeholders, except `SkeletonTranscript`, are non-scrollable — they are safe
to drop directly inside `CustomScrollView` slivers, `ListView`, or any other
scrolling parent without causing an "infinite-size" assertion. See
[Placement rules](#placement-rules).

The subtitle track picker's narrow sheet can use `SkeletonTranscript`, but its
wide dialog is already inside a `SingleChildScrollView`. The dialog therefore
uses [`_buildDialogSkeletonLoading`](../../lib/features/transcript/presentation/subtitle_track_picker_sheet.dart),
a bounded `Column` of four track-row placeholders composed from `Skeleton.box`
and `Skeleton.line`. Do not replace it with the scrollable transcript placeholder;
that would reintroduce an unbounded nested viewport.

## Placement rules

A placeholder renders inside whatever parent it is given. Two parent shapes are
common in this codebase:

1. **The parent is a bounded scroll view** (own `Scrollable`, fixed viewport size).
   The placeholder can be as tall as it likes, and a `ListView` / `SingleChildScrollView`
   is acceptable here (this is what `SkeletonTranscript` and `SkeletonProfile` rely on).
2. **The parent is unbounded** — `CustomScrollView` slivers, `Column.children`,
   `Row.children`, `Flexible` / `Expanded` inside a `Column`, or anything that
   wants the child to lay out against a `BoxConstraints` with `maxHeight = ∞`.
   A scrollable placeholder inside such a parent throws an assertion along the
   lines of *"RenderFlex children have non-zero flex but incoming height constraints are unbounded"* during layout.

For case (2), use one of the **Column-based** placeholders above
(`SkeletonMediaList`, `SkeletonSettingsList`, `SkeletonProfile`) or compose a
new one the same way — a `Column(mainAxisSize: MainAxisSize.min)` of `Skeleton.*`
shapes, with `SizedBox` gaps sourced from `EnjoyThemeTokens` spacing. For
visually grid-like placeholders that still need to share scroll with their
parent, use a `GridView.builder` configured exactly as `SkeletonMediaGrid`:

```dart
GridView.builder(
  shrinkWrap: true,                          // take only the height its children need
  physics: const NeverScrollableScrollPhysics(), // scroll is delegated to the parent
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 0.72,
  ),
  itemCount: …,
  itemBuilder: …,
);
```

Do **not** use a vanilla `ListView` or `SingleChildScrollView` as the top-level
placeholder inside a sliver or unbounded `Column` — that path was the root cause
of the "skeleton list layout crash in nested scroll views" fix; see the
[`[Unreleased]`](../../CHANGELOG.md) entry.

## When to add a new placeholder

Reach for the existing widgets first. Add a new placeholder only when:

- The layout is visually distinct enough that no existing variant reads as a
  reasonable proxy (e.g. an entirely new card shape).
- The placeholder needs a different scroll contract — i.e. it sits inside a
  bounded parent that needs its own `Scrollable`.

New placeholders should:

1. Be a `StatelessWidget` named `Skeleton*` in
   `lib/core/theme/widgets/skeleton.dart`.
2. Compose only `Skeleton` / `Skeleton.line` / `Skeleton.box` / `Skeleton.circle`
   — never `Container`-based tinted rectangles, so the shimmer and reduced-motion
   behavior stays uniform.
3. Source spacing and radii from `EnjoyThemeTokens` (`.space8`, `.space12`,
   `.radiusMd`, `.radiusXl`, …) — see [app-ui.md](app-ui.md#design-token-reference-enjoythemetokens).
4. Behave correctly inside a sliver parent — see [Placement rules](#placement-rules).

## Code map

| Area | Path |
|------|------|
| Skeleton module | [`lib/core/theme/widgets/skeleton.dart`](../../lib/core/theme/widgets/skeleton.dart) |
| Skeleton app-bootstrap usage | Library, Home, Discover bootstrap paths |
| Sliver-safe list placeholders | `SkeletonMediaList`, `SkeletonSettingsList` |
| Scrollable placeholders | `SkeletonTranscript`, `SkeletonProfile` |
| Bounded subtitle-picker dialog placeholder | [`_buildDialogSkeletonLoading`](../../lib/features/transcript/presentation/subtitle_track_picker_sheet.dart) |
| Grid placeholder | `SkeletonMediaGrid` |
| Layout regression tests | [`test/core/theme/skeleton_layout_test.dart`](../../test/core/theme/skeleton_layout_test.dart) |
| Settings loading tests | [`test/features/settings/presentation/sections/settings_loading_states_test.dart`](../../test/features/settings/presentation/sections/settings_loading_states_test.dart) |

## Related

- [app-ui.md](app-ui.md) — design tokens, motion, and reduced-motion conventions.
- [features/library.md](library.md) — first-paint loading order on the Library screen.
- [features/settings.md](settings.md#account-section) — single-column / two-pane account hero loading state.
- [ADR-0083](../decisions/0083-paper-graphite-light-dark.md) — paper/graphite light+dark theme that drives `Skeleton` colors.
