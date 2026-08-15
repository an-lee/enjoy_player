import 'dart:math' as math;

import 'cost.dart';

/// Sakoe-Chiba windowed DTW.
///
/// Returns, for each **reference** frame index, the matched **source** frame
/// index (median along the recovered path).
List<int> mapReferenceFramesToSource(
  List<List<double>> reference,
  List<List<double>> source, {
  double windowPct = 0.20,
}) {
  final n = reference.length;
  final m = source.length;
  if (n == 0 || m == 0) {
    throw ArgumentError('DTW sequences must be non-empty');
  }
  if (n == 1 && m == 1) return const [0];

  var radius = math.max((windowPct * math.max(n, m)).round(), (n - m).abs());
  radius = math.max(radius, 1);

  const inf = 1e30;
  final width = 2 * radius + 1;
  final cost = List<List<double>>.generate(
    n,
    (_) => List<double>.filled(width, inf),
  );
  final prevI = List<List<int>>.generate(n, (_) => List<int>.filled(width, -1));
  final prevJ = List<List<int>>.generate(n, (_) => List<int>.filled(width, -1));

  int jCenter(int i) => ((i + 0.5) * m / n).floor().clamp(0, m - 1);

  int bandCol(int i, int j) => j - (jCenter(i) - radius);

  bool inBand(int i, int j) {
    if (j < 0 || j >= m) return false;
    final col = bandCol(i, j);
    return col >= 0 && col < width;
  }

  for (var i = 0; i < n; i++) {
    final jc = jCenter(i);
    final jStart = math.max(0, jc - radius);
    final jEnd = math.min(m - 1, jc + radius);
    for (var j = jStart; j <= jEnd; j++) {
      final d = euclideanDistance(reference[i], source[j]);
      final col = bandCol(i, j);
      if (i == 0 && j == 0) {
        cost[0][col] = d;
        continue;
      }
      var best = inf;
      var bi = -1;
      var bj = -1;
      void consider(int pi, int pj) {
        if (!inBand(pi, pj)) return;
        final c = cost[pi][bandCol(pi, pj)];
        if (c < best) {
          best = c;
          bi = pi;
          bj = pj;
        }
      }

      if (i > 0) consider(i - 1, j);
      if (j > 0) consider(i, j - 1);
      if (i > 0 && j > 0) consider(i - 1, j - 1);
      cost[i][col] = d + (best >= inf / 2 ? 0 : best);
      prevI[i][col] = bi;
      prevJ[i][col] = bj;
    }
  }

  final jsForI = List<List<int>>.generate(n, (_) => <int>[]);
  var i = n - 1;
  var j = m - 1;
  if (!inBand(i, j) || cost[i][bandCol(i, j)] >= inf / 2) {
    return [
      for (var k = 0; k < n; k++) ((k + 0.5) * m / n).floor().clamp(0, m - 1),
    ];
  }

  var guard = n * m + 8;
  while (guard-- > 0) {
    jsForI[i].add(j);
    final col = bandCol(i, j);
    final pi = prevI[i][col];
    final pj = prevJ[i][col];
    if (pi < 0 || (pi == i && pj == j)) break;
    i = pi;
    j = pj;
  }

  return [
    for (var k = 0; k < n; k++)
      jsForI[k].isEmpty
          ? ((k + 0.5) * m / n).floor().clamp(0, m - 1)
          : jsForI[k][jsForI[k].length ~/ 2],
  ];
}
