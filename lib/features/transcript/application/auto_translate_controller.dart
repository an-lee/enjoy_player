/// On-demand per-line auto-translate for a media item's AI secondary track.
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/application/app_language_catalog.dart';
import '../../../core/application/app_preferences_provider.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/logging/log.dart';
import '../../../core/riverpod/async_value_x.dart';
import '../../../data/db/media_target_resolver.dart';
import '../../../data/db/app_database_provider.dart';
import '../../../data/subtitle/subtitle_markup_parser.dart';
import '../../ai/application/ai_services.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../domain/auto_translate.dart';
import 'active_transcript_provider.dart';
import 'transcript_playback_highlight_provider.dart';
import 'transcript_repository_provider.dart';

part 'auto_translate_controller.g.dart';

final Logger _log = logNamed('auto_translate');

@Riverpod(keepAlive: true)
class AutoTranslateCtrl extends _$AutoTranslateCtrl {
  final _inFlight = <int>{};
  final _waiting = ListQueue<int>();
  final _forceRefreshLines = <int>{};

  @override
  AutoTranslateUiState build(String mediaId) {
    ref.listen(activeTranscriptIdProvider(mediaId), (prev, next) {
      if (state.aiTranscriptId == null) return;
      if (state.status != AutoTranslateStatus.active) return;
      if (prev?.value != next.value) {
        unawaited(_handlePrimaryChanged());
      }
    });

    ref.listen(secondaryTranscriptIdProvider(mediaId), (prev, next) {
      final aiId = state.aiTranscriptId;
      if (aiId == null) return;
      if (next.value != aiId && state.status == AutoTranslateStatus.active) {
        _clearInFlightTracking();
        state = state.copyWith(status: AutoTranslateStatus.idle);
      }
    });

    // On seek / active-cue change, prefer the new viewport over a FIFO backlog
    // of earlier lines that were requested while scrolled at the top.
    ref.listen(
      transcriptPlaybackHighlightProvider(mediaId).select((h) => h.cueIndex),
      (prev, next) {
        if (prev == next) return;
        if (state.status != AutoTranslateStatus.active) return;
        _reprioritizeWaiting(anchor: next);
      },
    );

    unawaited(_hydrateIfAiSecondaryActive());
    return const AutoTranslateUiState();
  }

  Future<void> _hydrateIfAiSecondaryActive() async {
    final secondaryId = ref.read(secondaryTranscriptIdProvider(mediaId)).value;
    if (secondaryId == null) return;

    final repo = ref.read(transcriptRepositoryProvider);
    final row = await repo.transcriptRowById(secondaryId);
    if (row == null || row.source != 'ai') return;

    final primaryId = ref.read(activeTranscriptIdProvider(mediaId)).value;
    if (!ref.mounted) return;
    String? sourceLanguage;
    if (primaryId != null) {
      final primaryRow = await repo.transcriptRowById(primaryId);
      sourceLanguage = primaryRow?.language;
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      status: AutoTranslateStatus.active,
      clearBlockReason: true,
      aiTranscriptId: row.id,
      primaryTranscriptId: primaryId,
      sourceLanguage: sourceLanguage,
      targetLanguage: row.language,
    );
  }

