/// Continue practicing — last `echo_sessions` row with a live library item.
///
/// Consumed by the desktop sidebar card ([SidebarContinuePracticeCard]);
/// Home intentionally has no Continue section (the last-practiced item is
/// already the first row of its recents grid).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/library/application/library_media_provider.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/library/domain/practice_resume.dart';

const kContinueSessionLookback = 20;

final echoRecentSessionsProvider = StreamProvider<List<EchoSessionRow>>((ref) {
  return ref
      .watch(appDatabaseProvider)
      .echoSessionDao
      .watchRecentByLastActiveAt(limit: kContinueSessionLookback);
});

/// First session (by `last_active_at`) whose `target_id` still exists in the library.
PracticeResume? resolvePracticeResume({
  required List<EchoSessionRow> sessions,
  required Media? Function(String id) lookupMedia,
}) {
  for (final session in sessions) {
    final media = lookupMedia(session.targetId);
    if (media == null) continue;
    return PracticeResume(
      media: media,
      positionMs: session.currentTimeMs,
      echoActive: session.echoActive,
      lastActiveAt: session.lastActiveAt,
      sessionId: session.id,
    );
  }
  return null;
}

/// Last practiced item to resume, or `null` when there is nothing to resume.
final continuePracticeResumeProvider = Provider<PracticeResume?>((ref) {
  final sessions = ref.watch(echoRecentSessionsProvider).valueOrNull;
  final media = ref.watch(libraryMediaProvider).valueOrNull;
  if (sessions == null || media == null) return null;
  final byId = {for (final m in media) m.id: m};
  return resolvePracticeResume(
    sessions: sessions,
    lookupMedia: (id) => byId[id],
  );
});
