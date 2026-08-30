import 'package:enjoy_player/core/player/player_surface_overlay_coordinator.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_surface_registry.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_stage_resolver.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_surface_host.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_surface_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_player_engine.dart';

/// Stage mapping the host under test mounts: a keyed box whose geometry and
/// element identity the assertions read. Widget building left the engine
/// (issue #664), so the seam is injected into the host instead of overridden
/// on the engine.
PlayerStageBuilder _keyedStageBuilder() =>
    (engine, {required double maxWidth, required double maxHeight}) {
      final keyed = engine as _KeyedSurfaceEngine;
      keyed.lastMaxWidth = maxWidth;
      keyed.lastMaxHeight = maxHeight;
      return ColoredBox(key: keyed.surfaceKey, color: Colors.black);
    };

class _KeyedSurfaceEngine extends FakePlayerEngine {
  final surfaceKey = GlobalKey();
  double? lastMaxWidth;
  double? lastMaxHeight;
}

class _ParklessSurfaceEngine extends _KeyedSurfaceEngine {
  @override
  bool get keepSurfaceWhenParked => false;
}

void main() {
  testWidgets(
    'target detach and reattach never reparents keyed engine surface',
    (tester) async {
      final engine = _KeyedSurfaceEngine();
      addTearDown(engine.dispose);
      final enabled = ValueNotifier<bool>(true);
      addTearDown(enabled.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [playerEngineTestDoubleProvider.overrideWithValue(engine)],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: SizedBox(
                      width: 320,
                      height: 180,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: enabled,
                        builder: (context, value, _) {
                          return PlayerSurfaceTarget(
                            id: PlayerSurfaceIds.vocabularyClip,
                            enabled: value,
                            child: const ColoredBox(color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                  PlayerSurfaceHost(stageBuilder: _keyedStageBuilder()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final originalElement = engine.surfaceKey.currentContext;
      expect(originalElement, isNotNull);

      enabled.value = false;
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(engine.surfaceKey.currentContext, same(originalElement));

      enabled.value = true;
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(engine.surfaceKey.currentContext, same(originalElement));
    },
  );

  testWidgets(
    'forcePark parks stage left of origin even when a target is attached',
    (tester) async {
      final engine = _KeyedSurfaceEngine();
      addTearDown(engine.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [playerEngineTestDoubleProvider.overrideWithValue(engine)],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 320,
                      height: 180,
                      child: PlayerSurfaceTarget(
                        id: PlayerSurfaceIds.expandedPlayer,
                        child: ColoredBox(color: Colors.grey),
                      ),
                    ),
                  ),
                  PlayerSurfaceHost(
                    forcePark: true,
                    stageBuilder: _keyedStageBuilder(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(engine.surfaceKey.currentContext, isNotNull);

      final box =
          engine.surfaceKey.currentContext!.findRenderObject()! as RenderBox;
      final origin = box.localToGlobal(Offset.zero);
      // Parked at Offset(-size.width - 64, 0) — must not sit on the target.
      expect(origin.dx, lessThan(0));
    },
  );

  testWidgets(
    'parked YouTube surface keeps the live target size (no 320×180 shrink)',
    (tester) async {
      // Field: every CC-sheet round-trip (toggling IPA) used to shrink the
      // WebView from the on-screen stage (e.g. 400×225) to the 320×180 park
      // fallback. m.youtube.com treats 320 px as a compact-player breakpoint,
      // flushes ABR, and then pauses every programmatic play within ~0.5 s.
      final engine = _KeyedSurfaceEngine();
      addTearDown(engine.dispose);
      const targetSize = Size(400, 225);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [playerEngineTestDoubleProvider.overrideWithValue(engine)],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 400,
                      height: 225,
                      child: PlayerSurfaceTarget(
                        id: PlayerSurfaceIds.expandedPlayer,
                        child: ColoredBox(color: Colors.grey),
                      ),
                    ),
                  ),
                  PlayerSurfaceHost(
                    forcePark: true,
                    stageBuilder: _keyedStageBuilder(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(engine.lastMaxWidth, targetSize.width);
      expect(engine.lastMaxHeight, targetSize.height);

      final box =
          engine.surfaceKey.currentContext!.findRenderObject()! as RenderBox;
      expect(box.size, targetSize);
      final origin = box.localToGlobal(Offset.zero);
      expect(origin.dx, lessThanOrEqualTo(-targetSize.width));
    },
  );

  testWidgets('overlay park then unpark does not change YouTube stage size', (
    tester,
  ) async {
    final engine = _KeyedSurfaceEngine();
    addTearDown(engine.dispose);
    final container = ProviderContainer(
      overrides: [playerEngineTestDoubleProvider.overrideWithValue(engine)],
    );
    addTearDown(container.dispose);
    const targetSize = Size(400, 225);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 400,
                    height: 225,
                    child: PlayerSurfaceTarget(
                      id: PlayerSurfaceIds.expandedPlayer,
                      child: ColoredBox(color: Colors.grey),
                    ),
                  ),
                ),
                // No `forcePark` here: the host watches the overlay coordinator
                // itself (issue #663), which is what these assertions cover.
                PlayerSurfaceHost(stageBuilder: _keyedStageBuilder()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(engine.lastMaxWidth, targetSize.width);
    expect(engine.lastMaxHeight, targetSize.height);
    final attachedBox =
        engine.surfaceKey.currentContext!.findRenderObject()! as RenderBox;
    expect(attachedBox.size, targetSize);
    expect(attachedBox.localToGlobal(Offset.zero).dx, greaterThanOrEqualTo(0));

    final token = container
        .read(playerSurfaceOverlayCoordinatorProvider.notifier)
        .acquire('cc-sheet');
    await tester.pump();
    await tester.pump();

    expect(engine.lastMaxWidth, targetSize.width);
    expect(engine.lastMaxHeight, targetSize.height);
    final parkedBox =
        engine.surfaceKey.currentContext!.findRenderObject()! as RenderBox;
    expect(parkedBox.size, targetSize);
    expect(parkedBox.localToGlobal(Offset.zero).dx, lessThan(0));

    container
        .read(playerSurfaceOverlayCoordinatorProvider.notifier)
        .release(token);
    await tester.pump();
    await tester.pump();

    expect(engine.lastMaxWidth, targetSize.width);
    expect(engine.lastMaxHeight, targetSize.height);
    final restoredBox =
        engine.surfaceKey.currentContext!.findRenderObject()! as RenderBox;
    expect(restoredBox.size, targetSize);
    expect(restoredBox.localToGlobal(Offset.zero).dx, greaterThanOrEqualTo(0));
  });

  testWidgets(
    'overlay coordinator token parks stage without reparenting the surface',
    (tester) async {
      final engine = _KeyedSurfaceEngine();
      addTearDown(engine.dispose);
      final container = ProviderContainer(
        overrides: [playerEngineTestDoubleProvider.overrideWithValue(engine)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 320,
                      height: 180,
                      child: PlayerSurfaceTarget(
                        id: PlayerSurfaceIds.expandedPlayer,
                        child: ColoredBox(color: Colors.grey),
                      ),
                    ),
                  ),
                  // No `forcePark`: the host reads the coordinator itself
                  // (issue #663), so the token below must park it.
                  PlayerSurfaceHost(stageBuilder: _keyedStageBuilder()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final originalElement = engine.surfaceKey.currentContext;
      expect(originalElement, isNotNull);
      final attachedBox =
          engine.surfaceKey.currentContext!.findRenderObject()! as RenderBox;
      expect(
        attachedBox.localToGlobal(Offset.zero).dx,
        greaterThanOrEqualTo(0),
      );

      final token = container
          .read(playerSurfaceOverlayCoordinatorProvider.notifier)
          .acquire('notice');
      await tester.pump();
      await tester.pump();

      expect(engine.surfaceKey.currentContext, same(originalElement));
      final parkedBox =
          engine.surfaceKey.currentContext!.findRenderObject()! as RenderBox;
      expect(parkedBox.localToGlobal(Offset.zero).dx, lessThan(0));

      container
          .read(playerSurfaceOverlayCoordinatorProvider.notifier)
          .release(token);
      await tester.pump();
      await tester.pump();

      expect(engine.surfaceKey.currentContext, same(originalElement));
      final restoredBox =
          engine.surfaceKey.currentContext!.findRenderObject()! as RenderBox;
      expect(
        restoredBox.localToGlobal(Offset.zero).dx,
        greaterThanOrEqualTo(0),
      );
    },
  );

  testWidgets(
    'host follows target translation even when size does not change',
    (tester) async {
      final engine = _KeyedSurfaceEngine();
      addTearDown(engine.dispose);
      final dx = ValueNotifier<double>(0);
      addTearDown(dx.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [playerEngineTestDoubleProvider.overrideWithValue(engine)],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: dx,
                    builder: (context, value, _) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Transform.translate(
                          offset: Offset(value, 0),
                          child: const SizedBox(
                            width: 320,
                            height: 180,
                            child: PlayerSurfaceTarget(
                              id: PlayerSurfaceIds.expandedPlayer,
                              child: ColoredBox(color: Colors.grey),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  PlayerSurfaceHost(stageBuilder: _keyedStageBuilder()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final before =
          engine.surfaceKey.currentContext!.findRenderObject()! as RenderBox;
      final beforeDx = before.localToGlobal(Offset.zero).dx;

      dx.value = 48;
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      final after =
          engine.surfaceKey.currentContext!.findRenderObject()! as RenderBox;
      expect(after.localToGlobal(Offset.zero).dx, closeTo(beforeDx + 48, 0.5));
    },
  );

  testWidgets(
    'engine that does not keep a parked surface is unmounted until attached',
    (tester) async {
      final engine = _ParklessSurfaceEngine();
      addTearDown(engine.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [playerEngineTestDoubleProvider.overrideWithValue(engine)],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  PlayerSurfaceHost(stageBuilder: _keyedStageBuilder()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(engine.surfaceKey.currentContext, isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [playerEngineTestDoubleProvider.overrideWithValue(engine)],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 320,
                      height: 180,
                      child: PlayerSurfaceTarget(
                        id: PlayerSurfaceIds.expandedPlayer,
                        child: ColoredBox(color: Colors.grey),
                      ),
                    ),
                  ),
                  PlayerSurfaceHost(stageBuilder: _keyedStageBuilder()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(engine.surfaceKey.currentContext, isNotNull);
      final box =
          engine.surfaceKey.currentContext!.findRenderObject()! as RenderBox;
      expect(box.localToGlobal(Offset.zero).dx, greaterThanOrEqualTo(0));
    },
  );

  testWidgets(
    'replacing the expanded-player target does not unmount a parkless surface',
    (tester) async {
      final engine = _ParklessSurfaceEngine();
      addTearDown(engine.dispose);
      final loading = ValueNotifier(true);
      addTearDown(loading.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [playerEngineTestDoubleProvider.overrideWithValue(engine)],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: loading,
                    builder: (context, isLoading, _) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: isLoading ? 400 : 240,
                          height: isLoading ? 180 : 400,
                          child: PlayerSurfaceTarget(
                            id: PlayerSurfaceIds.expandedPlayer,
                            child: ColoredBox(
                              color: isLoading ? Colors.grey : Colors.blue,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  PlayerSurfaceHost(stageBuilder: _keyedStageBuilder()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final original = engine.surfaceKey.currentContext;
      expect(original, isNotNull);

      loading.value = false;
      await tester.pump();
      await tester.pump();

      expect(engine.surfaceKey.currentContext, same(original));
      expect(tester.takeException(), isNull);
    },
  );
}
