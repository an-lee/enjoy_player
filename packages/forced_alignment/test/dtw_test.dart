import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/src/dtw/windowed_dtw.dart';

List<double> _vec(double x) => [x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

void main() {
  test('identical sequences map each reference frame to itself', () {
    final seq = [for (var i = 0; i < 12; i++) _vec(i.toDouble())];
    final map = mapReferenceFramesToSource(seq, seq);
    for (var i = 0; i < seq.length; i++) {
      expect(map[i], i, reason: 'frame $i');
    }
  });

  test('source delayed by 2 frames maps i -> i+2', () {
    final reference = [for (var i = 0; i < 10; i++) _vec(i.toDouble())];
    final source = [_vec(-2), _vec(-1), ...reference];
    final map = mapReferenceFramesToSource(reference, source);
    for (var i = 0; i < reference.length; i++) {
      expect(
        (map[i] - (i + 2)).abs(),
        lessThanOrEqualTo(1),
        reason: 'frame $i mapped to ${map[i]}',
      );
    }
  });
}
