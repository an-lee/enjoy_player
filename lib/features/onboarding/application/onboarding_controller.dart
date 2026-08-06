/// Single-flight onboarding tip start / complete / dismiss orchestration.
library;

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/onboarding/application/onboarding_progress_provider.dart';
import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_eligibility.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_progress.dart';
import 'package:enjoy_player/features/onboarding/presentation/onboarding_keys.dart';

part 'onboarding_controller.g.dart';

final _log = logNamed('OnboardingController');

@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  bool _active = false;
  bool _completedByTarget = false;
  bool _presented = false;
  OnboardingTipId? _activeTip;
  String? _activeMediaId;
  TriggerContext? _lastPracticeCtx;
  TriggerContext? _lastHomeCtx;

  @override
  int build() => 0;

  bool get isActive => _active;

  Future<void> tryStartHomeEntries(TriggerContext ctx) async {
    _lastHomeCtx = ctx;
    if (_active) return;
    final progress = await ref.read(onboardingProgressProvider.future);
    if (!TipEligibility.homeEntriesEligible(ctx, progress)) return;
    final tips = TipEligibility.pendingHomeTips(progress);
    if (tips.isEmpty) return;
    await _startTip(tips.first, mediaId: null);
  }

  Future<void> tryStartEmptyTranscript(TriggerContext ctx) async {
    if (_active) return;
    // Never start while transcript is still loading — target Showcase is absent
    // and skipIfTargetNotPresent would finish instantly and poison progress.
    if (ctx.hasTranscript) return;
    final progress = await ref.read(onboardingProgressProvider.future);
    if (!TipEligibility.emptyTranscriptEligible(ctx, progress)) return;
    final tip = TipEligibility.emptyTranscriptTip(isYoutube: ctx.isYoutube);
    _activeMediaId = ctx.mediaId;
    await _startTip(tip, mediaId: ctx.mediaId);
  }

  Future<void> tryStartPracticeChain(TriggerContext ctx) async {
    _lastPracticeCtx = ctx;
    if (_active) return;
    var progress = await ref.read(onboardingProgressProvider.future);

    if (TipEligibility.shouldSoftCompleteEcho(ctx, progress)) {
      await ref
          .read(onboardingProgressProvider.notifier)
          .markGlobal(OnboardingTipId.playerEcho, TipStatus.completed);
      progress = await ref.read(onboardingProgressProvider.future);
    }

    var tip = TipEligibility.nextPracticeTipToShow(ctx, progress);
    if (tip == null) return;
    if (tip == OnboardingTipId.playerEcho && ctx.echoActive) {
      await ref
          .read(onboardingProgressProvider.notifier)
          .markGlobal(OnboardingTipId.playerEcho, TipStatus.completed);
      progress = await ref.read(onboardingProgressProvider.future);
      tip = TipEligibility.nextPracticeTipToShow(ctx, progress);
      if (tip == null) return;
    }
    await _startTip(tip, mediaId: ctx.mediaId);
  }

  Future<void> onTranscriptAvailable(String mediaId) async {
    if (mediaId.isEmpty) return;
    await ref
        .read(onboardingProgressProvider.notifier)
        .markEmptyTranscript(mediaId, TipStatus.completed);
    if (_active &&
        _activeTip?.isPerMedia == true &&
        _activeMediaId == mediaId) {
      dismissActive();
    }
  }

  /// Called from ShowcaseView.onStart once a tip overlay is actually shown.
  void onShowcaseStarted() {
    _presented = true;
  }

  Future<void> _startTip(
    OnboardingTipId tip, {
    required String? mediaId,
  }) async {
    if (_active) return;
    final key = OnboardingKeys.keyFor(tip);

    // Wait until the Showcase target is mounted; starting earlier races the
    // empty/loading player UI and marks tips completed via skip/finish.
    final mounted = await _waitForTarget(key);
    if (!mounted) {
      _log.fine('defer startShowCase ${tip.id}: target not mounted');
      return;
    }
    if (_active) return;

    final completerDone = _scheduleStartShowCase(tip, mediaId: mediaId);
    await completerDone;
  }

  Future<bool> _waitForTarget(GlobalKey key, {int maxFrames = 48}) async {
    // ShowcaseView stores the GlobalKey as showcaseKey and does NOT attach it
    // to the Element — key.currentContext is always null. Use the package's
    // registration check instead.
    for (var i = 0; i < maxFrames; i++) {
      if (_isTargetRendered(key)) return true;
      await _endOfFrame();
      if (!ref.mounted) return false;
    }
    return _isTargetRendered(key);
  }

  bool _isTargetRendered(GlobalKey key) {
    try {
      return ShowcaseView.get().isTargetRendered(key);
    } on Object {
      return false;
    }
  }

  Future<void> _endOfFrame() {
    final binding = SchedulerBinding.instance;
    final completer = _FrameCompleter();
    binding.scheduleFrameCallback((_) {
      completer.complete();
    });
    binding.scheduleFrame();
    return completer.future;
  }

  Future<void> _scheduleStartShowCase(
    OnboardingTipId tip, {
    required String? mediaId,
  }) {
    final done = _FrameCompleter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_active || !ref.mounted) {
        done.complete();
        return;
      }
      final key = OnboardingKeys.keyFor(tip);
      if (!_isTargetRendered(key)) {
        _log.fine('abort startShowCase ${tip.id}: target lost');
        done.complete();
        return;
      }
      try {
        _active = true;
        _presented = false;
        _completedByTarget = false;
        _activeTip = tip;
        _activeMediaId = mediaId;
        state++;
        ShowcaseView.get().startShowCase([key]);
        _log.fine('startShowCase ${tip.id}');
      } on Object catch (e, st) {
        _active = false;
        _presented = false;
        _activeTip = null;
        _activeMediaId = null;
        _log.warning('startShowCase failed: $e', e, st);
      } finally {
        done.complete();
      }
    });
    return done.future;
  }

  void onShowcaseFinished() {
    // Finished via next/natural end — treat as completed for active tip.
    unawaited(_finalizeActive(completed: true, chainNext: true));
  }

  void onShowcaseDismissed(GlobalKey? key) {
    unawaited(_finalizeActive(completed: false, chainNext: false));
  }

  Future<void> onTargetActed(OnboardingTipId tip) async {
    // disposeOnTap dismisses; onDismiss will also fire — prefer completed.
    _completedByTarget = true;
    _presented = true;
    final progress = ref.read(onboardingProgressProvider.notifier);
    if (tip.isPerMedia) {
      final mediaId = _activeMediaId;
      if (mediaId != null) {
        await progress.markEmptyTranscript(mediaId, TipStatus.completed);
      }
    } else {
      await progress.markGlobal(tip, TipStatus.completed);
    }
  }

  Future<void> _finalizeActive({
    required bool completed,
    required bool chainNext,
  }) async {
    if (!_active && _activeTip == null) return;
    final tip = _activeTip;
    final mediaId = _activeMediaId;
    final treatedComplete = completed || _completedByTarget;
    final wasPresented = _presented || _completedByTarget;
    _active = false;
    _completedByTarget = false;
    _presented = false;
    _activeTip = null;
    _activeMediaId = null;
    state++;
    if (tip == null) return;

    // Ghost finish (target missing / skip) must not poison tip progress.
    if (!wasPresented) {
      _log.fine('ignore unpresented finish for ${tip.id}');
      return;
    }

    final progress = ref.read(onboardingProgressProvider.notifier);
    final already = tip.isPerMedia
        ? (mediaId == null
              ? TipStatus.pending
              : await progress.statusOfEmptyTranscript(mediaId))
        : progress.statusOfGlobal(tip);

    if (!already.isResolved) {
      final status = treatedComplete ? TipStatus.completed : TipStatus.skipped;
      if (tip.isPerMedia) {
        if (mediaId != null) {
          await progress.markEmptyTranscript(mediaId, status);
        }
      } else {
        await progress.markGlobal(tip, status);
      }
    }

    if (!chainNext || !treatedComplete) return;

    // Chain next home / practice tip in the same visit.
    final homeCtx = _lastHomeCtx;
    if (homeCtx != null && tip.sequenceId == OnboardingSequenceId.homeEntries) {
      await tryStartHomeEntries(homeCtx);
      return;
    }
    final practiceCtx = _lastPracticeCtx;
    if (practiceCtx != null &&
        tip.sequenceId == OnboardingSequenceId.playerPractice) {
      await tryStartPracticeChain(practiceCtx);
    }
  }

  void dismissActive() {
    if (!_active) return;
    try {
      ShowcaseView.get().dismiss();
    } on Object catch (e, st) {
      _log.fine('dismissActive: $e', e, st);
      unawaited(_finalizeActive(completed: false, chainNext: false));
    }
  }

  void onRouteOrMediaChanged() {
    dismissActive();
  }
}

void unawaited(Future<void> future) {
  future.ignore();
}

class _FrameCompleter {
  final _c = Completer<void>();
  Future<void> get future => _c.future;
  void complete() {
    if (!_c.isCompleted) _c.complete();
  }
}
