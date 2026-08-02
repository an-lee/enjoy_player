/// Direct YouTube captions fetcher using the public InnerTube API.
///
/// Port of the [youtube-caption-extractor](https://github.com/devhims/youtube-caption-extractor)
/// TypeScript library to Dart. Calls YouTube's InnerTube `/player` endpoint with
/// spoofed client profiles, then fetches the selected caption track in `json3`
/// format.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'client_profile.dart';
import '../../../data/subtitle/transcript_line.dart';
import '../../../core/logging/log.dart';
import '../../../core/utils/html_clean.dart';

/// Module-level logger for direct InnerTube fetches.
///
/// Each profile attempt logs at INFO; the cumulative "all profiles failed"
/// path in [YoutubeCaptionFetcher.fetchAllSubtitles] is logged at INFO here,
/// and the caller ([TranscriptRepository._fetchYoutubeTranscriptsWithFallback])
/// escalates it to WARNING when surfacing the result. This split keeps
/// per-profile chatter at INFO (cheap in production) while the user-visible
/// "I see captions on Windows but not on Android" failure mode still trips
/// WARNING once per open.
final Logger _log = logNamed('YoutubeCaptionFetcher');

/// Stage at which a [YoutubeCaptionFetchException] was raised.
///
/// Lets callers / tests distinguish InnerTube `/player` failures from
/// per-track `timedtext` fetches without string-parsing the message.
enum YoutubeCaptionErrorStage {
  /// InnerTube `/player` HTTP call returned a non-200 status.
  innertubePlayer,

  /// InnerTube `/player` returned a `playabilityStatus.status` other than
  /// 'OK' (e.g. `ERROR`, `LOGIN_REQUIRED`, `UNPLAYABLE`).
  innertubePlayability,

  /// Per-track `timedtext?v=…&fmt=json3` HTTP call returned a non-200
  /// status.
  timedTextGet,

  /// Per-track `timedtext` body could not be parsed as JSON.
  timedTextJson,
}

/// Typed exception thrown by [YoutubeCaptionFetcher] when a YouTube
/// captions fetch fails at an HTTP / parse boundary.
///
/// All throw sites in `youtube_caption_fetcher.dart` raise this type so
/// callers can catch it explicitly (`on YoutubeCaptionFetchException`) to
/// distinguish InnerTube / `timedtext` failures from the broader
/// `CaptionFetchResult.error` strings produced by the fallback chain.
/// Implements [Exception] for compatibility with existing `on Object catch`
/// blocks.
class YoutubeCaptionFetchException implements Exception {
  YoutubeCaptionFetchException({
    required this.stage,
    required this.message,
    this.statusCode,
  });

  /// Where the failure occurred.
  final YoutubeCaptionErrorStage stage;

  /// Human-readable description (already safe to log).
  final String message;

  /// HTTP status code when [stage] is an HTTP boundary; null otherwise.
  final int? statusCode;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' ($statusCode)';
    return 'YoutubeCaptionFetchException(${stage.name}$code): $message';
  }
}

/// Session-sticky last profile that returned usable caption tracks.
///
/// Survives [YoutubeCaptionFetcher] rebuilds when Riverpod refreshes the
/// profile list so subsequent videos try the known-good client first.
String? _lastSuccessfulCaptionProfileKey;

/// Clears the sticky caption profile (tests / forced reset).
void resetLastSuccessfulCaptionProfile() {
  _lastSuccessfulCaptionProfileKey = null;
}

/// InnerTube API endpoint.
const _innertubeEndpoint =
    'https://youtubei.googleapis.com/youtubei/v1/player?prettyPrint=false';

/// Transient descriptor for a YouTube caption track.
class CaptionTrack {
  const CaptionTrack({
    required this.baseUrl,
    this.vssId,
    this.languageCode,
    this.kind,
  });

