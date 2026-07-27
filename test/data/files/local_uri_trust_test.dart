import 'dart:io';

import 'package:enjoy_player/data/files/local_uri_trust.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('localUriTrusted requires existing file', () async {
    final missing = Uri.file(
      p.join(Directory.systemTemp.path, 'enjoy_missing_trust.bin'),
    ).toString();
    expect(
      await localUriTrusted(
        localUri: missing,
        storedSize: 1,
        storedMtimeMs: null,
      ),
      isFalse,
    );
    expect(
      await localUriTrusted(
        localUri: null,
        storedSize: null,
        storedMtimeMs: null,
      ),
      isFalse,
    );
  });

  test('localUriTrusted accepts matching size and optional mtime', () async {
    final root = Directory.systemTemp.createTempSync('enjoy_trust');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final file = File(p.join(root.path, 'a.bin'));
    await file.writeAsBytes([1, 2, 3, 4]);
    final stat = await file.stat();
    final uri = Uri.file(file.path).toString();

    expect(
      await localUriTrusted(
        localUri: uri,
        storedSize: 4,
        storedMtimeMs: stat.modified.millisecondsSinceEpoch,
      ),
      isTrue,
    );
    expect(
      await localUriTrusted(localUri: uri, storedSize: 4, storedMtimeMs: null),
      isTrue,
    );
    // Production may store a bare filesystem path (not a file: URI).
    expect(
      await localUriTrusted(
        localUri: file.path,
        storedSize: 4,
        storedMtimeMs: null,
      ),
      isTrue,
    );
  });

  test('localUriTrusted rejects size or mtime mismatch', () async {
    final root = Directory.systemTemp.createTempSync('enjoy_trust');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final file = File(p.join(root.path, 'b.bin'));
    await file.writeAsBytes([1, 2, 3]);
    final stat = await file.stat();
    final uri = Uri.file(file.path).toString();

    expect(
      await localUriTrusted(localUri: uri, storedSize: 99, storedMtimeMs: null),
      isFalse,
    );
    expect(
      await localUriTrusted(
        localUri: uri,
        storedSize: 3,
        storedMtimeMs: stat.modified.millisecondsSinceEpoch + 1,
      ),
      isFalse,
    );
  });
}
