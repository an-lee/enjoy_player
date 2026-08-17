import 'dart:io';

import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'transcript presentation, player, ASR, lookup, Settings, and l10n do not import forced_alignment',
    () {
      const roots = [
        'lib/features/transcript/presentation',
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

  test('transcript application enricher may import forced_alignment', () {
    final file = File(
      'lib/features/transcript/application/transcript_enrichment_controller.dart',
    );
    expect(file.existsSync(), isTrue);
    expect(
      file.readAsStringSync().contains('package:forced_alignment/'),
      isTrue,
    );
  });

  test(
    'Craft, subtitle mapper, and PCM helper may import forced_alignment',
    () {
      const allowed = [
        'lib/features/craft',
        'lib/data/subtitle',
        'lib/data/audio',
      ];
      var anyImport = false;
      for (final root in allowed) {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final text = entity.readAsStringSync();
          if (text.contains('package:forced_alignment/')) {
            anyImport = true;
          }
        }
      }
      expect(anyImport, isTrue);
    },
  );

  test('transcript.timelineEnrichment settings key is allowlisted', () {
    expect(
      SettingsKeys.transcriptTimelineEnrichment,
      'transcript.timelineEnrichment',
    );
    expect(
      SettingsKeys.isKnown(SettingsKeys.transcriptTimelineEnrichment),
      isTrue,
    );
    final settings = File('lib/data/db/settings_keys.dart').readAsStringSync();
    expect(settings.contains('transcript.timelineEnrichment'), isTrue);
  });

  test('transcript.karaokeHighlight settings key is allowlisted', () {
    expect(
      SettingsKeys.transcriptKaraokeHighlight,
      'transcript.karaokeHighlight',
    );
    expect(
      SettingsKeys.isKnown(SettingsKeys.transcriptKaraokeHighlight),
      isTrue,
    );
    final settings = File('lib/data/db/settings_keys.dart').readAsStringSync();
    expect(settings.contains('transcript.karaokeHighlight'), isTrue);
  });

  test('transcript IPA overlay and word practice keys are allowlisted', () {
    expect(SettingsKeys.transcriptIpaOverlay, 'transcript.ipaOverlay');
    expect(SettingsKeys.transcriptWordPractice, 'transcript.wordPractice');
    expect(SettingsKeys.isKnown(SettingsKeys.transcriptIpaOverlay), isTrue);
    expect(SettingsKeys.isKnown(SettingsKeys.transcriptWordPractice), isTrue);
    final settings = File('lib/data/db/settings_keys.dart').readAsStringSync();
    expect(settings.contains('transcript.ipaOverlay'), isTrue);
    expect(settings.contains('transcript.wordPractice'), isTrue);
  });
}
