import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Craft, transcript, player, ASR, lookup, and Settings do not import forced_alignment',
    () {
      const roots = [
        'lib/features/craft',
        'lib/features/transcript',
        'lib/features/player',
        'lib/features/asr',
        'lib/features/lookup',
        'lib/features/settings',
        'lib/l10n',
      ];
      final hits = <String>[];
      for (final root in roots) {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final text = entity.readAsStringSync();
          if (text.contains('package:forced_alignment/')) {
            hits.add(entity.path);
          }
        }
      }
      expect(hits, isEmpty, reason: hits.join('\n'));
    },
  );

  test('no transcript.timelineEnrichment settings key', () {
    final settings = File('lib/data/db/settings_keys.dart').readAsStringSync();
    expect(settings.contains('timelineEnrichment'), isFalse);
    expect(settings.contains('transcript.timeline'), isFalse);
  });
}
