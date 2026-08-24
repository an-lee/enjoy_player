/// Prototype outlined chrome icons (sprite port) for shell / transport / settings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Glyphs ported from the Enjoy Player prototype `assets/icons.svg` sprite.
enum EnjoyChromeGlyph {
  home,
  compass,
  library,
  user,
  play,
  pause,
  skipBack,
  skipForward,
  replay,
  mic,
  wave,
  cc,
  speed,
  volume,
  volumeOff,
  plus,
  search,
  close,
  sun,
  moon,
  monitor,
  gear,
  chevronDown,
  chevronRight,
  chevronLeft,
  dots,
  check,
}

extension EnjoyChromeGlyphAsset on EnjoyChromeGlyph {
  String get assetPath {
    switch (this) {
      case EnjoyChromeGlyph.home:
        return 'assets/icons/home.svg';
      case EnjoyChromeGlyph.compass:
        return 'assets/icons/compass.svg';
      case EnjoyChromeGlyph.library:
        return 'assets/icons/library.svg';
      case EnjoyChromeGlyph.user:
        return 'assets/icons/user.svg';
      case EnjoyChromeGlyph.play:
        return 'assets/icons/play.svg';
      case EnjoyChromeGlyph.pause:
        return 'assets/icons/pause.svg';
      case EnjoyChromeGlyph.skipBack:
        return 'assets/icons/skip-back.svg';
      case EnjoyChromeGlyph.skipForward:
        return 'assets/icons/skip-forward.svg';
      case EnjoyChromeGlyph.replay:
        return 'assets/icons/replay.svg';
      case EnjoyChromeGlyph.mic:
        return 'assets/icons/mic.svg';
      case EnjoyChromeGlyph.wave:
        return 'assets/icons/wave.svg';
      case EnjoyChromeGlyph.cc:
        return 'assets/icons/cc.svg';
      case EnjoyChromeGlyph.speed:
        return 'assets/icons/speed.svg';
      case EnjoyChromeGlyph.volume:
        return 'assets/icons/volume.svg';
      case EnjoyChromeGlyph.volumeOff:
        return 'assets/icons/volume-off.svg';
      case EnjoyChromeGlyph.plus:
        return 'assets/icons/plus.svg';
      case EnjoyChromeGlyph.search:
        return 'assets/icons/search.svg';
      case EnjoyChromeGlyph.close:
        return 'assets/icons/x.svg';
      case EnjoyChromeGlyph.sun:
        return 'assets/icons/sun.svg';
      case EnjoyChromeGlyph.moon:
        return 'assets/icons/moon.svg';
      case EnjoyChromeGlyph.monitor:
        return 'assets/icons/monitor.svg';
      case EnjoyChromeGlyph.gear:
        return 'assets/icons/gear.svg';
      case EnjoyChromeGlyph.chevronDown:
        return 'assets/icons/chevron-down.svg';
      case EnjoyChromeGlyph.chevronRight:
        return 'assets/icons/chevron-right.svg';
      case EnjoyChromeGlyph.chevronLeft:
        return 'assets/icons/chevron-left.svg';
      case EnjoyChromeGlyph.dots:
        return 'assets/icons/dots.svg';
      case EnjoyChromeGlyph.check:
        return 'assets/icons/check.svg';
    }
  }
}

/// Tinted SVG chrome icon. Color follows [IconTheme] when [color] is omitted.
class EnjoyChromeIcon extends StatelessWidget {
  const EnjoyChromeIcon(this.glyph, {super.key, this.size, this.color});

  final EnjoyChromeGlyph glyph;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 22;
    final resolvedColor =
        color ?? iconTheme.color ?? DefaultTextStyle.of(context).style.color;
    return SvgPicture.asset(
      glyph.assetPath,
      width: resolvedSize,
      height: resolvedSize,
      colorFilter: resolvedColor == null
          ? null
          : ColorFilter.mode(resolvedColor, BlendMode.srcIn),
      semanticsLabel: glyph.name,
    );
  }
}
