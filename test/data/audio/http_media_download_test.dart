import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:enjoy_player/data/audio/http_media_download.dart';

void main() {
  test('downloadHttpMediaToTemp writes bytes and cleans up', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://cdn.example/a.mp3');
      return http.Response.bytes([1, 2, 3, 4], 200);
    });
    final path = await downloadHttpMediaToTemp(
      'https://cdn.example/a.mp3',
      client: client,
    );
    addTearDown(() => deleteDownloadedHttpMedia(path));
    expect(File(path).existsSync(), isTrue);
    expect(File(path).readAsBytesSync(), [1, 2, 3, 4]);
    expect(path.endsWith('.mp3'), isTrue);

    await deleteDownloadedHttpMedia(path);
    expect(File(path).existsSync(), isFalse);
  });

  test('downloadHttpMediaToTemp fails closed on HTTP error', () async {
    final client = MockClient((request) async {
      return http.Response('nope', 404);
    });
    await expectLater(
      downloadHttpMediaToTemp(
        'https://cdn.example/missing.mp3',
        client: client,
      ),
      throwsA(isA<HttpMediaDownloadException>()),
    );
  });

  test('downloadHttpMediaToTemp respects cancel before send', () async {
    final cancel = AlignmentCancelToken()..cancel();
    final client = MockClient((request) async {
      fail('must not send after cancel');
    });
    await expectLater(
      downloadHttpMediaToTemp(
        'https://cdn.example/a.mp3',
        client: client,
        cancel: cancel,
      ),
      throwsA(isA<HttpMediaDownloadException>()),
    );
  });
}