  /// Ensures the AI track exists and sets it as secondary. Does not translate
  /// lines — the transcript list requests each line when it enters the viewport.
  Future<void> selectAutoTranslate() async {
    final auth = ref.read(authCtrlProvider).valueOrNull;
    if (auth is! AuthSignedIn) {
      state = state.copyWith(
        status: AutoTranslateStatus.blocked,
        blockReason: AutoTranslateBlockReason.signedOut,
      );
      return;
    }

    final native = ref
        .read(appPreferencesCtrlProvider)
        .valueOrNull
        ?.effectiveNativeLanguage;
    if (native == null || native.isEmpty) {
      state = state.copyWith(
        status: AutoTranslateStatus.blocked,
        blockReason: AutoTranslateBlockReason.noPrimary,
      );
      return;
    }

    final repo = ref.read(transcriptRepositoryProvider);
    final primaryRow = await repo.primaryTranscriptRowForMedia(mediaId);
    if (primaryRow == null) {
      state = state.copyWith(
        status: AutoTranslateStatus.blocked,
        blockReason: AutoTranslateBlockReason.noPrimary,
      );
      return;
    }

    final primaryLines = repo.linesForRow(primaryRow);
    if (primaryLines.isEmpty) {
      state = state.copyWith(
        status: AutoTranslateStatus.blocked,
        blockReason: AutoTranslateBlockReason.noPrimary,
      );
      return;
    }

    final sourceBase = workerLanguageBase(primaryRow.language);
    final targetBase = workerLanguageBase(native);
    if (sourceBase == targetBase) {
      state = state.copyWith(
        status: AutoTranslateStatus.blocked,
        blockReason: AutoTranslateBlockReason.sameLanguage,
      );
      return;
    }

    final aiId = await repo.ensureAutoTranslateTrack(
      mediaId: mediaId,
      primaryTranscriptId: primaryRow.id,
      targetLanguage: native,
      primaryLines: primaryLines,
    );
    if (aiId == null) {
      state = state.copyWith(
        status: AutoTranslateStatus.blocked,
        blockReason: AutoTranslateBlockReason.noPrimary,
      );
      return;
    }

    await repo.setSecondaryTranscript(mediaId, aiId);
    if (!ref.mounted) return;

    _waiting.clear();
    state = state.copyWith(
      status: AutoTranslateStatus.active,
      clearBlockReason: true,
      aiTranscriptId: aiId,
      primaryTranscriptId: primaryRow.id,
      sourceLanguage: primaryRow.language,
      targetLanguage: native,
      failedLineIndexes: state.failedLineIndexes
          .where((i) => i >= 0 && i < primaryLines.length)
          .toSet(),
    );
  }

  /// Requests translation for a single cue when it becomes visible.
  /// Idempotent: no-op if cached, in-flight, failed, or Auto translate inactive.
  void requestTranslateLine(int lineIndex) {
    if (lineIndex < 0) return;
    if (state.status != AutoTranslateStatus.active) return;
    if (state.aiTranscriptId == null ||
        state.primaryTranscriptId == null ||
        state.targetLanguage == null) {
      return;
    }
    if (state.isLineFailed(lineIndex)) return;
    if (_inFlight.contains(lineIndex) || state.isLineInFlight(lineIndex)) {
      return;
    }
    if (_waiting.contains(lineIndex)) return;

    // Stream providers can lag behind setSecondaryTranscript; only bail when
    // secondary has a concrete non-AI id.
    final secondaryId = ref.read(secondaryTranscriptIdProvider(mediaId)).value;
    if (secondaryId != null && secondaryId != state.aiTranscriptId) return;

    if (_inFlight.length >= kAutoTranslateMaxConcurrency) {
      _enqueueWaiting(lineIndex);
      return;
    }

    unawaited(_translateLine(lineIndex, forceRefresh: false));
  }

  /// Re-translates a single cue (force-refresh). Preserves all other lines.
  Future<void> retranslateLine(int lineIndex) async {
    final aiId = state.aiTranscriptId;
    final primaryId = state.primaryTranscriptId;
    if (aiId == null || primaryId == null) return;
    if (lineIndex < 0) return;
    if (state.status != AutoTranslateStatus.active) return;

    final repo = ref.read(transcriptRepositoryProvider);
    final primaryRow = await repo.transcriptRowById(primaryId);
    if (primaryRow == null) return;
    final primaryLines = repo.linesForRow(primaryRow);
    if (lineIndex >= primaryLines.length) return;

    await repo.updateAutoTranslateLineText(
      aiTranscriptId: aiId,
      lineIndex: lineIndex,
      text: '',
    );
    if (!ref.mounted) return;

    final nextFailed = Set<int>.from(state.failedLineIndexes)
      ..remove(lineIndex);
    _waiting.remove(lineIndex);
    _forceRefreshLines.add(lineIndex);
    state = state.copyWith(failedLineIndexes: nextFailed);

    if (_inFlight.contains(lineIndex)) return;
    if (_inFlight.length >= kAutoTranslateMaxConcurrency) {
      _enqueueWaiting(lineIndex, preferFront: true);
      return;
    }
    unawaited(_translateLine(lineIndex, forceRefresh: true));
  }

