/// JSON Feed v1.1 parser for RSSHub YouTube feeds.
library;

import 'dart:convert';

import 'package:enjoy_player/core/utils/youtube_video_identity.dart';
import 'package:enjoy_player/features/discover/domain/feed_entry.dart';

/// Matches the YouTube watch URL query parameter.
final RegExp _kYTUrlV = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})');

/// Matches a youtu.be short URL path component.
final RegExp _kYTShort = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})');

/// Parsed result from a JSON Feed v1.1 worker response.
class JsonFeedResult {
  const JsonFeedResult({
    required this.displayName,
    required this.homePageUrl,
    this.iconUrl,
    required this.entries,
  });

  /// Source display name (e.g. "TED" from "TED - YouTube").
  final String displayName;

  /// YouTube source URL (e.g. "https://www.youtube.com/channel/UC...").
  final String homePageUrl;

  /// Avatar URL from feed-level `icon`.
  final String? iconUrl;

  /// Parsed video entries.
  final List<FeedEntry> entries;
}

/// Extracts video ID from a YouTube watch URL or returns the input if
/// it's already a bare ID.
String extractVideoId(dynamic idValue) {
  if (idValue == null) return '';
  final idStr = idValue.toString().trim();
  // Try extracting from URL: https://www.youtube.com/watch?v=VIDEO_ID
  final urlMatch = _kYTUrlV.firstMatch(idStr);
  if (urlMatch != null) return urlMatch.group(1)!;
  // Try bare 11-char video ID
  if (bareYoutubeIdRegExp.hasMatch(idStr)) return idStr;
  // Try youtu.be short URL
  final shortMatch = _kYTShort.firstMatch(idStr);
  if (shortMatch != null) return shortMatch.group(1)!;
  return idStr;
}

/// Strips " - YouTube" suffix from feed title.
String _stripYouTubeSuffix(String title) {
  const suffix = ' - YouTube';
  if (title.endsWith(suffix)) {
    return title.substring(0, title.length - suffix.length);
  }
  return title;
}

/// Parses a JSON Feed v1.1 response body into a [JsonFeedResult].
///
/// Throws [FormatException] if the JSON structure is invalid or
/// required fields are missing.
class JsonFeedParser {
  JsonFeedResult parse(String jsonBody) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonBody);
    } catch (e) {
      throw FormatException('Invalid JSON: $e');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON Feed must be a JSON object');
    }
    final data = decoded;

    // Validate JSON Feed version
    final version = data['version'] as String?;
    if (version == null || !version.contains('jsonfeed.org')) {
      throw FormatException('Not a JSON Feed response: $version');
    }

    // Feed-level fields
    final title = data['title'] as String?;
    if (title == null || title.isEmpty) {
      throw const FormatException('Missing feed title');
    }
    final displayName = _stripYouTubeSuffix(title);

    final homePageUrl = data['home_page_url'] as String? ?? '';
    final iconUrl = data['icon'] as String?;

    // Parse items
    final items = data['items'];
    if (items is! List) {
      throw const FormatException('Missing items array in JSON Feed');
    }

    final entries = <FeedEntry>[];
    final now = DateTime.now();

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;

      final videoId = extractVideoId(item['id']);
      if (videoId.isEmpty) continue;

      final entryTitle = item['title'] as String? ?? '';
      final image = item['image'] as String?;

      // Parse published date
      DateTime? publishedAt;
      final dateStr = item['date_published'] as String?;
      if (dateStr != null) {
        publishedAt = DateTime.tryParse(dateStr);
      }

      // Extract duration from attachments
      int? durationSeconds;
      final attachments = item['attachments'];
      if (attachments is List && attachments.isNotEmpty) {
        for (final att in attachments) {
          if (att is Map<String, dynamic>) {
            final dur = att['duration_in_seconds'];
            if (dur is int && dur > 0) {
              durationSeconds = dur;
              break;
            }
            if (dur is double && dur > 0) {
              durationSeconds = dur.round();
              break;
            }
          }
        }
      }

      // Extract channelId from the first item's authors or feed home_page_url
      // We use the home_page_url channel ID as the channelId placeholder;
      // the caller sets the actual channelId from the subscription context.
      final channelId = ''; // caller fills this in

      entries.add(
        FeedEntry(
          videoId: videoId,
          channelId: channelId,
          title: entryTitle,
          thumbnailUrl: image,
          durationSeconds: durationSeconds,
          publishedAt: publishedAt ?? now,
        ),
      );
    }

    return JsonFeedResult(
      displayName: displayName,
      homePageUrl: homePageUrl,
      iconUrl: iconUrl,
      entries: entries,
    );
  }
}
