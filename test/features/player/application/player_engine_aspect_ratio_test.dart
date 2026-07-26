import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' as mk;

void main() {
  group('aspectRatioFromVideoParams', () {
    const zeroState = mk.PlayerState();

    test('returns vp.aspect when present and positive', () {
      final vp = const mk.VideoParams(aspect: 2.35);
      expect(aspectRatioFromVideoParams(vp, zeroState), closeTo(2.35, 1e-9));
    });

    test('ignores vp.aspect when zero', () {
      final vp = const mk.VideoParams(aspect: 0);
      final state = const mk.PlayerState(width: 1920, height: 1080);
      expect(aspectRatioFromVideoParams(vp, state), closeTo(16 / 9, 1e-9));
    });

    test('ignores vp.aspect when negative', () {
      final vp = const mk.VideoParams(aspect: -1.5);
      final state = const mk.PlayerState(width: 1280, height: 720);
      expect(aspectRatioFromVideoParams(vp, state), closeTo(16 / 9, 1e-9));
    });

    test('prefers vp.dw / vp.dh when aspect is null', () {
      final vp = const mk.VideoParams(dw: 1280, dh: 720);
      expect(aspectRatioFromVideoParams(vp, zeroState), closeTo(16 / 9, 1e-9));
    });

    test('falls back to vp.w / vp.h when dw/dh are null', () {
      final vp = const mk.VideoParams(w: 1920, h: 1080);
      expect(aspectRatioFromVideoParams(vp, zeroState), closeTo(16 / 9, 1e-9));
    });

    test('falls back to state.width / state.height when all params null', () {
      final vp = const mk.VideoParams();
      final state = const mk.PlayerState(width: 640, height: 480);
      expect(aspectRatioFromVideoParams(vp, state), closeTo(4 / 3, 1e-9));
    });

    test('uses vp.dw even when state.width is also set', () {
      final vp = const mk.VideoParams(dw: 800, dh: 600);
      final state = const mk.PlayerState(width: 1920, height: 1080);
      expect(aspectRatioFromVideoParams(vp, state), closeTo(4 / 3, 1e-9));
    });

    test('uses vp.w when dw is null even when state.width is set', () {
      final vp = const mk.VideoParams(w: 800, h: 600);
      final state = const mk.PlayerState(width: 1920, height: 1080);
      expect(aspectRatioFromVideoParams(vp, state), closeTo(4 / 3, 1e-9));
    });

    test('returns 16/9 when all sources are null/zero', () {
      final vp = const mk.VideoParams();
      expect(aspectRatioFromVideoParams(vp, zeroState), closeTo(16 / 9, 1e-9));
    });

    test('returns 16/9 when dw/dh are zero', () {
      final vp = const mk.VideoParams(dw: 0, dh: 0);
      expect(aspectRatioFromVideoParams(vp, zeroState), closeTo(16 / 9, 1e-9));
    });

    test('returns 16/9 when w/h are zero', () {
      final vp = const mk.VideoParams(w: 0, h: 0);
      expect(aspectRatioFromVideoParams(vp, zeroState), closeTo(16 / 9, 1e-9));
    });

    test('returns 16/9 when state dimensions are zero', () {
      final vp = const mk.VideoParams();
      final state = const mk.PlayerState(width: 0, height: 0);
      expect(aspectRatioFromVideoParams(vp, state), closeTo(16 / 9, 1e-9));
    });

    test('handles square dimensions from dw/dh', () {
      final vp = const mk.VideoParams(dw: 500, dh: 500);
      expect(aspectRatioFromVideoParams(vp, zeroState), closeTo(1.0, 1e-9));
    });

    test('handles portrait dimensions from w/h', () {
      final vp = const mk.VideoParams(w: 1080, h: 1920);
      expect(aspectRatioFromVideoParams(vp, zeroState), closeTo(9 / 16, 1e-9));
    });

    test('vp.aspect takes precedence over dw/dh', () {
      final vp = const mk.VideoParams(aspect: 4.0, dw: 100, dh: 100);
      expect(aspectRatioFromVideoParams(vp, zeroState), closeTo(4.0, 1e-9));
    });
  });
}