  Future<void> _handlePrimaryChanged() async {
    final aiId = state.aiTranscriptId;
    final native = state.targetLanguage;
    if (aiId == null || native == null) return;

    final repo = ref.read(transcriptRepositoryProvider);
    final primaryRow = await repo.primaryTranscriptRowForMedia(mediaId);
    if (primaryRow == null) {
      if (!ref.mounted) return;
      state = state.copyWith(
        status: AutoTranslateStatus.blocked,
        blockReason: AutoTranslateBlockReason.noPrimary,
      );
      return;
    }

    final primaryLines = repo.linesForRow(primaryRow);
    await repo.ensureAutoTranslateTrack(
      mediaId: mediaId,
      primaryTranscriptId: primaryRow.id,
      targetLanguage: native,
      primaryLines: primaryLines,
    );
    await repo.setSecondaryTranscript(mediaId, aiId);
    if (!ref.mounted) return;

    _clearInFlightTracking();
    state = state.copyWith(
      status: AutoTranslateStatus.active,
      clearBlockReason: true,
      primaryTranscriptId: primaryRow.id,
      sourceLanguage: primaryRow.language,
      failedLineIndexes: const {},
    );
  }

  Future<void> _translateLine(
    int lineIndex, {
    required bool forceRefresh,
  }) async {
    final aiId = state.aiTranscriptId;
    final primaryId = state.primaryTranscriptId;
    final targetLang = state.targetLanguage;
    if (aiId == null || primaryId == null || targetLang == null) return;

    _inFlight.add(lineIndex);
    _publishInFlight();

    try {
      for (
        var attempt = 1;
        attempt <= kAutoTranslateMaxLineAttempts;
        attempt++
      ) {
        if (!ref.mounted) return;
        if (state.status != AutoTranslateStatus.active) return;
        final secondaryNow = ref
            .read(secondaryTranscriptIdProvider(mediaId))
            .value;
        if (secondaryNow != null && secondaryNow != aiId) return;

        final repo = ref.read(transcriptRepositoryProvider);
        final primaryRow = await repo.transcriptRowById(primaryId);
        final aiRow = await repo.transcriptRowById(aiId);
        if (primaryRow == null || aiRow == null) return;
        if (lineIndex >= repo.linesForRow(primaryRow).length) return;

        if (repo.isAutoTranslateTrackStale(
          aiRow: aiRow,
          primaryId: primaryId,
          primaryLines: repo.linesForRow(primaryRow),
        )) {
          if (!ref.mounted) return;
          state = state.copyWith(
            status: AutoTranslateStatus.blocked,
            blockReason: AutoTranslateBlockReason.stalePrimary,
          );
          return;
        }

        final primaryLines = repo.linesForRow(primaryRow);
        final aiLines = repo.linesForRow(aiRow);
        final sourceLang = primaryRow.language;
        final primaryLine = primaryLines[lineIndex];
        final plain = plainTextFromSubtitleMarkup(primaryLine.text).trim();
        if (plain.isEmpty) {
          // Nothing to translate — leave empty permanently.
          return;
        }

        final sourceKey = autoTranslateSourceKey(
          primaryText: primaryLine.text,
          sourceLanguage: sourceLang,
          targetLanguage: targetLang,
        );

        final useForce = forceRefresh || _forceRefreshLines.remove(lineIndex);
        if (!useForce) {
          final existing = resolveAutoTranslateSecondaryText(
            primaryLines: primaryLines,
            aiLines: aiLines,
            lineIndex: lineIndex,
            sourceLanguage: sourceLang,
            targetLanguage: targetLang,
          );
          if (existing != null) return;

          final reused = findCachedAutoTranslateText(
            aiLines: aiLines,
            key: sourceKey,
          );
          if (reused != null) {
            await repo.updateAutoTranslateLineText(
              aiTranscriptId: aiId,
              lineIndex: lineIndex,
              text: reused,
              sourceKey: sourceKey,
            );
            return;
          }
        }

        try {
          final result = await ref
              .read(translationServiceProvider)
              .translate(
                text: plain,
                sourceLanguage: sourceLang,
                targetLanguage: targetLang,
                forceRefresh: useForce,
              );

          if (!ref.mounted) return;
          final secondaryAfter = ref
              .read(secondaryTranscriptIdProvider(mediaId))
              .value;
          if (secondaryAfter != null && secondaryAfter != aiId) return;

          await repo.updateAutoTranslateLineText(
            aiTranscriptId: aiId,
            lineIndex: lineIndex,
            text: result.translatedText,
            sourceKey: sourceKey,
          );
          return;
        } on AuthFailure {
          if (!ref.mounted) return;
          state = state.copyWith(
            status: AutoTranslateStatus.blocked,
            blockReason: AutoTranslateBlockReason.auth,
          );
          return;
        } on CreditsFailure {
          if (!ref.mounted) return;
          state = state.copyWith(
            status: AutoTranslateStatus.blocked,
            blockReason: AutoTranslateBlockReason.credits,
          );
          return;
        } catch (e, st) {
          if (attempt >= kAutoTranslateMaxLineAttempts) {
            _log.warning(
              'auto-translate line $lineIndex failed after '
              '$kAutoTranslateMaxLineAttempts attempts: $e',
            );
            if (!ref.mounted) return;
            final nextFailed = Set<int>.from(state.failedLineIndexes)
              ..add(lineIndex);
            state = state.copyWith(failedLineIndexes: nextFailed);
            return;
          }
          _log.warning(
            'auto-translate line $lineIndex attempt $attempt failed, retrying: $e',
          );
          _log.fine('auto-translate line $lineIndex stack', e, st);
        }
      }
    } finally {
      _inFlight.remove(lineIndex);
      if (ref.mounted) {
        _publishInFlight();
        _drainWaiting();
      }
    }
  }

