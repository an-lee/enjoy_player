import 'package:enjoy_player/core/window/window_fullscreen_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initial state defaults to false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(windowFullscreenProvider), isFalse);
  });

  test('onWindowEnterFullScreen flips state to true', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(windowFullscreenProvider.notifier);
    notifier.onWindowEnterFullScreen();
    expect(container.read(windowFullscreenProvider), isTrue);
  });

  test('onWindowLeaveFullScreen flips state back to false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(windowFullscreenProvider.notifier);
    notifier.onWindowEnterFullScreen();
    expect(container.read(windowFullscreenProvider), isTrue);
    notifier.onWindowLeaveFullScreen();
    expect(container.read(windowFullscreenProvider), isFalse);
  });

  test('toggle flips state (false -> true)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(windowFullscreenProvider.notifier);
    expect(container.read(windowFullscreenProvider), isFalse);

    // The default setWindowFullscreen is a no-op (test runs on Linux Flutter
    // test host, not a real desktop binary), so the flip is driven solely by
    // `state = value` inside setFullscreen.
    await notifier.toggle();
    expect(container.read(windowFullscreenProvider), isTrue);
  });

  test('toggle flips state (true -> false)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(windowFullscreenProvider.notifier);
    notifier.onWindowEnterFullScreen();
    expect(container.read(windowFullscreenProvider), isTrue);

    await notifier.toggle();
    expect(container.read(windowFullscreenProvider), isFalse);
  });

  test('setFullscreen(false) leaves fullscreen when in fullscreen', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(windowFullscreenProvider.notifier);
    notifier.onWindowEnterFullScreen();
    expect(container.read(windowFullscreenProvider), isTrue);

    await notifier.setFullscreen(false);
    expect(container.read(windowFullscreenProvider), isFalse);
  });

  test(
    'setFullscreen(true) enters fullscreen when not in fullscreen',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(windowFullscreenProvider.notifier);
      expect(container.read(windowFullscreenProvider), isFalse);

      await notifier.setFullscreen(true);
      expect(container.read(windowFullscreenProvider), isTrue);
    },
  );

  test('emits to listeners via state-change stream', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(windowFullscreenProvider.notifier);
    final emissions = <bool>[];
    final sub = container.listen<dynamic>(
      windowFullscreenProvider,
      (_, next) => emissions.add(next as bool),
      fireImmediately: true,
    );
    notifier.onWindowEnterFullScreen();
    notifier.onWindowLeaveFullScreen();
    notifier.onWindowEnterFullScreen();
    // The initial value, plus three more events.
    expect(emissions, [false, true, false, true]);
    sub.close();
  });

  test('listeners receive updates from setFullscreen + toggle', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(windowFullscreenProvider.notifier);
    final emissions = <bool>[];
    final sub = container.listen<dynamic>(
      windowFullscreenProvider,
      (_, next) => emissions.add(next as bool),
      fireImmediately: true,
    );
    await notifier.setFullscreen(true);
    await notifier.toggle();
    await notifier.setFullscreen(true);
    await notifier.toggle();
    expect(emissions, [false, true, false, true, false]);
    sub.close();
  });
}
