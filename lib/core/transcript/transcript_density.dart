/// Mobile-density tokens for the transcript panel and echo region controls.
///
/// On phones (iOS / Android) the script size, list padding, and echo chrome
/// use a denser rhythm so a single screen-fit shows more cues without crowding
/// tap targets. Desktop stays slightly more open but still compact.
///
/// Read via [TranscriptDensity.of] from a widget `BuildContext`; the helper
/// resolves [isMobilePlatform] against the current [defaultTargetPlatform].
///
/// See docs/features/transcript.md § Mobile density for the canonical values.
library;

import 'package:flutter/widgets.dart';

import 'package:enjoy_player/core/platform/mobile_platform.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

@immutable
class TranscriptDensity {
  const TranscriptDensity({
    required this.listHorizontalPadding,
    required this.listVerticalPadding,
    required this.lineVerticalPadding,
    required this.lineInterGap,
    required this.headerBodyGap,
    required this.primarySecondaryGap,
    required this.secondaryLeftPadding,
    required this.bodyHeight,
    required this.secondaryHeight,
    required this.echoControlsPadding,
    required this.echoCardGap,
    required this.echoBottomPanelGap,
    required this.echoDividerThickness,
    required this.echoControlIconSize,
  });

  final double listHorizontalPadding;
  final double listVerticalPadding;
  final double lineVerticalPadding;
  final double lineInterGap;
  final double headerBodyGap;
  final double primarySecondaryGap;
  final double secondaryLeftPadding;
  final double bodyHeight;
  final double secondaryHeight;
  final double echoControlsPadding;
  final double echoCardGap;
  final double echoBottomPanelGap;
  final double echoDividerThickness;
  final double echoControlIconSize;

  /// Returns compact values on [isMobilePlatform], full-spacing otherwise.
  ///
  /// Every value is resolved against the current [Theme]'s
  /// [EnjoyThemeTokens] so the desktop branch always tracks the latest
  /// spacing tokens.
  static TranscriptDensity of(BuildContext context) {
    final tok = EnjoyThemeTokens.of(context);
    final compact = isMobilePlatform;
    return TranscriptDensity(
      listHorizontalPadding: compact ? 8 : tok.space12,
      listVerticalPadding: compact ? 4 : tok.space8,
      lineVerticalPadding: compact ? 4 : 6,
      lineInterGap: compact ? 2 : tok.space4,
      headerBodyGap: 2,
      primarySecondaryGap: compact ? 2 : tok.space4,
      secondaryLeftPadding: compact ? 8 : tok.space12,
      bodyHeight: compact ? 1.35 : 1.45,
      secondaryHeight: compact ? 1.3 : 1.4,
      echoControlsPadding: compact ? 2 : tok.space4,
      echoCardGap: compact ? 4 : tok.space8,
      echoBottomPanelGap: compact ? 4 : tok.space8,
      echoDividerThickness: compact ? 0.5 : 1.0,
      echoControlIconSize: compact ? 16 : 20,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscriptDensity &&
          listHorizontalPadding == other.listHorizontalPadding &&
          listVerticalPadding == other.listVerticalPadding &&
          lineVerticalPadding == other.lineVerticalPadding &&
          lineInterGap == other.lineInterGap &&
          headerBodyGap == other.headerBodyGap &&
          primarySecondaryGap == other.primarySecondaryGap &&
          secondaryLeftPadding == other.secondaryLeftPadding &&
          bodyHeight == other.bodyHeight &&
          secondaryHeight == other.secondaryHeight &&
          echoControlsPadding == other.echoControlsPadding &&
          echoCardGap == other.echoCardGap &&
          echoBottomPanelGap == other.echoBottomPanelGap &&
          echoDividerThickness == other.echoDividerThickness &&
          echoControlIconSize == other.echoControlIconSize;

  @override
  int get hashCode => Object.hash(
    listHorizontalPadding,
    listVerticalPadding,
    lineVerticalPadding,
    lineInterGap,
    headerBodyGap,
    primarySecondaryGap,
    secondaryLeftPadding,
    bodyHeight,
    secondaryHeight,
    echoControlsPadding,
    echoCardGap,
    echoBottomPanelGap,
    echoDividerThickness,
    echoControlIconSize,
  );
}
