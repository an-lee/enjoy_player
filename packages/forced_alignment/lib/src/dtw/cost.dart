import 'dart:math' as math;

/// Euclidean distance between two MFCC vectors.
double euclideanDistance(List<double> a, List<double> b) {
  final n = math.min(a.length, b.length);
  var sum = 0.0;
  for (var i = 0; i < n; i++) {
    final d = a[i] - b[i];
    sum += d * d;
  }
  return math.sqrt(sum);
}
