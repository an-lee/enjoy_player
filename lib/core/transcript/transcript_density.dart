/// Mobile-density tokens for the transcript panel and echo region controls.
///
/// On phones (iOS / Android) the script size, list padding, and echo chrome
/// use a denser rhythm so a single screen-fit shows more cues without crowding
/// tap targets. Desktop stays slightly more open but still compact.
///
/// Read via [transcriptDensityOf] from a widget `BuildContext`; the helper
/// resolves [isMobilePlatform] against the current [defaultTargetPlatform].
///
/// See docs/features/transcript.md § Mobile density for the canonical values.
library;

import 'package:flutter/widgets.dart';

import 'package:enjoy_player/core/platform/mobile_platform.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

/// Density values as a record — structural `==` / `hashCode` for free.
typedef TranscriptDensity = ({
  double listHorizontalPadding,
  double listVerticalPadding,
  double lineVerticalPadding,
  double lineInterGap,
  double headerBodyGap,
  double primarySecondaryGap,
  double secondaryLeftPadding,
  double bodyHeight,
  double secondaryHeight,
  double echoControlsPadding,
  double echoCardGap,
  double echoBottomPanelGap,
  double echoDividerThickness,
  double echoControlIconSize,
});

/// Returns compact values on [isMobilePlatform], full-spacing otherwise.
///
/// Every value is resolved against the current [Theme]'s [EnjoyThemeTokens]
/// so the desktop branch always tracks the latest spacing tokens.
TranscriptDensity transcriptDensityOf(BuildContext context) {
  final tok = EnjoyThemeTokens.of(context);
  final compact = isMobilePlatform;
  return (
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
