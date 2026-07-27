/// Deterministic generative artwork from a string seed — parity with web
/// `apps/web/src/components/library/generative-cover.tsx`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ── Public API ───────────────────────────────────────────────────────────────

/// Accent color from the same RNG stream as [GenerativeMediaCover] (last draw).
Color generativeAccentForSeed(String seed) => _computeSpec(seed).accent;

/// Full-bleed cover: gradient + pattern + centered icon (matches web layout).
class GenerativeMediaCover extends StatelessWidget {
  const GenerativeMediaCover({
    super.key,
    required this.seed,
    required this.isVideo,
  });

  final String seed;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final spec = _computeSpec(seed);
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _GenerativeCoverPainter(spec)),
        // Light noise (web uses SVG turbulence; this approximates texture).
        CustomPaint(painter: _NoisePainter(seed: seed, opacity: 0.03)),
        Center(
          child: _CenterGlassIcon(accent: spec.accent, isVideo: isVideo),
        ),
      ],
    );
  }
}

// ── Spec + painter ────────────────────────────────────────────────────────────

class _CoverSpec {
  const _CoverSpec({
    required this.angleDeg,
    required this.gradientStart,
    required this.gradientEnd,
    required this.onPaintForeground,
    required this.accent,
  });

  final double angleDeg;
  final Color gradientStart;
  final Color gradientEnd;
  final void Function(Canvas canvas, Size size) onPaintForeground;
  final Color accent;
}

/// Seeded LCG — must match `seededRandom` in `generative-cover.tsx`.
class _Rng {
  _Rng(int seed) : _state = seed;

  int _state;

  double next() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state / 0x7fffffff;
  }
}

/// Match `hashToNumber` in `generative-cover.tsx`.
@visibleForTesting
int hashToNumber(String hash, [int offset = 0]) {
  var value = 0;
  final modBase = math.max(1, hash.length - 4);
  final startIndex = offset % modBase;
  final upper = math.min(8, hash.length - startIndex);
  for (var i = 0; i < upper; i++) {
    value += hash.codeUnitAt(startIndex + i) * (i + 1);
  }
  return value;
}

const List<List<Color>> _palettes = [
  [Color(0xFFFF6B6B), Color(0xFFFEC89A), Color(0xFFFFD93D), Color(0xFF6BCB77)],
  [Color(0xFF4ECDC4), Color(0xFF45B7D1), Color(0xFF96CEB4), Color(0xFF88D8B0)],
  [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb), Color(0xFFf5576c)],
  [Color(0xFF134E5E), Color(0xFF71B280), Color(0xFF3D7068), Color(0xFFA8E6CF)],
  [Color(0xFF2C3E50), Color(0xFF34495E), Color(0xFF5D6D7E), Color(0xFF85929E)],
  [Color(0xFFD4A5A5), Color(0xFFFFCFDF), Color(0xFFE8B4B8), Color(0xFFA67B5B)],
  [Color(0xFF4A5568), Color(0xFF718096), Color(0xFFA0AEC0), Color(0xFFCBD5E0)],
  [Color(0xFFD35400), Color(0xFFE67E22), Color(0xFFF39C12), Color(0xFFF1C40F)],
  [Color(0xFF9B59B6), Color(0xFF8E44AD), Color(0xFFBB8FCE), Color(0xFFD7BDE2)],
  [Color(0xFF16A085), Color(0xFF1ABC9C), Color(0xFF48C9B0), Color(0xFF76D7C4)],
];

enum _PatternType { circles, rectangles, waves, grid, diagonal }

List<Color> _getPalette(String hash) {
  final index = hashToNumber(hash, 0) % _palettes.length;
  return _palettes[index];
}

_PatternType _getPatternType(String hash) {
  const patterns = _PatternType.values;
  final index = hashToNumber(hash, 4) % patterns.length;
  return patterns[index];
}

/// CSS `#RRGGBB` + two-digit alpha suffix (`20`, `30`).
Color _colorWithHexSuffix(Color rgb, int alphaByte) => rgb.withAlpha(alphaByte);