  factory CaptionTrack.fromJson(Map<String, dynamic> json) {
    return CaptionTrack(
      baseUrl: json['baseUrl'] as String? ?? '',
      vssId: json['vssId'] as String?,
      languageCode: json['languageCode'] as String?,
      kind: json['kind'] as String?,
    );
  }

  final String baseUrl;
  final String? vssId;
  final String? languageCode;
  final String? kind;
}

/// Outcome of a direct YouTube caption fetch attempt.
class CaptionFetchResult {
  const CaptionFetchResult({
    this.subtitles = const [],
    this.source = 'auto',
    this.language = '',
    this.fetchProfile = '',
    this.error,
  });

  final List<TranscriptLine> subtitles;
  final String source;
  final String language;
  final String fetchProfile;
  final String? error;

  bool get isSuccess => error == null && subtitles.isNotEmpty;
}

/// Outcome of fetching all available caption tracks for a video.
class AllCaptionsResult {
  const AllCaptionsResult({
    this.results = const [],
    this.fetchProfile = '',
    this.error,
  });

  final List<CaptionFetchResult> results;
  final String fetchProfile;
  final String? error;

  bool get isSuccess => error == null && results.isNotEmpty;
}

/// Fetches YouTube captions directly using the InnerTube API.
class YoutubeCaptionFetcher {
  YoutubeCaptionFetcher({
    required this.httpClient,
    this.profiles = kBuiltInClientProfiles,
  });

  final http.Client httpClient;
  final List<ClientProfile> profiles;

  /// Returns the fallback chain of profiles to try.
  ///
  /// When a prior fetch in this process succeeded, that profile is moved to
  /// the front so later videos skip already-failed clients.
  List<ClientProfile> get _profileChain {
    final chain = profiles.where((p) => p.isValid).toList();
    final sticky = _lastSuccessfulCaptionProfileKey;
    if (sticky == null || chain.length < 2) return chain;
    final idx = chain.indexWhere(
      (p) => p.name == sticky || p.clientKey == sticky.toUpperCase(),
    );
    if (idx <= 0) return chain;
    return [chain[idx], ...chain.sublist(0, idx), ...chain.sublist(idx + 1)];
  }

  /// Fetches subtitles for [videoId] in [lang] by trying each client profile
  /// in sequence, selecting the best matching caption track, and parsing the
  /// json3 timed text.
  Future<CaptionFetchResult> fetchSubtitles({
    required String videoId,
    String lang = 'en',
  }) async {
    final result = await fetchAllSubtitles(
      videoId: videoId,
      preferredLang: lang,
    );
    if (result.error != null) {
      return CaptionFetchResult(error: result.error);
    }
    if (result.results.isEmpty) {
      return const CaptionFetchResult(error: 'No caption tracks available');
    }
    return result.results.first;
  }