  void _drainWaiting() {
    _reprioritizeWaiting();
    while (_waiting.isNotEmpty &&
        _inFlight.length < kAutoTranslateMaxConcurrency) {
      final next = _waiting.removeFirst();
      if (_inFlight.contains(next) || state.isLineFailed(next)) continue;
      unawaited(
        _translateLine(next, forceRefresh: _forceRefreshLines.contains(next)),
      );
    }
  }

  void _enqueueWaiting(int lineIndex, {bool preferFront = false}) {
    if (_waiting.contains(lineIndex)) {
      _reprioritizeWaiting();
      return;
    }
    if (preferFront) {
      _waiting.addFirst(lineIndex);
    } else {
      _waiting.add(lineIndex);
    }
    _reprioritizeWaiting();
  }

  /// Keep waiting work near the playback cue so seek jumps the queue ahead
  /// of earlier cache-extent requests.
  void _reprioritizeWaiting({int? anchor}) {
    if (_waiting.isEmpty) return;
    final int raw =
        anchor ??
        ref.read(transcriptPlaybackHighlightProvider(mediaId)).cueIndex;
    final focus = raw < 0 ? 0 : raw;
    // Drop backlog far from the cue so a mid-video seek does not keep
    // draining early lines that were queued from the list cache extent.
    final nearby = _waiting
        .where((i) => (i - focus).abs() <= kAutoTranslateViewportWindow)
        .toList();
    final ordered = orderPendingLineIndexes(
      anchorIndex: focus,
      pending: nearby,
    );
    _waiting
      ..clear()
      ..addAll(ordered);
  }

  void _publishInFlight() {
    state = state.copyWith(inFlightIndexes: Set<int>.from(_inFlight));
  }

  void _clearInFlightTracking() {
    _waiting.clear();
    _forceRefreshLines.clear();
    // In-flight futures finish and no-op via secondary/status checks.
    _inFlight.clear();
    if (ref.mounted) {
      state = state.copyWith(inFlightIndexes: const {});
    }
  }
}

/// Whether [secondaryId] is the auto-translate AI track for [mediaId].
@riverpod
Future<bool> isAutoTranslateSecondary(
  Ref ref,
  String mediaId,
  String? secondaryId,
) async {
  if (secondaryId == null) return false;
  final row = await ref
      .read(transcriptRepositoryProvider)
      .transcriptRowById(secondaryId);
  return row?.source == 'ai';
}

/// Predicted AI track id for picker radio value (may not exist in DB yet).
@riverpod
Future<String?> autoTranslateSelectionId(Ref ref, String mediaId) async {
  final auth = ref.watch(authCtrlProvider).valueOrNull;
  if (auth is! AuthSignedIn) return null;
  final native = ref
      .watch(appPreferencesCtrlProvider)
      .valueOrNull
      ?.effectiveNativeLanguage;
  if (native == null || native.isEmpty) return null;

  final db = ref.read(appDatabaseProvider);
  final tt = await dexieTargetTypeForId(db, mediaId);
  if (tt == null) return null;

  return autoTranslateAiTrackId(
    targetType: tt,
    mediaId: mediaId,
    targetLanguage: native,
  );
}