void _paintCircles(
  List<void Function(Canvas, Size)> shapes,
  List<Color> palette,
  _Rng rng,
) {
  final count = 3 + (rng.next() * 4).floor();
  for (var i = 0; i < count; i++) {
    final cx = 10 + rng.next() * 80;
    final cy = 10 + rng.next() * 80;
    final r = 8 + rng.next() * 25;
    final color = palette[(rng.next() * palette.length).floor()];
    final opacity = 0.3 + rng.next() * 0.4;
    shapes.add((canvas, size) {
      final ux = size.width / 100;
      final uy = size.height / 100;
      final rr = r * 0.01 * size.shortestSide;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx * ux, cy * uy), rr, paint);
    });
  }
}

void _paintRectangles(
  List<void Function(Canvas, Size)> shapes,
  List<Color> palette,
  _Rng rng,
) {
  final count = 3 + (rng.next() * 3).floor();
  for (var i = 0; i < count; i++) {
    final x = rng.next() * 60;
    final y = rng.next() * 60;
    final w = 20 + rng.next() * 40;
    final h = 20 + rng.next() * 40;
    final color = palette[(rng.next() * palette.length).floor()];
    final opacity = 0.25 + rng.next() * 0.35;
    final rx = rng.next() > 0.5 ? 4 + rng.next() * 8 : 0.0;
    shapes.add((canvas, size) {
      final ux = size.width / 100;
      final uy = size.height / 100;
      final rect = Rect.fromLTWH(x * ux, y * uy, w * ux, h * uy);
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      if (rx > 0) {
        canvas.drawRRect(RRect.fromRectXY(rect, rx * ux, rx * uy), paint);
      } else {
        canvas.drawRect(rect, paint);
      }
    });
  }
}

void _paintWaves(
  List<void Function(Canvas, Size)> shapes,
  List<Color> palette,
  _Rng rng,
) {
  final count = 3 + (rng.next() * 2).floor();
  for (var i = 0; i < count; i++) {
    final yOffset = 20 + i * 25 + rng.next() * 10;
    final amplitude = 10 + rng.next() * 15;
    final color = palette[(rng.next() * palette.length).floor()];
    final opacity = 0.3 + rng.next() * 0.3;

    final xs = <double>[];
    final ys = <double>[];
    for (var x = 0.0; x <= 100; x += 5) {
      final y =
          yOffset +
          math.sin((x / 100) * math.pi * (2 + rng.next())) * amplitude;
      xs.add(x);
      ys.add(y);
    }
    shapes.add((canvas, size) {
      final ux = size.width / 100;
      final uy = size.height / 100;
      final path = Path();
      path.moveTo(xs[0] * ux, ys[0] * uy);
      for (var k = 1; k < xs.length; k++) {
        path.lineTo(xs[k] * ux, ys[k] * uy);
      }
      path.lineTo(100 * ux, 100 * uy);
      path.lineTo(0, 100 * uy);
      path.close();
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paint);
    });
  }
}

void _paintGrid(
  List<void Function(Canvas, Size)> shapes,
  List<Color> palette,
  _Rng rng,
) {
  final cols = 3 + (rng.next() * 2).floor();
  final rows = 2 + (rng.next() * 2).floor();
  const gap = 2.0;

  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      if (rng.next() > 0.3) {
        final cellWidth = (100 - gap * (cols + 1)) / cols;
        final cellHeight = (100 - gap * (rows + 1)) / rows;
        final x = gap + col * (cellWidth + gap);
        final y = gap + row * (cellHeight + gap);
        final color = palette[(rng.next() * palette.length).floor()];
        final opacity = 0.3 + rng.next() * 0.4;
        shapes.add((canvas, size) {
          final ux = size.width / 100;
          final uy = size.height / 100;
          final rect = Rect.fromLTWH(
            x * ux,
            y * uy,
            cellWidth * ux,
            cellHeight * uy,
          );
          final paint = Paint()
            ..color = color.withValues(alpha: opacity)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(RRect.fromRectXY(rect, 3 * ux, 3 * uy), paint);
        });
      }
    }
  }
}