  /// Fetches all available caption tracks for [videoId], returning them as a
  /// list with the [preferredLang] match first. Fetches player data once and
  /// downloads all tracks in parallel.
  ///
  /// For each language, prefers manual captions (`.lang`) over auto-generated
  /// (`a.lang`). Returns an [AllCaptionsResult] with the deduplicated results
  /// list plus combined error/failure information.
  Future<AllCaptionsResult> fetchAllSubtitles({
    required String videoId,
    String preferredLang = 'en',
  }) async {
    final chain = _profileChain;
    if (chain.isEmpty) {
      return const AllCaptionsResult(error: 'No valid client profiles');
    }

    final failures = <String>[];
    for (final profile in chain) {
      try {
        final playerData = await _fetchPlayer(
          videoId: videoId,
          profile: profile,
        );

        final allTracks = _extractCaptionTracks(playerData);
        if (allTracks.isEmpty) {
          const msg = 'OK but no caption tracks';
          failures.add('${profile.name}: $msg');
          _log.info('InnerTube profile=${profile.name} for $videoId: $msg');
          continue;
        }

        // Deduplicate: for each language, prefer manual over auto
        final bestByLang = <String, CaptionTrack>{};
        for (final track in allTracks) {
          final code = track.languageCode;
          if (code == null || code.isEmpty) continue;
          final existing = bestByLang[code];
          if (existing == null ||
              _isBetterMatch(track, existing, preferredLang: preferredLang)) {
            bestByLang[code] = track;
          }
        }

        if (bestByLang.isEmpty) {
          const msg = 'no tracks with valid language codes';
          failures.add('${profile.name}: $msg');
          _log.info('InnerTube profile=${profile.name} for $videoId: $msg');
          continue;
        }

        // Fetch all tracks in parallel
        final futures = bestByLang.values.map((track) async {
          try {
            final source = _determineSource(track);
            final subtitles = await _fetchCaptionTrack(track, profile);
            return CaptionFetchResult(
              subtitles: subtitles,
              source: source,
              language: track.languageCode ?? '',
              fetchProfile: profile.name,
            );
          } on Object catch (e) {
            return CaptionFetchResult(
              error: '${track.languageCode}: $e',
              language: track.languageCode ?? '',
            );
          }
        });

        final allResults = await Future.wait(futures);

        // Sort: preferred language first, then alphabetical
        final sorted = [...allResults];
        sorted.sort((a, b) {
          if (a.language == preferredLang) return -1;
          if (b.language == preferredLang) return 1;
          return a.language.compareTo(b.language);
        });

        final okCount = sorted.where((r) => r.isSuccess).length;
        if (okCount > 0) {
          _lastSuccessfulCaptionProfileKey = profile.name;
        }
        _log.info(
          'InnerTube profile=${profile.name} for $videoId returned '
          '${bestByLang.length} track(s) ($okCount fetchable)',
        );
        return AllCaptionsResult(results: sorted, fetchProfile: profile.name);
      } on Object catch (e) {
        final msg = '$e';
        failures.add('${profile.name}: $msg');
        _log.info('InnerTube profile=${profile.name} for $videoId threw: $msg');
      }
    }

    _log.info(
      'InnerTube all profiles failed for $videoId (tried: '
      '${chain.map((p) => p.name).join(', ')})',
    );
    return AllCaptionsResult(
      error: 'All profiles failed:\n${failures.join('\n')}',
    );
  }

