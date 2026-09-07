/// Stream of all library media (manual provider — avoids riverpod_generator + Drift edge case).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart';
import 'package:enjoy_player/core/utils/stream_distinct.dart';
import 'package:enjoy_player/features/library/domain/media.dart';

import 'library_repository_provider.dart';
import 'library_search_provider.dart';

final libraryMediaProvider = StreamProvider<List<Media>>((ref) {
  return ref.watch(mediaLibraryRepositoryProvider).watchAll();
});

/// Up to 12 most recently updated items for [HomeScreen] (pre-sorted).
///
/// Subscribes to `watchAll()` and applies the same library-wide dedupe as
/// [libraryFilteredListsProvider]: a single Drift tick that re-queries without
/// changing the top-12 still produces a brand-new list, which would otherwise
/// rebuild every `ConsumerWidget` watching this provider. Skip the emission
/// when the new top-12 is element-wise equal to the previous one.
final libraryHomeRecentsProvider = StreamProvider<List<Media>>((ref) {
  const recentLimit = 12;
  final repo = ref.watch(mediaLibraryRepositoryProvider);
  return repo
      .watchAll()
      .map((items) {
        final sorted = [...items]
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return sorted.take(recentLimit).toList();
      })
      .distinctBy(listEquals);
});

/// Pre-filtered audio/video lists for [LibraryScreen], newest [Media.updatedAt]
/// first (same ordering as Home recent media).
///
/// `watchAll()` re-emits a new list on every Drift table change. A background
/// `playbackSessionPersister` write or a duration probe on a non-matching row
/// re-sorts both halves and rebuilds every library-tab widget, even when the
/// filtered + ordered lists are byte-for-byte identical to the previous
/// emission. Dedupe on element equality of both halves to avoid that work.
final libraryFilteredListsProvider =
    StreamProvider<({List<Media> audio, List<Media> video})>((ref) {
      final repo = ref.watch(mediaLibraryRepositoryProvider);
      final query = ref.watch(librarySearchProvider);
      return repo
          .watchAll()
          .map((items) {
            final filtered = _filterMediaByQuery(items, query);
            final audioItems =
                filtered.where((m) => m.kind == MediaKind.audio).toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            final videoItems =
                filtered.where((m) => m.kind == MediaKind.video).toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            return (audio: audioItems, video: videoItems);
          })
          .distinctBy((prev, next) {
            return listEquals(prev.audio, next.audio) &&
                listEquals(prev.video, next.video);
          });
    });

List<Media> _filterMediaByQuery(List<Media> items, String query) {
  if (query.isEmpty) return items;
  final lower = query.toLowerCase();
  return items.where((m) => m.title.toLowerCase().contains(lower)).toList();
}
