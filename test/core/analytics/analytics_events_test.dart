// Catalog contract sync (spec 046, contracts/event-catalog.md): every code
// constant stays inside the documented closed vocabulary — snake_case names,
// no duplicates, and every builder emitting only allowlisted property keys.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/analytics/analytics_events.dart';

void main() {
  group('event names', () {
    test('are snake_case object_verb strings, unique', () {
      final names = AnalyticsEvents.all;
      expect(names, isNotEmpty);
      expect(names.toSet(), hasLength(names.length));
      final pattern = RegExp(r'^[a-z]+(_[a-z]+)+$');
      for (final name in names) {
        expect(pattern.hasMatch(name), isTrue, reason: name);
      }
    });
  });

  group('property builders', () {
    test('emit only allowlisted property keys', () {
      final allowlist = AnalyticsEvents.propertyKeys.toSet();
      final samples = <Map<String, Object>>[
        AnalyticsEvents.practiceStarted(
          surface: 'shadow_reading',
          itemCount: 1,
        ),
        AnalyticsEvents.practiceCompleted(
          surface: 'flashcard',
          durationSeconds: 10,
          itemsCompleted: 1,
        ),
        AnalyticsEvents.transcriptRequested(source: 'asr', mediaKind: 'video'),
        AnalyticsEvents.transcriptRequested(source: 'youtube'),
        AnalyticsEvents.transcriptCompleted(
          source: 'local_file',
          durationSeconds: 1,
        ),
        AnalyticsEvents.transcriptFailed(
          source: 'asr',
          reason: AnalyticsFailureReason.credits,
        ),
        AnalyticsEvents.lookupPerformed(source: 'selection', cacheHit: false),
        AnalyticsEvents.translationRequestedProps(
          kind: 'contextual',
          cacheHit: true,
        ),
        AnalyticsEvents.craftCreated(mode: 'capture'),
        AnalyticsEvents.craftCompleted(durationSeconds: 30),
        AnalyticsEvents.vocabularyReview(reviewedCount: 5, correctCount: 4),
        AnalyticsEvents.purchaseStarted(tier: 'pro'),
        AnalyticsEvents.purchaseCompleted(tier: 'pro'),
        AnalyticsEvents.creditsPurchased(packageId: 'pkg-1'),
      ];
      for (final properties in samples) {
        for (final key in properties.keys) {
          expect(allowlist.contains(key), isTrue, reason: key);
        }
      }
    });

    test('failure reasons are a closed enum; names are the payload', () {
      expect(AnalyticsFailureReason.values.map((r) => r.name).toSet(), {
        'network',
        'credits',
        'auth',
        'server',
        'local',
        'cancelled',
        'unknown',
      });
    });
  });
}
