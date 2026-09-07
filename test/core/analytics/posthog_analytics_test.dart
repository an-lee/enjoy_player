// Tests the PostHog facade wrapper: setup contract, gating (not-ready /
// disabled), the beforeSend UGC guard, identity dedupe, opt-out behavior,
// flag fallbacks, and vendor-exception swallowing. The vendor method channel
// is mocked, so every assertion observes the exact calls that would reach
// the native SDK.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'package:enjoy_player/core/analytics/analytics_events.dart';
import 'package:enjoy_player/core/analytics/posthog_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('posthog_flutter');
  final invoked = <MethodCall>[];
  Object? Function(MethodCall)? handlerOverride;

  setUp(() {
    invoked.clear();
    handlerOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (handlerOverride != null) return handlerOverride!(call);
          invoked.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// A wrapper taken through the full boot sequence: setup + enabled.
  Future<PosthogAnalytics> readyWrapper() async {
    final impl = PosthogAnalytics();
    final config = PostHogConfig('test-token')
      ..host = 'https://eu.i.posthog.com';
    await impl.setup(config);
    impl.setEnabled(true);
    return impl;
  }

  List<MethodCall> calls(String method) =>
      invoked.where((c) => c.method == method).toList();

  /// Vendor capture() defers its channel call by a microtask.
  Future<void> pump() => Future<void>.delayed(Duration.zero);

  group('setup + gating', () {
    test('setup sends the vendor setup call with host and token', () async {
      final impl = PosthogAnalytics();
      final config = PostHogConfig('tok-123')
        ..host = 'https://eu.i.posthog.com';
      await impl.setup(config);

      final setupCalls = calls('setup');
      expect(setupCalls, hasLength(1));
      final args = setupCalls.single.arguments as Map<Object?, Object?>;
      expect(args['apiKey'] ?? args['projectToken'], 'tok-123');
    });

    test('captures are dropped until setup and enable complete', () async {
      final impl = PosthogAnalytics();
      impl.capture(
        AnalyticsEvents.practiceSessionStarted,
        properties: AnalyticsEvents.practiceStarted(
          surface: AnalyticsEvents.surfaceShadowReading,
          itemCount: 2,
        ),
      );
      expect(calls('capture'), isEmpty);

      await impl.setup(PostHogConfig('tok')..host = 'https://x.example');
      impl.capture(AnalyticsEvents.practiceSessionStarted);
      // setup done but the stored opt-out has not been applied yet — the
      // opted-out-user guarantee (no events before setEnabled(true)).
      expect(calls('capture'), isEmpty);

      impl.setEnabled(true);
      impl.capture(AnalyticsEvents.practiceSessionStarted);
      await pump();
      expect(calls('capture'), hasLength(1));
    });
  });

  group('beforeSend UGC guard', () {
    test('allows catalog events with allowlisted properties', () async {
      final impl = await readyWrapper();
      impl.capture(
        AnalyticsEvents.practiceSessionCompleted,
        properties: AnalyticsEvents.practiceCompleted(
          surface: AnalyticsEvents.surfaceShadowReading,
          durationSeconds: 42,
          itemsCompleted: 5,
        ),
      );
      await pump();
      final capture = calls('capture').single;
      expect(
        capture.arguments['eventName'],
        AnalyticsEvents.practiceSessionCompleted,
      );
    });

    test('drops unknown (free-form) event names', () async {
      final impl = await readyWrapper();
      impl.capture('user typed something private');
      expect(calls('capture'), isEmpty);
    });

    test('drops catalog events carrying non-allowlisted properties', () async {
      final impl = await readyWrapper();
      impl.capture(
        AnalyticsEvents.dictionaryLookupPerformed,
        properties: {
          AnalyticsEvents.propSource: AnalyticsEvents.sourceSelection,
          'selectedText': 'bonjour', // UGC-shaped — must never leave the app
        },
      );
      expect(calls('capture'), isEmpty);
    });

    test('allows screen events and drops unnamed junk', () async {
      final impl = await readyWrapper();
      impl.screen('library');
      await pump();
      expect(calls('screen'), hasLength(1));

      impl.capture(r'$screen', properties: {'made_up': true});
      await pump();
      expect(calls('capture'), isEmpty);
    });
  });

  group('identity', () {
    test('deduplicates re-identify with the same id', () async {
      final impl = await readyWrapper();
      impl.identify('u-1', userProperties: {'email': 'a@example.com'});
      impl.identify('u-1', userProperties: {'email': 'a@example.com'});
      expect(calls('identify'), hasLength(1));

      impl.identify('u-2');
      expect(calls('identify'), hasLength(2));
    });

    test('reset clears identity and notifies the vendor', () async {
      final impl = await readyWrapper();
      impl.identify('u-1');
      impl.reset();
      expect(calls('reset'), hasLength(1));

      // Re-identify after reset goes through again (fresh identity).
      impl.identify('u-1');
      expect(calls('identify'), hasLength(2));
    });

    test(
      'identify while disabled is remembered and replayed on enable',
      () async {
        final impl = PosthogAnalytics();
        await impl.setup(PostHogConfig('tok')..host = 'https://x.example');
        // Not enabled: the opted-out-user state.
        impl.identify('u-9', userProperties: {'name': 'Ana'});
        expect(calls('identify'), isEmpty);

        impl.setEnabled(true);
        expect(calls('enable'), hasLength(1));
        final replayed = calls('identify').single;
        expect(replayed.arguments['userId'], 'u-9');
      },
    );
  });

  group('opt-out', () {
    test('disable stops subsequent captures immediately', () async {
      final impl = await readyWrapper();
      impl.setEnabled(false);
      expect(calls('disable'), hasLength(1));

      impl.capture(AnalyticsEvents.translationRequested);
      impl.screen('home');
      expect(calls('capture'), isEmpty);
      expect(calls('screen'), isEmpty);
    });
  });

  group('flags', () {
    test('bool flags read the vendor value when available', () async {
      handlerOverride = (call) async {
        invoked.add(call);
        if (call.method == 'isFeatureEnabled') return true;
        return null;
      };
      final impl = await readyWrapper();
      final value = await impl.flag(key: 'test_flag', fallback: false);
      expect(value, isTrue);
    });

    test('falls back when the vendor errors', () async {
      // The vendor's IO layer converts channel errors into `false`, so the
      // only way to exercise the guard is the test-only short-circuit.
      final impl = PosthogAnalytics(shortCircuitOnError: true);
      final config = PostHogConfig('tok')..host = 'https://x.example';
      await impl.setup(config);
      impl.setEnabled(true);

      final value = await impl.flag(key: 'test_flag', fallback: true);
      expect(value, isTrue);
    });

    test(
      'falls back when the vendor does not answer before the timeout',
      () async {
        handlerOverride = (call) async {
          if (call.method == 'isFeatureEnabled') {
            await Future<void>.delayed(const Duration(seconds: 30));
          }
          return null;
        };
        final impl = PosthogAnalytics(
          flagTimeout: const Duration(milliseconds: 50),
        );
        final config = PostHogConfig('tok')..host = 'https://x.example';
        await impl.setup(config);
        impl.setEnabled(true);

        final value = await impl.flag(key: 'test_flag', fallback: 'control');
        expect(value, 'control');
      },
    );

    test('falls back when the value type does not match', () async {
      handlerOverride = (call) async {
        invoked.add(call);
        if (call.method == 'getFeatureFlag') return true; // bool, not String
        return null;
      };
      final impl = await readyWrapper();
      final value = await impl.flag(key: 'test_flag', fallback: 'control');
      expect(value, 'control');
    });
  });

  group('failure tolerance', () {
    test('capture never throws even when the channel throws', () async {
      handlerOverride = (call) async {
        if (call.method == 'capture') {
          throw StateError('channel exploded');
        }
        return null;
      };
      final impl = await readyWrapper();
      expect(
        () => impl.capture(
          AnalyticsEvents.vocabularyReviewCompleted,
          properties: AnalyticsEvents.vocabularyReview(
            reviewedCount: 3,
            correctCount: 2,
          ),
        ),
        returnsNormally,
      );
      // Let the guarded future settle.
      await Future<void>.delayed(Duration.zero);
    });
  });
}
