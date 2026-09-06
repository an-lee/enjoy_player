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
  static const _paths = <EnjoyChromeGlyph, String>{
    EnjoyChromeGlyph.home: 'assets/icons/home.svg',
    EnjoyChromeGlyph.compass: 'assets/icons/compass.svg',
    EnjoyChromeGlyph.library: 'assets/icons/library.svg',
    EnjoyChromeGlyph.user: 'assets/icons/user.svg',
    EnjoyChromeGlyph.play: 'assets/icons/play.svg',
    EnjoyChromeGlyph.pause: 'assets/icons/pause.svg',
    EnjoyChromeGlyph.skipBack: 'assets/icons/skip-back.svg',
    EnjoyChromeGlyph.skipForward: 'assets/icons/skip-forward.svg',
    EnjoyChromeGlyph.replay: 'assets/icons/replay.svg',
    EnjoyChromeGlyph.mic: 'assets/icons/mic.svg',
    EnjoyChromeGlyph.wave: 'assets/icons/wave.svg',
    EnjoyChromeGlyph.cc: 'assets/icons/cc.svg',
    EnjoyChromeGlyph.speed: 'assets/icons/speed.svg',
    EnjoyChromeGlyph.volume: 'assets/icons/volume.svg',
    EnjoyChromeGlyph.volumeOff: 'assets/icons/volume-off.svg',
    EnjoyChromeGlyph.plus: 'assets/icons/plus.svg',
    EnjoyChromeGlyph.search: 'assets/icons/search.svg',
    EnjoyChromeGlyph.close: 'assets/icons/x.svg',
    EnjoyChromeGlyph.sun: 'assets/icons/sun.svg',
    EnjoyChromeGlyph.moon: 'assets/icons/moon.svg',
    EnjoyChromeGlyph.monitor: 'assets/icons/monitor.svg',
    EnjoyChromeGlyph.gear: 'assets/icons/gear.svg',
    EnjoyChromeGlyph.chevronDown: 'assets/icons/chevron-down.svg',
    EnjoyChromeGlyph.chevronRight: 'assets/icons/chevron-right.svg',
    EnjoyChromeGlyph.chevronLeft: 'assets/icons/chevron-left.svg',
    EnjoyChromeGlyph.dots: 'assets/icons/dots.svg',
    EnjoyChromeGlyph.check: 'assets/icons/check.svg',
  };

  String get assetPath => _paths[this]!;
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
