/// Persisted onboarding tip progress for the signed-in user.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_progress.dart';

part 'onboarding_progress_provider.g.dart';

final _log = logNamed('OnboardingProgress');

@Riverpod(keepAlive: true)
class OnboardingProgress extends _$OnboardingProgress {
  @override
  Future<TipProgressSnapshot> build() async {
    final db = ref.watch(appDatabaseProvider);
    final raw = await db.settingsDao.getValue(
      SettingsKeys.onboardingTipProgressV1,
    );
    final global = TipProgressSnapshot.decodeGlobalJson(raw);

    // Load per-media keys by scanning is expensive; we load lazily via
    // mark/status APIs. Snapshot starts with empty media map; callers that
    // need a media status call [statusOfEmptyTranscript] which hits the DB
    // when missing from cache after [ensureEmptyTranscriptLoaded].
    return TipProgressSnapshot(global: global);
  }

  TipStatus statusOfGlobal(OnboardingTipId tip) {
    final snap = state.asData?.value;
    if (snap == null) return TipStatus.pending;
    return snap.statusOfGlobal(tip);
  }

  Future<TipStatus> statusOfEmptyTranscript(String mediaId) async {
    final snap = state.asData?.value;
    if (snap != null && snap.emptyTranscriptByMediaId.containsKey(mediaId)) {
      return snap.statusOfEmptyTranscript(mediaId);
    }
    final db = ref.read(appDatabaseProvider);
    final raw = await db.settingsDao.getValue(
      SettingsKeys.onboardingEmptyTranscript(mediaId),
    );
    final status = TipStatus.parse(raw);
    final current = state.asData?.value ?? const TipProgressSnapshot();
    state = AsyncData(
      current.copyWith(
        emptyTranscriptByMediaId: {
          ...current.emptyTranscriptByMediaId,
          mediaId: status,
        },
      ),
    );
    return status;
  }

  Future<void> markGlobal(OnboardingTipId tip, TipStatus status) async {
    if (status == TipStatus.pending) return;
    final db = ref.read(appDatabaseProvider);
    // Re-read from DB so concurrent tip updates (e.g. import + craft) cannot
    // clobber each other with a stale in-memory snapshot.
    final raw = await db.settingsDao.getValue(
      SettingsKeys.onboardingTipProgressV1,
    );
    final fromDb = TipProgressSnapshot.decodeGlobalJson(raw);
    final memory =
        state.asData?.value.global ?? const <String, TipStatus>{};
    final nextGlobal = <String, TipStatus>{
      ...fromDb,
      ...memory,
      tip.id: status,
    };
    await db.settingsDao.setValue(
      SettingsKeys.onboardingTipProgressV1,
      TipProgressSnapshot.encodeGlobalJson(nextGlobal),
    );
    final current = state.asData?.value ?? const TipProgressSnapshot();
    state = AsyncData(current.copyWith(global: nextGlobal));
    _log.fine('markGlobal ${tip.id}=${status.storageValue}');
  }

  Future<void> markEmptyTranscript(String mediaId, TipStatus status) async {
    if (mediaId.isEmpty || status == TipStatus.pending) return;
    final db = ref.read(appDatabaseProvider);
    await db.settingsDao.setValue(
      SettingsKeys.onboardingEmptyTranscript(mediaId),
      status.storageValue,
    );
    final current = state.asData?.value ?? const TipProgressSnapshot();
    state = AsyncData(
      current.copyWith(
        emptyTranscriptByMediaId: {
          ...current.emptyTranscriptByMediaId,
          mediaId: status,
        },
      ),
    );
    _log.fine('markEmptyTranscript $mediaId=${status.storageValue}');
  }

  Future<void> resetAll() async {
    final db = ref.read(appDatabaseProvider);
    await db.settingsDao.deleteValue(SettingsKeys.onboardingTipProgressV1);
    await db.settingsDao.deleteKeysWithPrefix(
      SettingsKeys.onboardingEmptyTranscriptPrefix,
    );
    state = const AsyncData(TipProgressSnapshot());
    _log.info('resetAll tip progress');
  }
}
