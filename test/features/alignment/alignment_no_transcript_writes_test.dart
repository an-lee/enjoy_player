import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forced_alignment sources do not import Drift or transcript DAOs', () {
    final dir = Directory('packages/forced_alignment/lib');
    expect(dir.existsSync(), isTrue);
    final hits = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      if (text.contains('package:drift/') ||
          text.contains('app_database') ||
          text.contains('transcript_repository') ||
          text.contains('package:enjoy_player/')) {
        hits.add(entity.path);
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
