/// Worker cache & profile API for YouTube transcripts
/// (see `specs/013-client-yt-transcripts/contracts/worker-cache-api.md`).
library;

import 'package:logging/logging.dart';

import 'package:enjoy_player/core/json/json_cast.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/api/rest_api.dart';

/// Module-level logger for worker transit calls.
///
/// Every method on [YoutubeTranscriptsApi] is fire-and-forget from the
/// caller's perspective (see [YoutubeTranscriptsClient]'s contract). That
/// contract is correct, but it must not silently swallow transport /
/// validation failures: callers (and operators) need a signal whenever a
/// cache GET, an upload, or a profile fetch does not reach the worker, or
/// the video-to-video caption sync silently regresses (issue: Windows
/// fetch → no worker upload → Android cache miss). All three methods
/// downgrade the API result on exception but log here at WARNING so the
/// failure shows up in `debugPrint` / logcat / the rotating log file.
final Logger _log = logNamed('YouTubeTranscripts');

/// Contract for the Enjoy Worker transcript cache & profile endpoints
/// (cache-only; the legacy poll-based POST `/youtube/transcripts` was removed
/// upstream — see issue #320).
abstract class YoutubeTranscriptsClient {
  /// Looks up a cached transcript from the worker's GET endpoint.
  ///
  /// Returns the transcript map on cache hit, `null` on 404 (cache miss).
  Future<Map<String, dynamic>?> getCachedTranscript({
    required String videoId,
    required String language,
  });

  /// Uploads a client-fetched transcript to the worker for caching.
  ///
  /// Sends the full wire body the worker validates as required
  /// (`format`, `caption_fetch`, `generated_at`, plus `video_id`, `language`,
  /// `source`, `timeline`, optional `metadata`). Returns `true` on success
  /// (201 or 409 idempotent). Any failure (validation, transport, ...) is
  /// swallowed and surfaced as `false` — call sites treat this as
  /// fire-and-forget.
  Future<bool> uploadTranscript({
    required String videoId,
    required String language,
    required String source,
    required List<Map<String, dynamic>> timeline,
    Map<String, dynamic>? metadata,
  });

  /// Fetches the current set of YouTube InnerTube client profiles.
  ///
  /// `GET /youtube/client-profiles` returns a `{"version", "profiles"}`
  /// envelope; this extracts and returns the `profiles` list.
  Future<List<Map<String, dynamic>>> fetchClientProfiles();
}

class YoutubeTranscriptsApi extends RestApi
    implements YoutubeTranscriptsClient {
  YoutubeTranscriptsApi(super.client);

  static const _transcriptsPath = '/youtube/transcripts';
  static const _profilesPath = '/youtube/client-profiles';

  /// Fire-and-forget: log at WARNING and return [fallback] on any failure.
  Future<T> _swallow<T>(
    String description,
    Future<T> Function() call, {
    required T fallback,
  }) async {
    try {
      return await call();
    } on Object catch (e, st) {
      _log.warning(description, e, st);
      return fallback;
    }
  }

  @override
  Future<Map<String, dynamic>?> getCachedTranscript({
    required String videoId,
    required String language,
  }) => _swallow(
    'worker cache GET failed for $videoId/$language',
    () => client.getJson(
      _transcriptsPath,
      queryParameters: {'videoId': videoId, 'language': language},
    ),
    fallback: null,
  );

  @override
  Future<bool> uploadTranscript({
    required String videoId,
    required String language,
    required String source,
    required List<Map<String, dynamic>> timeline,
    Map<String, dynamic>? metadata,
  }) => _swallow(
    // Fire-and-forget from the caller's perspective, but do NOT silently
    // disappear here: a failed upload means the next client on a
    // different machine will re-fetch via InnerTube instead of using
    // the worker cache (issue: Windows → no worker upload → Android
    // cache miss). Operators need to see this in production logs.
    'worker upload failed for $videoId/$language '
    '(source=$source, ${timeline.length} lines)',
    () async {
      await client.postJson(
        _transcriptsPath,
        body: {
          'format': 'enjoy',
          'videoId': videoId,
          'language': language,
          'captionFetch': source == 'official' ? 'official' : 'auto',
          'source': source,
          'timeline': timeline,
          'metadata': ?metadata,
          'generatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      return true;
    },
    fallback: false,
  );

  @override
  Future<List<Map<String, dynamic>>> fetchClientProfiles() =>
      _swallow('worker profile fetch failed', () async {
        final response = await client.getJson(_profilesPath);
        final list = response['profiles'];
        if (list is List) {
          return list
              .map(castJsonObjectOrNull)
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
        }
        _log.warning(
          'worker profile fetch returned a body without a profiles list; '
          'falling back to built-in defaults',
        );
        return <Map<String, dynamic>>[];
      }, fallback: const <Map<String, dynamic>>[]);
}
