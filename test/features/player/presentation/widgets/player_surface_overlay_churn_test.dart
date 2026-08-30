// Issue #663 (rebuild scope, item C): the expanded-player chrome must not
// churn the surface registry.
//
// `_VideoStageWithChrome` used to allocate a fresh `overlayBuilder` closure on
// every build. `PlayerSurfaceTarget` compares builders by identity, so every
// ancestor rebuild handed the registry a "new" chrome and re-created the
// attachment — including each splitter-drag pointer move, where the video
// column resizes at pointer-move rate.
//
// Structural signals (docs/perf-measurement.md): registry write counts and
// widget-instance identity, both deterministic — no wall-clock timing.
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/player/application/player_surface_registry.dart';
import 'package:enjoy_player/features/player/presentation/layouts/video_player_layout.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_player_engine.dart';

/// Registry double that counts entry into each mutation.
class _CountingRegistry extends PlayerSurfaceRegistry {
  int attachCalls = 0;
  int updateCalls = 0;

  @override
  void attach(PlayerSurfaceAttachment attachment) {
    attachCalls++;
    super.attach(attachment);
  }

  @override
  void update({
    required String id,
    Offset? offset,
    Size? size,
    PlayerSurfaceOverlayBuilder? overlayBuilder,
    bool clearOverlay = false,
  }) {
    updateCalls++;
    super.update(
      id: id,
      offset: offset,
      size: size,
      overlayBuilder: overlayBuilder,
      clearOverlay: clearOverlay,
    );
  }
}

Future<
  ({
    ProviderContainer container,
    _CountingRegistry registry,
    ValueNotifier<int> rebuildLayout,
  })
>
_pump(WidgetTester tester, {required FakePlayerEngine engine}) async {
  final container = ProviderContainer(
    overrides: [
      playerEngineTestDoubleProvider.overrideWithValue(engine),
      playerSurfaceRegistryProvider.overrideWith(_CountingRegistry.new),
    ],
  );
  final registry =
      container.read(playerSurfaceRegistryProvider.notifier)
          as _CountingRegistry;
  addTearDown(container.dispose);

  final view = tester.view;
  view.physicalSize = const Size(900 * 3, 600 * 3);
  view.devicePixelRatio = 3;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);

  // Bumping this re-creates [VideoPlayerLayout] — and therefore
  // `_VideoStageWithChrome` — without changing any geometry.
  final rebuildLayout = ValueNotifier<int>(0);
  addTearDown(rebuildLayout.dispose);

  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: scheme,
          extensions: [EnjoyThemeTokens.build(scheme)],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 900,
              height: 600,
              child: ValueListenableBuilder<int>(
                valueListenable: rebuildLayout,
                builder: (context, _, _) => VideoPlayerLayout(
                  engine: engine,
                  transcript: const Text('TR_STUB'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // Two frames: first layout, then the post-frame `_sync` retry that attaches
  // once the target has a real size.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  return (
    container: container,
    registry: registry,
    rebuildLayout: rebuildLayout,
  );
}

/// Fires one splitter drag frame of [dx] logical pixels.
void _dragSplitter(WidgetTester tester, double dx) {
  final splitter = tester.widget<GestureDetector>(
    find.byWidgetPredicate(
      (w) =>
          w is GestureDetector &&
          w.onHorizontalDragUpdate != null &&
          w.onHorizontalDragEnd != null &&
          w.behavior == HitTestBehavior.translucent,
    ),
  );
  splitter.onHorizontalDragUpdate!(
    DragUpdateDetails(globalPosition: Offset.zero, delta: Offset(dx, 0)),
  );
}

void main() {
  testWidgets(
    'an ancestor rebuild without a geometry change writes nothing to the registry',
    (tester) async {
      final engine = FakePlayerEngine();
      addTearDown(engine.dispose);
      final (:container, :registry, :rebuildLayout) = await _pump(
        tester,
        engine: engine,
      );

      final afterAttach = registry.updateCalls;
      final attachment = container.read(playerSurfaceRegistryProvider);
      expect(attachment, isNotNull);

      // Re-run the ancestor build five times without touching geometry. The
      // chrome builder is identity-stable now, so `PlayerSurfaceTarget` has no
      // reason to even schedule a sync.
      for (var i = 0; i < 5; i++) {
        rebuildLayout.value++;
        await tester.pump();
        await tester.pump();
      }

      expect(registry.updateCalls, afterAttach);
      expect(
        container.read(playerSurfaceRegistryProvider),
        same(attachment),
        reason: 'A no-op ancestor rebuild must not re-create the attachment',
      );
    },
  );

  testWidgets(
    'splitter drag keeps the registered chrome builder identity-stable',
    (tester) async {
      final engine = FakePlayerEngine();
      addTearDown(engine.dispose);
      final (:container, :registry, :rebuildLayout) = await _pump(
        tester,
        engine: engine,
      );
      // Unused here; the drag is what drives the rebuilds.
      expect(rebuildLayout.value, 0);

      final builderBefore = container
          .read(playerSurfaceRegistryProvider)!
          .overlayBuilder;
      expect(builderBefore, isNotNull);

      // Six pointer moves: the video column resizes each frame, so the target
      // geometry genuinely changes and the host must follow. What must NOT
      // happen is the chrome being re-registered alongside it.
      var updatesDuringDrag = 0;
      for (var i = 0; i < 6; i++) {
        final before = registry.updateCalls;
        _dragSplitter(tester, -12);
        await tester.pump();
        await tester.pump();
        updatesDuringDrag += registry.updateCalls - before;
      }

      final after = container
          .read(playerSurfaceRegistryProvider)!
          .overlayBuilder;
      expect(
        identical(builderBefore, after),
        isTrue,
        reason:
            'The chrome builder must survive a splitter drag; a fresh closure '
            'per build defeats the registry delta gate (issue #663)',
      );
      // The drag did move the surface — following geometry is still required.
      expect(updatesDuringDrag, greaterThan(0));
    },
  );
}
