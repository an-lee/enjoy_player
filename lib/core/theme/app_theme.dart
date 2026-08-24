/// Material 3 theme — paper (light) / graphite (dark) cinematic editorial.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';
import 'enjoy_tokens.dart';
import 'typography.dart';

ThemeData? _cachedLight;
ThemeData? _cachedDark;

/// Builds the Enjoy [ThemeData] for [brightness].
///
/// Results are cached per brightness. Existing call sites that omit
/// [brightness] still receive dark (historical default).
ThemeData buildAppTheme([Brightness brightness = Brightness.dark]) {
  if (brightness == Brightness.light) {
    return _cachedLight ??= _buildAppThemeImpl(Brightness.light);
  }
  return _cachedDark ??= _buildAppThemeImpl(Brightness.dark);
}

ThemeData _buildAppThemeImpl(Brightness brightness) {
  final colorScheme = AppColors.colorScheme(brightness);
  final tokens = EnjoyThemeTokens.build(colorScheme);

  final baseTheme = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: brightness,
  );
  final textTheme = buildBaseTextTheme(baseTheme.textTheme, colorScheme);

  final transcriptTokens = TranscriptTypographyTokens.build(
    useSerif: true,
    base: textTheme,
    scheme: colorScheme,
  );

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
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
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
    elevation: 0,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusXl),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),
    color: colorScheme.surface,
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

  final focusGlow = tokens.accentInk.withValues(alpha: 0.18);

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: brightness,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    splashColor: colorScheme.primary.withValues(alpha: 0.10),
    highlightColor: colorScheme.primary.withValues(alpha: 0.05),
    hoverColor: colorScheme.onSurface.withValues(alpha: 0.06),
    focusColor: colorScheme.primary.withValues(alpha: 0.14),
    extensions: <ThemeExtension<dynamic>>[tokens, transcriptTokens],
    textTheme: textTheme,
    scaffoldBackgroundColor: Colors.transparent,
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: colorScheme.primary,
    ),
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
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
        textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.1),
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space24,
          vertical: tokens.space12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
        side: BorderSide(color: colorScheme.outline, width: 1),
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
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
        textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.1),
      ),
    ),
    iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: 24),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
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
      fillColor: colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide(color: tokens.accentInk, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
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
        color: tokens.accentInk,
        fontWeight: FontWeight.w600,
      ),
      helperStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
        height: 1.35,
      ),
      focusColor: focusGlow,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusFull),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: textTheme.labelSmall,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
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

/// Status / navigation bar chrome that follows paper vs graphite.
SystemUiOverlayStyle enjoySystemUiOverlayStyle(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: dark
        ? AppColors.surfaceContainerLowestDark
        : AppColors.surfaceContainerLowestLight,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}
