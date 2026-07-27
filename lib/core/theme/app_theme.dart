/// Material 3 theme — dark-only cinematic editorial (logo-aligned blue / purple).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'colors.dart';
import 'enjoy_tokens.dart';
import 'typography.dart';

ThemeData? _cachedTheme;

ThemeData buildAppTheme() {
  return _cachedTheme ??= _buildAppThemeImpl();
}

ThemeData _buildAppThemeImpl() {
  // ── Color scheme ────────────────────────────────────────────────────────
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.seedBrand,
    brightness: Brightness.dark,
  );

  final colorScheme = _refinedDark(base);

  // ── Tokens ──────────────────────────────────────────────────────────────
  final tokens = EnjoyThemeTokens.build(colorScheme);

  // ── Typography ──────────────────────────────────────────────────────────
  final baseTheme = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: Brightness.dark,
  );
  final textTheme = buildBaseTextTheme(baseTheme.textTheme, colorScheme);

  // Serif extension (default: serif ON for transcript)
  final transcriptTokens = TranscriptTypographyTokens.build(
    useSerif: true,
    base: textTheme,
    scheme: colorScheme,
  );

  // ── Component themes ────────────────────────────────────────────────────
  final navigationBarTheme = NavigationBarThemeData(
    height: 68,
    backgroundColor: colorScheme.surface,
    indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.7),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return textTheme.labelMedium?.copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        size: 24,
        color: selected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
      );
    }),
  );

  final railTheme = NavigationRailThemeData(
    backgroundColor: Colors.transparent,
    indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
    selectedIconTheme: IconThemeData(
      color: colorScheme.onPrimaryContainer,
      size: 22,
    ),
    unselectedIconTheme: IconThemeData(
      color: colorScheme.onSurfaceVariant,
      size: 22,
    ),
    selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    ),
    minWidth: 88,
    minExtendedWidth: 200,
  );

  final inactiveSliderColor = colorScheme.onSurface.withValues(alpha: 0.12);

  final sliderTheme = SliderThemeData(
    trackHeight: 2,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
    overlayShape: SliderComponentShape.noOverlay,
    activeTrackColor: colorScheme.primary,
    inactiveTrackColor: inactiveSliderColor,
    thumbColor: colorScheme.primary,
    overlayColor: colorScheme.primary.withValues(alpha: 0.12),
  );

  final snackBarTheme = SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    elevation: tokens.elevationSheet,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusXl),
    ),
    backgroundColor: colorScheme.surfaceContainerHigh,
    contentTextStyle: textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
    ),
    actionTextColor: colorScheme.primary,
    showCloseIcon: false,
    closeIconColor: colorScheme.onSurface,
    dismissDirection: DismissDirection.horizontal,
  );

  final bottomSheetTheme = BottomSheetThemeData(
    backgroundColor: colorScheme.surfaceContainerHigh,
    surfaceTintColor: Colors.transparent,
    elevation: tokens.elevationSheet,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(tokens.radiusXl),
      ),
    ),
    dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
    dragHandleSize: const Size(36, 4),
    showDragHandle: true,
  );

  final cardTheme = CardThemeData(
    elevation: tokens.elevationCard,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusXl),
      side: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.15),
      ),
    ),
    color: colorScheme.surfaceContainerLow,
  );

  final listTileTheme = ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(
      horizontal: tokens.space16,
      vertical: tokens.space4,
    ),
    iconColor: colorScheme.onSurfaceVariant,
    titleTextStyle: textTheme.titleMedium,
    subtitleTextStyle: textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    ),
    minVerticalPadding: tokens.space12,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusMd),
    ),
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: Brightness.dark,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    splashColor: colorScheme.primary.withValues(alpha: 0.10),
    highlightColor: colorScheme.primary.withValues(alpha: 0.05),
    hoverColor: colorScheme.onSurface.withValues(alpha: 0.06),
    focusColor: colorScheme.primary.withValues(alpha: 0.14),
    extensions: <ThemeExtension<dynamic>>[tokens, transcriptTokens],
    textTheme: textTheme,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
      ),
    ),
    cardTheme: cardTheme,
    listTileTheme: listTileTheme,
    navigationBarTheme: navigationBarTheme,
    navigationRailTheme: railTheme,
    sliderTheme: sliderTheme,
    snackBarTheme: snackBarTheme,
    bottomSheetTheme: bottomSheetTheme,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space24,
          vertical: tokens.space12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
        textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.1),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space24,
          vertical: tokens.space12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.1),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space16,
          vertical: tokens.space8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
        textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.1),
      ),
    ),
    iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: 24),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
      thickness: 1,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      elevation: tokens.elevationModal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusXl),
      ),
      backgroundColor: colorScheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: tokens.space24,
        vertical: tokens.space24,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      elevation: tokens.elevationSheet,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.space16,
        vertical: tokens.space12,
      ),
      isDense: false,
      labelStyle: textTheme.labelLarge?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: textTheme.labelLarge?.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
      helperStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
        height: 1.35,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusFull),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      backgroundColor: colorScheme.surfaceContainerLow,
      labelStyle: textTheme.labelSmall,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // Cupertino slide for Apple platforms
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        // Fade-upward for others
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(6),
      radius: Radius.circular(tokens.radiusFull),
      thumbColor: WidgetStateProperty.all(
        colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
      crossAxisMargin: 2,
      mainAxisMargin: 4,
    ),
  );
}

// ── Dark color scheme refinement (surfaces + logo-aligned roles) ───────────
ColorScheme _refinedDark(ColorScheme base) {
  return base.copyWith(
    surface: AppColors.surfaceDark,
    surfaceDim: AppColors.surfaceContainerLowestDark,
    surfaceBright: AppColors.surfaceContainerHighestDark,
    surfaceContainerLowest: AppColors.surfaceContainerLowestDark,
    surfaceContainerLow: AppColors.surfaceContainerLowDark,
    surfaceContainer: AppColors.surfaceContainerDark,
    surfaceContainerHigh: AppColors.surfaceContainerHighDark,
    surfaceContainerHighest: AppColors.surfaceContainerHighestDark,
    // Premium purple primary
    primary: AppColors.brand,
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFF2B2250),
    onPrimaryContainer: AppColors.brandOnDark,
    // Logo blue secondary
    secondary: AppColors.brandSecondary,
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFF172554),
    onSecondaryContainer: const Color(0xFFBFDBFE),
  );
}