void _paintDiagonal(
  List<void Function(Canvas, Size)> shapes,
  List<Color> palette,
  _Rng rng,
) {
  final count = 4 + (rng.next() * 3).floor();
  for (var i = 0; i < count; i++) {
    final startX = -20 + rng.next() * 80;
    final width = 15 + rng.next() * 25;
    final color = palette[(rng.next() * palette.length).floor()];
    final opacity = 0.25 + rng.next() * 0.35;
    shapes.add((canvas, size) {
      final ux = size.width / 100;
      final uy = size.height / 100;
      final path = Path()
        ..moveTo(startX * ux, 0)
        ..lineTo((startX + width) * ux, 0)
        ..lineTo((startX + width + 100) * ux, 100 * uy)
        ..lineTo((startX + 100) * ux, 100 * uy)
        ..close();
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paint);
    });
  }
}

final Map<String, _CoverSpec> _specCache = {};
const int _specCacheLimit = 64;

_CoverSpec _computeSpec(String seed) {
  final cached = _specCache[seed];
  if (cached != null) return cached;

  final palette = _getPalette(seed);
  final patternType = _getPatternType(seed);
  final rng = _Rng(hashToNumber(seed, 8));

  final angle = (rng.next() * 360).floorToDouble();
  final c1 = palette[(rng.next() * palette.length).floor()];
  final c2 = palette[(rng.next() * palette.length).floor()];
  final gradientStart = _colorWithHexSuffix(c1, 0x20);
  final gradientEnd = _colorWithHexSuffix(c2, 0x30);

  final shapes = <void Function(Canvas, Size)>[];
  switch (patternType) {
    case _PatternType.circles:
      _paintCircles(shapes, palette, rng);
      break;
    case _PatternType.rectangles:
      _paintRectangles(shapes, palette, rng);
      break;
    case _PatternType.waves:
      _paintWaves(shapes, palette, rng);
      break;
    case _PatternType.grid:
      _paintGrid(shapes, palette, rng);
      break;
    case _PatternType.diagonal:
      _paintDiagonal(shapes, palette, rng);
      break;
  }

  final accent = palette[(rng.next() * palette.length).floor()];

  void paintForeground(Canvas canvas, Size size) {
    for (final draw in shapes) {
      draw(canvas, size);
    }
  }

  final result = _CoverSpec(
    angleDeg: angle,
    gradientStart: gradientStart,
    gradientEnd: gradientEnd,
    onPaintForeground: paintForeground,
    accent: accent,
  );

  if (_specCache.length >= _specCacheLimit) {
    _specCache.remove(_specCache.keys.first);
  }
  _specCache[seed] = result;
  return result;
}

class _GenerativeCoverPainter extends CustomPainter {
  _GenerativeCoverPainter(this.spec);

  final _CoverSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rad = spec.angleDeg * math.pi / 180;
    final begin = Alignment(-math.sin(rad), math.cos(rad));
    final end = Alignment(math.sin(rad), -math.cos(rad));
    final gradient = LinearGradient(
      begin: begin,
      end: end,
      colors: [spec.gradientStart, spec.gradientEnd],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
    spec.onPaintForeground(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _GenerativeCoverPainter oldDelegate) =>
      oldDelegate.spec.angleDeg != spec.angleDeg ||
      oldDelegate.spec.gradientStart != spec.gradientStart ||
      oldDelegate.spec.gradientEnd != spec.gradientEnd ||
      oldDelegate.spec.accent != spec.accent;
}

class _NoisePainter extends CustomPainter {
  _NoisePainter({required this.seed, required this.opacity})
    : _rnd = math.Random(hashToNumber(seed, 16));

  final String seed;
  final double opacity;
  final math.Random _rnd;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final paint = Paint()
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;
    // Sparse grain — cheap stand-in for SVG fractal noise.
    for (var i = 0; i < 180; i++) {
      final x = _rnd.nextDouble() * size.width;
      final y = _rnd.nextDouble() * size.height;
      paint.color = Colors.black.withValues(alpha: opacity * _rnd.nextDouble());
      canvas.drawCircle(Offset(x, y), 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.seed != seed;
}

class _CenterGlassIcon extends StatelessWidget {
  const _CenterGlassIcon({required this.accent, required this.isVideo});

  final Color accent;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.19)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Icon(
          isVideo ? Icons.play_arrow_rounded : Icons.audiotrack_rounded,
          size: 28,
          color: accent.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
