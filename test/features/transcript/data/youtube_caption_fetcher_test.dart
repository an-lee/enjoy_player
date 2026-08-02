import 'dart:convert';

import 'package:enjoy_player/features/transcript/data/youtube_caption_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Returns canned InnerTube /player JSON for a video with caption tracks.
Map<String, dynamic> _cannedPlayerResponse({
  String status = 'OK',
  List<Map<String, dynamic>> tracks = const [],
}) {
  return {
    'playabilityStatus': {'status': status},
    'captions': {
      'playerCaptionsTracklistRenderer': {'captionTracks': tracks},
    },
  };
}

/// Returns canned json3 caption track data.
String _cannedJson3Response(List<Map<String, dynamic>> events) {
  return jsonEncode({'events': events});
}

void main() {
  late http.Client mockClient;

  setUp(() {
    resetLastSuccessfulCaptionProfile();
    mockClient = MockClient((request) async {
      return http.Response('', 500);
    });
  });

  group('YoutubeCaptionFetcher', () {
    test('fetchSubtitles returns captions for a valid video', () async {
      const captionUrl = 'https://www.youtube.com/api/timedtext?v=test&lang=en';
      var callCount = 0;
      mockClient = MockClient((request) async {
        callCount++;
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {'baseUrl': captionUrl, 'vssId': '.en', 'languageCode': 'en'},
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.toString().startsWith(captionUrl)) {
          return http.Response(
            _cannedJson3Response([
              {
                'tStartMs': 0,
                'dDurationMs': 3000,
                'segs': [
                  {'utf8': 'Hello world'},
                ],
                'aAppend': 0,
              },
              {
                'tStartMs': 3000,
                'dDurationMs': 2500,
                'segs': [
                  {'utf8': 'How are you?'},
                ],
                'aAppend': 0,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('', 404);
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchSubtitles(
        videoId: 'dQw4w9WgXcQ',
        lang: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(result.subtitles.length, 2);
      expect(result.subtitles[0].text, 'Hello world');
      expect(result.subtitles[0].startMs, 0);
      expect(result.subtitles[0].durationMs, 3000);
      expect(result.subtitles[1].text, 'How are you?');
      expect(result.source, 'official');
      expect(result.fetchProfile, 'ios');
      expect(callCount, 2);
    });

    test('fetchSubtitles falls back through client profiles', () async {
      var attempts = <String>[];
      const captionUrl = 'https://www.youtube.com/api/timedtext?v=test';
      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          final ua = request.headers['user-agent'] ?? '';
          attempts.add(
            'POST with ${ua.substring(0, ua.length > 30 ? 30 : ua.length)}...',
          );
        }
        if (request.url.toString().contains(captionUrl)) {
          return http.Response(
            _cannedJson3Response([
              {
                'tStartMs': 0,
                'dDurationMs': 1000,
                'segs': [
                  {'utf8': 'Hello from fallback'},
                ],
                'aAppend': 0,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('', 500);
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchSubtitles(
        videoId: 'test1234567',
        lang: 'en',
      );

      // Expect that with all-500 mock, the fetcher tries multiple profiles
      // and eventually returns an error (relying on all failing)
      expect(
        attempts.length,
        greaterThanOrEqualTo(2),
        reason: 'Should have tried at least 2 profiles',
      );
      expect(result.isSuccess, isFalse);
    });

    test('fetchSubtitles returns error when all profiles fail', () async {
      mockClient = MockClient((request) async {
        return http.Response('Forbidden', 403);
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchSubtitles(
        videoId: 'test1234567',
        lang: 'en',
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
      expect(result.error!.contains('All profiles failed'), isTrue);
    });

    test('fetchSubtitles returns error for unplayable video', () async {
      mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_cannedPlayerResponse(status: 'ERROR')),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchSubtitles(
        videoId: 'test1234567',
        lang: 'en',
      );

      expect(result.isSuccess, isFalse);
    });

    test('fetchSubtitles selects manual captions over auto', () async {
      const manualUrl =
          'https://www.youtube.com/api/timedtext?v=test&lang=en&kind=';
      const autoUrl =
          'https://www.youtube.com/api/timedtext?v=test&lang=en&kind=asr';
      String? fetchedUrl;

      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {
                    'baseUrl': autoUrl,
                    'vssId': 'a.en',
                    'languageCode': 'en',
                    'kind': 'asr',
                  },
                  {'baseUrl': manualUrl, 'vssId': '.en', 'languageCode': 'en'},
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        fetchedUrl = request.url.toString();
        return http.Response(
          _cannedJson3Response([
            {
              'tStartMs': 0,
              'dDurationMs': 1000,
              'segs': [
                {'utf8': 'manual'},
              ],
              'aAppend': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchSubtitles(
        videoId: 'test1234567',
        lang: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(result.source, 'official');
      expect(fetchedUrl, isNotNull);
      expect(fetchedUrl!.contains(manualUrl), isTrue);
    });

    test('fetchSubtitles handles auto-generated captions', () async {
      const autoUrl =
          'https://www.youtube.com/api/timedtext?v=test&lang=en&kind=asr';

      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {
                    'baseUrl': autoUrl,
                    'vssId': 'a.en',
                    'languageCode': 'en',
                    'kind': 'asr',
                  },
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          _cannedJson3Response([
            {
              'tStartMs': 0,
              'dDurationMs': 1000,
              'segs': [
                {'utf8': 'auto generated'},
              ],
              'aAppend': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchSubtitles(
        videoId: 'test1234567',
        lang: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(result.source, 'auto');
    });

    test('fetchSubtitles decodes HTML entities in captions', () async {
      const captionUrl = 'https://www.youtube.com/api/timedtext?v=test';
      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {'baseUrl': captionUrl, 'vssId': '.en', 'languageCode': 'en'},
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          _cannedJson3Response([
            {
              'tStartMs': 0,
              'dDurationMs': 1000,
              'segs': [
                {'utf8': 'We&#39;re no strangers to &amp; love'},
              ],
              'aAppend': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchSubtitles(
        videoId: 'test1234567',
        lang: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(result.subtitles[0].text, "We're no strangers to & love");
    });

    test('fetchSubtitles strips HTML tags from captions', () async {
      const captionUrl = 'https://www.youtube.com/api/timedtext?v=test';
      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {'baseUrl': captionUrl, 'vssId': '.en', 'languageCode': 'en'},
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          _cannedJson3Response([
            {
              'tStartMs': 0,
              'dDurationMs': 1000,
              'segs': [
                {'utf8': '<b>bold</b> text <i>italic</i>'},
              ],
              'aAppend': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchSubtitles(
        videoId: 'test1234567',
        lang: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(result.subtitles[0].text, 'bold text italic');
    });

    test('fetchSubtitles skips aAppend events', () async {
      const captionUrl = 'https://www.youtube.com/api/timedtext?v=test';
      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {'baseUrl': captionUrl, 'vssId': '.en', 'languageCode': 'en'},
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          _cannedJson3Response([
            {
              'tStartMs': 0,
              'dDurationMs': 3000,
              'segs': [
                {'utf8': 'First part'},
              ],
              'aAppend': 0,
            },
            {
              'tStartMs': 3000,
              'dDurationMs': 1000,
              'segs': [
                {'utf8': ' - continued part'},
              ],
              'aAppend': 1,
            },
            {
              'tStartMs': 4000,
              'dDurationMs': 2000,
              'segs': [
                {'utf8': 'New segment'},
              ],
              'aAppend': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchSubtitles(
        videoId: 'test1234567',
        lang: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(result.subtitles.length, 2);
      expect(result.subtitles[0].text, 'First part');
      expect(result.subtitles[1].text, 'New segment');
    });

    test('fetchSubtitles skips events with no segs', () async {
      const captionUrl = 'https://www.youtube.com/api/timedtext?v=test';
      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {'baseUrl': captionUrl, 'vssId': '.en', 'languageCode': 'en'},
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          _cannedJson3Response([
            {'tStartMs': 0, 'dDurationMs': 1000, 'segs': [], 'aAppend': 0},
            {
              'tStartMs': 1000,
              'dDurationMs': 2000,
              'segs': [
                {'utf8': 'Valid segment'},
              ],
              'aAppend': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchSubtitles(
        videoId: 'test1234567',
        lang: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(result.subtitles.length, 1);
      expect(result.subtitles[0].text, 'Valid segment');
    });

    test('fetchSubtitles handles empty caption tracks gracefully', () async {
      mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_cannedPlayerResponse(tracks: [])),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchSubtitles(
        videoId: 'test1234567',
        lang: 'en',
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
    });

    test('fetchSubtitles handles caption track 404', () async {
      const captionUrl = 'https://www.youtube.com/api/timedtext?v=test';
      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {'baseUrl': captionUrl, 'vssId': '.en', 'languageCode': 'en'},
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchSubtitles(
        videoId: 'test1234567',
        lang: 'en',
      );

      expect(result.isSuccess, isFalse);
    });

    test(
      'fetchSubtitles returns empty result for empty json3 response',
      () async {
        const captionUrl = 'https://www.youtube.com/api/timedtext?v=test';
        mockClient = MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode(
                _cannedPlayerResponse(
                  tracks: [
                    {
                      'baseUrl': captionUrl,
                      'vssId': '.en',
                      'languageCode': 'en',
                    },
                  ],
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'events': <Map<String, dynamic>>[]}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
        final result = await fetcher.fetchSubtitles(
          videoId: 'test1234567',
          lang: 'en',
        );

        expect(result.isSuccess, isFalse);
        expect(result.subtitles, isEmpty);
        expect(result.error, isNull);
      },
    );
  });

  group('fetchAllSubtitles', () {
    test('returns all available language tracks', () async {
      const enUrl = 'https://www.youtube.com/api/timedtext?v=test&lang=en';
      const esUrl = 'https://www.youtube.com/api/timedtext?v=test&lang=es';
      const jaUrl = 'https://www.youtube.com/api/timedtext?v=test&lang=ja';

      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {'baseUrl': enUrl, 'vssId': '.en', 'languageCode': 'en'},
                  {'baseUrl': esUrl, 'vssId': '.es', 'languageCode': 'es'},
                  {
                    'baseUrl': jaUrl,
                    'vssId': 'a.ja',
                    'languageCode': 'ja',
                    'kind': 'asr',
                  },
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        final url = request.url.toString();
        return http.Response(
          _cannedJson3Response([
            {
              'tStartMs': 0,
              'dDurationMs': 1000,
              'segs': [
                {
                  'utf8': url.contains('lang=en')
                      ? 'English'
                      : url.contains('lang=es')
                      ? 'Español'
                      : '日本語',
                },
              ],
              'aAppend': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchAllSubtitles(videoId: 'test1234567');

      expect(result.isSuccess, isTrue);
      expect(result.results.length, 3);
      expect(result.results[0].language, 'en');
      expect(result.results[0].source, 'official');
      expect(result.results[2].source, 'auto');
    });

    test('preferred language is sorted first', () async {
      const enUrl = 'https://www.youtube.com/api/timedtext?v=test&lang=en';
      const esUrl = 'https://www.youtube.com/api/timedtext?v=test&lang=es';

      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {'baseUrl': enUrl, 'vssId': '.en', 'languageCode': 'en'},
                  {'baseUrl': esUrl, 'vssId': '.es', 'languageCode': 'es'},
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          _cannedJson3Response([
            {
              'tStartMs': 0,
              'dDurationMs': 1000,
              'segs': [
                {'utf8': 'text'},
              ],
              'aAppend': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchAllSubtitles(
        videoId: 'test1234567',
        preferredLang: 'es',
      );

      expect(result.isSuccess, isTrue);
      expect(result.results.length, 2);
      expect(result.results[0].language, 'es');
      expect(result.results[1].language, 'en');
    });

    test('deduplicates manual over auto for same language', () async {
      const manualUrl =
          'https://www.youtube.com/api/timedtext?v=test&lang=en&kind=';
      const autoUrl =
          'https://www.youtube.com/api/timedtext?v=test&lang=en&kind=asr';

      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {
                    'baseUrl': autoUrl,
                    'vssId': 'a.en',
                    'languageCode': 'en',
                    'kind': 'asr',
                  },
                  {'baseUrl': manualUrl, 'vssId': '.en', 'languageCode': 'en'},
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        final url = request.url.toString();
        final isManual = url.contains('lang=en&kind=');
        return http.Response(
          _cannedJson3Response([
            {
              'tStartMs': 0,
              'dDurationMs': 1000,
              'segs': [
                {'utf8': isManual ? 'manual text' : 'auto text'},
              ],
              'aAppend': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchAllSubtitles(
        videoId: 'test1234567',
        preferredLang: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(result.results.length, 1);
      expect(result.results[0].source, 'official');
      expect(result.results[0].subtitles[0].text, 'manual text');
    });

    test('skip tracks without language code', () async {
      const enUrl = 'https://www.youtube.com/api/timedtext?v=test&lang=en';

      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {
                    'baseUrl': 'https://www.youtube.com/api/timedtext?v=nolang',
                    'vssId': '.en',
                  },
                  {'baseUrl': enUrl, 'vssId': '.en', 'languageCode': 'en'},
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          _cannedJson3Response([
            {
              'tStartMs': 0,
              'dDurationMs': 1000,
              'segs': [
                {'utf8': 'text'},
              ],
              'aAppend': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchAllSubtitles(videoId: 'test1234567');

      expect(result.isSuccess, isTrue);
      expect(result.results.length, 1);
      expect(result.results[0].language, 'en');
    });

    test('handles individual track fetch failures gracefully', () async {
      const okUrl = 'https://www.youtube.com/api/timedtext?v=test&lang=en';
      const badUrl = 'https://www.youtube.com/api/timedtext?v=test&lang=es';

      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {'baseUrl': okUrl, 'vssId': '.en', 'languageCode': 'en'},
                  {'baseUrl': badUrl, 'vssId': '.es', 'languageCode': 'es'},
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.toString().startsWith(badUrl)) {
          return http.Response('Not Found', 404);
        }
        return http.Response(
          _cannedJson3Response([
            {
              'tStartMs': 0,
              'dDurationMs': 1000,
              'segs': [
                {'utf8': 'ok text'},
              ],
              'aAppend': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchAllSubtitles(
        videoId: 'test1234567',
        preferredLang: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(result.results.length, 2);
      expect(result.results[0].isSuccess, isTrue);
      expect(result.results[1].isSuccess, isFalse);
      expect(result.results[0].language, 'en');
    });

    test('prefers last successful profile on subsequent fetches', () async {
      const iosUa = 'com.google.ios.youtube/';
      const vrUa = 'com.google.android.apps.youtube.vr';
      const captionUrl = 'https://www.youtube.com/api/timedtext?v=sticky';
      final playerAttempts = <String>[];

      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          final ua = request.headers['user-agent'] ?? '';
          if (ua.contains(iosUa)) {
            playerAttempts.add('ios');
            // First video: IOS has no tracks; ANDROID_VR succeeds.
            if (playerAttempts.where((a) => a == 'ios').length == 1) {
              return http.Response(
                jsonEncode(_cannedPlayerResponse(tracks: const [])),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            // Second video: IOS would succeed, but sticky should skip to VR.
            return http.Response(
              jsonEncode(
                _cannedPlayerResponse(
                  tracks: [
                    {
                      'baseUrl': captionUrl,
                      'vssId': '.en',
                      'languageCode': 'en',
                    },
                  ],
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (ua.contains(vrUa)) {
            playerAttempts.add('android_vr');
            return http.Response(
              jsonEncode(
                _cannedPlayerResponse(
                  tracks: [
                    {
                      'baseUrl': captionUrl,
                      'vssId': '.en',
                      'languageCode': 'en',
                    },
                  ],
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          playerAttempts.add('other');
          return http.Response('Forbidden', 403);
        }
        return http.Response(
          _cannedJson3Response([
            {
              'tStartMs': 0,
              'dDurationMs': 1000,
              'segs': [
                {'utf8': 'sticky'},
              ],
              'aAppend': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final first = await fetcher.fetchAllSubtitles(videoId: 'vid11111111');
      expect(first.isSuccess, isTrue);
      expect(first.fetchProfile, 'android_vr');
      expect(playerAttempts, ['ios', 'android_vr']);

      playerAttempts.clear();
      final second = await fetcher.fetchAllSubtitles(videoId: 'vid22222222');
      expect(second.isSuccess, isTrue);
      expect(second.fetchProfile, 'android_vr');
      // Sticky puts android_vr first — no ios attempt on the second video.
      expect(playerAttempts, ['android_vr']);
    });
  });

  group('YoutubeCaptionFetchException', () {
    test('innertubePlayer stage flows through aggregation error string',
        () async {
      mockClient = MockClient((request) async {
        return http.Response('Forbidden', 403);
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      // Per-profile `_fetchPlayer` throws, but the inner
      // `try { ... } on Object catch` aggregates into `AllCaptionsResult.error`
      // so callers see the typed exception via the embedded toString() —
      // not as a propagated throw.
      final result = await fetcher.fetchAllSubtitles(videoId: 'test1234567');
      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
      expect(
        result.error,
        contains(YoutubeCaptionErrorStage.innertubePlayer.name),
      );
      expect(result.error, contains('403'));
    });

    test('innertubePlayability stage fires on non-OK playabilityStatus',
        () async {
      mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_cannedPlayerResponse(status: 'LOGIN_REQUIRED')),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      // The exception is caught inside fetchAllSubtitles (so chained
      // profiles can still try), but `allResult.error` must reference the
      // typed exception's `toString()` for log/monitoring correlation.
      final result = await fetcher.fetchAllSubtitles(videoId: 'test1234567');
      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, contains('LOGIN_REQUIRED'));
    });

    test('timedTextGet stage fires on non-200 timedtext response', () async {
      mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              _cannedPlayerResponse(
                tracks: [
                  {
                    'baseUrl': 'https://www.youtube.com/api/timedtext?v=t',
                    'vssId': '.en',
                    'languageCode': 'en',
                  },
                ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final fetcher = YoutubeCaptionFetcher(httpClient: mockClient);
      final result = await fetcher.fetchAllSubtitles(
        videoId: 'test1234567',
        preferredLang: 'en',
      );
      expect(result.isSuccess, isTrue);
      expect(result.results.length, 1);
      expect(result.results[0].isSuccess, isFalse);
      expect(result.results[0].error, contains('404'));
    });

    test('toString embeds stage name and status code', () {
      final ex = YoutubeCaptionFetchException(
        stage: YoutubeCaptionErrorStage.timedTextJson,
        message: 'broken body',
      );
      expect(ex.toString(), contains('timedTextJson'));
      expect(ex.toString(), contains('broken body'));
      expect(ex.toString(), isNot(contains('null')));

      final exWithCode = YoutubeCaptionFetchException(
        stage: YoutubeCaptionErrorStage.timedTextGet,
        statusCode: 503,
        message: 'upstream busy',
      );
      expect(exWithCode.toString(), contains('(503)'));
      expect(exWithCode.toString(), contains('upstream busy'));
    });

    test('is catchable as plain Exception for backward compatibility', () {
      final ex = YoutubeCaptionFetchException(
        stage: YoutubeCaptionErrorStage.innertubePlayer,
        message: 'x',
      );
      // Existing `on Object catch` / `on Exception catch` blocks continue to
      // catch this type without modification.
      expect(ex, isA<Exception>());
      try {
        throw ex;
      } on Exception catch (e) {
        expect(e, same(ex));
      }
    });
  });
}
