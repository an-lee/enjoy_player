import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/player/player_surface_overlay_coordinator.dart';
import 'package:enjoy_player/core/player/player_surface_overlay_navigator_observer.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerSurfaceOverlayCoordinator', () {
    test('shouldPark is false until a token is acquired', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(playerSurfaceShouldParkForOverlayProvider),
        isFalse,
      );

      final coordinator = container.read(
        playerSurfaceOverlayCoordinatorProvider.notifier,
      );
      final token = coordinator.acquire('test');
      expect(container.read(playerSurfaceShouldParkForOverlayProvider), isTrue);

      coordinator.release(token);
      expect(
        container.read(playerSurfaceShouldParkForOverlayProvider),
        isFalse,
      );
    });

    test('multiple tokens keep shouldPark true until all released', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final coordinator = container.read(
        playerSurfaceOverlayCoordinatorProvider.notifier,
      );

      final a = coordinator.acquire('a');
      final b = coordinator.acquire('b');
      expect(container.read(playerSurfaceShouldParkForOverlayProvider), isTrue);

      coordinator.release(a);
      expect(container.read(playerSurfaceShouldParkForOverlayProvider), isTrue);

      coordinator.release(b);
      expect(
        container.read(playerSurfaceShouldParkForOverlayProvider),
        isFalse,
      );
    });

    test('release of unknown token is a no-op', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final coordinator = container.read(
        playerSurfaceOverlayCoordinatorProvider.notifier,
      );

      final token = coordinator.acquire('keep');
      coordinator.release(Object());
      expect(container.read(playerSurfaceShouldParkForOverlayProvider), isTrue);
      coordinator.release(token);
      expect(
        container.read(playerSurfaceShouldParkForOverlayProvider),
        isFalse,
      );
    });
  });

  group('PlayerSurfaceOverlayNavigatorObserver', () {
    testWidgets('dialog push/pop acquires and releases overlay token', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final observer = PlayerSurfaceOverlayNavigatorObserver(
        coordinator: () =>
            container.read(playerSurfaceOverlayCoordinatorProvider.notifier),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [observer],
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () {
                      unawaited(
                        showEnjoyAlertDialog<void>(
                          context: context,
                          title: const Text('Park me'),
                          content: const Text('body'),
                          actionsBuilder: (ctx) => [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(
        container.read(playerSurfaceShouldParkForOverlayProvider),
        isFalse,
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Park me'), findsOneWidget);
      expect(container.read(playerSurfaceShouldParkForOverlayProvider), isTrue);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(
        container.read(playerSurfaceShouldParkForOverlayProvider),
        isFalse,
      );
    });

    testWidgets('sheet push/pop acquires and releases overlay token', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final observer = PlayerSurfaceOverlayNavigatorObserver(
        coordinator: () =>
            container.read(playerSurfaceOverlayCoordinatorProvider.notifier),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [observer],
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () {
                      unawaited(
                        showEnjoySheet<void>(
                          context: context,
                          builder: (ctx) => SizedBox(
                            height: 120,
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Dismiss sheet'),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open sheet'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      expect(container.read(playerSurfaceShouldParkForOverlayProvider), isTrue);

      await tester.tap(find.text('Dismiss sheet'));
      await tester.pumpAndSettle();
      expect(
        container.read(playerSurfaceShouldParkForOverlayProvider),
        isFalse,
      );
    });
  });
}