  /// POSTs to the InnerTube `/player` endpoint with [profile]'s credentials.
  Future<Map<String, dynamic>> _fetchPlayer({
    required String videoId,
    required ClientProfile profile,
  }) async {
    final body = {
      'context': {
        'client': {
          'clientName': profile.clientName,
          'clientVersion': profile.clientVersion,
          'hl': 'en',
          'gl': 'US',
          ...profile.context,
        },
        'user': {'lockedSafetyMode': false},
        'request': {'useSsl': true},
      },
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
    };

    final response = await httpClient.post(
      Uri.parse(_innertubeEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'User-Agent': profile.userAgent,
        'X-YouTube-Client-Name': profile.clientNameHeader,
        'X-YouTube-Client-Version': profile.clientVersion,
        'Origin': 'https://www.youtube.com',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw YoutubeCaptionFetchException(
        stage: YoutubeCaptionErrorStage.innertubePlayer,
        statusCode: response.statusCode,
        message:
            'InnerTube /player failed: ${response.statusCode} ${response.reasonPhrase}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status =
        (data['playabilityStatus'] as Map<String, dynamic>?)?['status']
            as String?;

    if (status != null && status != 'OK') {
      throw YoutubeCaptionFetchException(
        stage: YoutubeCaptionErrorStage.innertubePlayability,
        message: 'Video not playable: $status',
      );
    }

    return data;
  }

  /// Extracts caption tracks from the InnerTube player response.
  List<CaptionTrack> _extractCaptionTracks(Map<String, dynamic> playerData) {
    final captions = playerData['captions'] as Map<String, dynamic>?;
    if (captions == null) return [];
    final renderer =
        captions['playerCaptionsTracklistRenderer'] as Map<String, dynamic>?;
    if (renderer == null) return [];
    final tracks = renderer['captionTracks'] as List?;
    if (tracks == null) return [];
    return tracks
        .whereType<Map<String, dynamic>>()
        .map(CaptionTrack.fromJson)
        .where((t) => t.baseUrl.isNotEmpty)
        .toList();
  }

  /// Determines source label from the selected track's kind.
  String _determineSource(CaptionTrack track) {
    if (track.vssId != null && track.vssId!.startsWith('a.')) return 'auto';
    if (track.kind == 'asr') return 'auto';
    return 'official';
  }

  /// Returns true when [candidate] is a better choice than [current] for a
  /// given language. Prefers manual captions over auto, and prefers tracks
  /// matching [preferredLang].
  bool _isBetterMatch(
    CaptionTrack candidate,
    CaptionTrack current, {
    String preferredLang = 'en',
  }) {
    final cVss = candidate.vssId ?? '';
    final curVss = current.vssId ?? '';
    final cIsManual = cVss.startsWith('.');
    final curIsManual = curVss.startsWith('.');
    if (cIsManual && !curIsManual) return true;
    if (!cIsManual && curIsManual) return false;
    final cIsPref =
        candidate.languageCode == preferredLang || cVss == '.$preferredLang';
    final curIsPref =
        current.languageCode == preferredLang || curVss == '.$preferredLang';
    if (cIsPref && !curIsPref) return true;
    return false;
  }

  /// Fetches the caption track data in json3 format and parses to segments.
  ///
  /// Uses [profile]'s user agent and a matching `Referer` so the timedtext
  /// endpoint sees a consistent client identity with the `/player` call that
  /// succeeded. Mixing the iOS UA on a non-iOS profile silently returns
  /// empty / 403 on real YouTube.
  Future<List<TranscriptLine>> _fetchCaptionTrack(
    CaptionTrack track,
    ClientProfile profile,
  ) async {
    var url = track.baseUrl.replaceAll(RegExp(r'&fmt=[^&]+'), '');
    url += '&fmt=json3';

    final response = await httpClient.get(
      Uri.parse(url),
      headers: {
        'User-Agent': profile.userAgent,
        'Referer': 'https://m.youtube.com/',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    );

    if (response.statusCode != 200) {
      throw YoutubeCaptionFetchException(
        stage: YoutubeCaptionErrorStage.timedTextGet,
        statusCode: response.statusCode,
        message: 'Caption fetch failed: ${response.statusCode}',
      );
    }

    final text = response.body.trim();
    if (text.isEmpty) return [];

    final dynamic data;
    try {
      data = jsonDecode(text);
    } on FormatException {
      throw YoutubeCaptionFetchException(
        stage: YoutubeCaptionErrorStage.timedTextJson,
        message: 'Caption response was not valid JSON',
      );
    }

    if (data is! Map) return [];

    final events = data['events'] as List?;
    if (events == null) return [];

    final subtitles = <TranscriptLine>[];
    for (final event in events) {
      if (event is! Map) continue;
      final aAppend = event['aAppend'];
      if (aAppend == 1) continue;
      final segs = event['segs'] as List?;
      if (segs == null || segs.isEmpty) continue;

      final raw = segs
          .whereType<Map>()
          .map((s) => (s['utf8'] as String?) ?? '')
          .join();
      final cleaned = cleanHtmlText(raw);
      if (cleaned.isEmpty) continue;

      final tStartMs = (event['tStartMs'] as num?)?.toInt() ?? 0;
      final dDurationMs = (event['dDurationMs'] as num?)?.toInt() ?? 0;

      subtitles.add(
        TranscriptLine(
          text: cleaned,
          startMs: tStartMs,
          durationMs: dDurationMs,
        ),
      );
    }

    return subtitles;
  }
}
