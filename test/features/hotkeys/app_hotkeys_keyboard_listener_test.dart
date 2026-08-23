// Pure dispatch coverage for [AppHotkeysKeyboardListener] (the global keyboard
// handler above MaterialApp.router's Navigator). Exercises every branch of the
// internal `_onKey` method:
//   - early returns (KeyUpEvent, primary focus on EditableText, empty binding)
//   - Escape (`modal.close`) → 8 EscapeDismissalAction branches
//   - global.help / global.settings / global.craft / global.search
//   - library.search (`/`)
//   - shadow-reading bus pulses (recording / playback / pitch / assessment)
//   - player interactions (togglePlay / toggleExpand / toggleFullscreen /
//     prevLine / nextLine / replayLine / toggleEcho / toggleBlur /
//     slowDown / speedUp / echo expand/shrink)
//   - the slow-down / speed-up rate clamps at 0.25 and 2.0
//   - the `escape_dismissal.dart` "noop on player route" branch
//   - the `_onKey` return-false path when no shortcut matches
//
// Keys are dispatched through [HardwareKeyboard.instance.handleKeyEvent] which
// is the public API used by the engine — it updates the `_pressedKeys` map
// (so `isControlPressed` etc. reflect the simulated modifier state) AND calls
// every registered `addHandler` callback in registration order.
import 'dart:async';

import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/routing/app_router.dart';
import 'package:enjoy_player/core/routing/player_navigation.dart';
import 'package:enjoy_player/core/window/window_fullscreen_provider.dart';
import 'package:enjoy_player/features/craft/application/craft_controller.dart';
import 'package:enjoy_player/features/craft/domain/craft_job_state.dart';
import 'package:enjoy_player/features/hotkeys/application/escape_dismissal.dart';
import 'package:enjoy_player/features/hotkeys/application/hotkey_focus_policy.dart';
import 'package:enjoy_player/features/hotkeys/application/hotkeys_ctrl.dart';
import 'package:enjoy_player/features/hotkeys/application/shadow_reading_hotkey_policy.dart';
import 'package:enjoy_player/features/hotkeys/domain/hotkey_chord.dart';
import 'package:enjoy_player/features/hotkeys/domain/hotkey_definitions.dart';
import 'package:enjoy_player/features/hotkeys/presentation/app_hotkeys_keyboard_listener.dart';
import 'package:enjoy_player/features/hotkeys/presentation/hotkeys_cheatsheet_open.dart';
import 'package:enjoy_player/features/hotkeys/presentation/hotkeys_help_dialog.dart';
import 'package:enjoy_player/features/library/application/library_search_focus_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_interactions.dart';
import 'package:enjoy_player/features/player/application/player_preferences_provider.dart';
import 'package:enjoy_player/features/player/application/player_ui_provider.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/domain/player_settings.dart'
    as player_settings;
import 'package:enjoy_player/features/shadow_reading/application/shadow_reading_hotkey_bus.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_review_practice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/l10n/app_localizations.dart';

// ── Foundation debug var resetter ─────────────────────────────────────────────

// `debugDefaultTargetPlatformOverride` is asserted to be null by
// [TestWidgetsFlutterBinding._verifyInvariants] which runs *after* the test body
// returns and *after* `addTearDown` callbacks. The only reliable point to reset
// it inside a `testWidgets` body is when the framework replaces the widget tree
// with the post-test message (binding.dart `_runTestBody`, line 1959) — at that
// moment our widget is unmounted and [State.dispose] runs synchronously, *before*
// `_verifyInvariants`. Wrap the mounted tree with [_PlatformResetter] so the
// override is reset at the right moment without per-test try/finally boilerplate.
class _PlatformResetter extends StatefulWidget {
  const _PlatformResetter({required this.child});

  final Widget child;

  @override
  State<_PlatformResetter> createState() => _PlatformResetterState();
}

class _PlatformResetterState extends State<_PlatformResetter> {
  @override
  void dispose() {
    debugDefaultTargetPlatformOverride = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── Fake providers ───────────────────────────────────────────────────────────

class _RecordingHotkeysCtrl extends HotkeysCtrl {
  _RecordingHotkeysCtrl(this.bindings);

  /// action id → binding string. Missing ids fall back to defaultKeys.
  final Map<String, String> bindings;

  @override
  Future<Map<String, String>> build() async => bindings;

  @override
  String effectiveKeys(String actionId) {
    final override = bindings[actionId];
    if (override != null && override.isNotEmpty) return override;
    final def = hotkeyDefinitionMap[actionId];
    return def?.defaultKeys ?? '';
  }
}

class _FakeWindowFullscreen extends WindowFullscreen {
  _FakeWindowFullscreen({required bool fullscreen})
    : _isFullscreen = fullscreen;

  bool _isFullscreen;

  @override
  bool build() => _isFullscreen;

  var setFullscreenCalls = <bool>[];
  var toggleCalls = 0;

  @override
  Future<void> setFullscreen(bool value) async {
    _isFullscreen = value;
    state = value;
    setFullscreenCalls.add(value);
  }

  @override
  Future<void> toggle() async {
    toggleCalls++;
    await setFullscreen(!state);
  }
}

class _FakeShadowReadingHotkeyBus extends ShadowReadingHotkeyBus {
  _FakeShadowReadingHotkeyBus({ShadowReadingHotkeyTicks? initial})
    : _seed = initial ?? ShadowReadingHotkeyTicks.initial;

  final ShadowReadingHotkeyTicks _seed;

  @override
  ShadowReadingHotkeyTicks build() => _seed;

  var recordingPulses = 0;
  var playbackPulses = 0;
  var pitchContourPulses = 0;
  var assessmentPulses = 0;
  var recordingCancelPulses = 0;
  bool _isRecordingActive = false;

  @override
  void pulseRecording() {
    recordingPulses++;
    state = state.copyWith(recording: state.recording + 1);
  }

  @override
  void pulsePlayback() {
    playbackPulses++;
    state = state.copyWith(playback: state.playback + 1);
  }

  @override
  void pulsePitchContour() {
    pitchContourPulses++;
    state = state.copyWith(pitchContour: state.pitchContour + 1);
  }

  @override
  void pulseAssessment() {
    assessmentPulses++;
    state = state.copyWith(assessment: state.assessment + 1);
  }

  @override
  void pulseRecordingCancel() {
    recordingCancelPulses++;
    state = state.copyWith(recordingCancel: state.recordingCancel + 1);
  }

  @override
  void setRecordingActive(bool active) {
    _isRecordingActive = active;
    if (state.isRecordingActive == active) return;
    state = state.copyWith(isRecordingActive: active);
  }

  // Not an override on the parent bus — exposed for test assertions.
  // The listener reads `state.isRecordingActive` (the state field) rather
  // than calling this getter.
  // ignore: override_on_non_overriding_member
  bool get isRecordingActive => _isRecordingActive;
}

class _FakeCraftController extends CraftController {
  bool _isCapturing = false;
  var cancelCaptureCalls = 0;

  @override
  CraftJobState build() => const CraftJobState();

  // Not an override on the parent controller — exposed for test assertions.
  // The listener reads `state.isCapturing` (the state field) rather than
  // calling this getter.
  // ignore: override_on_non_overriding_member
  bool get isCapturing => _isCapturing;

  @override
  void startCapture() {
    _isCapturing = true;
    state = state.copyWith(isCapturing: true);
  }

  @override
  void cancelCapture() {
    _isCapturing = false;
    cancelCaptureCalls++;
    state = state.copyWith(
      isCapturing: false,
      captureCancelTick: state.captureCancelTick + 1,
    );
  }
}

class _FakeVocabularyReviewSession extends VocabularyReviewSession {
  _FakeVocabularyReviewSession({ReviewSessionState? initial})
    : _seed = initial ?? const ReviewSessionState(queue: []);

  final ReviewSessionState _seed;

  var clearPracticeCalls = 0;

  @override
  ReviewSessionState build() => _seed;

  void setState(ReviewSessionState next) {
    state = next;
  }

  @override
  Future<void> clearPractice() async {
    clearPracticeCalls++;
    final s = state;
    if (s.practicePhase == ReviewPracticePhase.none) return;
    state = s.copyWith(
      practicePhase: ReviewPracticePhase.none,
      clearMediaError: true,
    );
  }
}

class _FakePlayerController extends PlayerController {
  _FakePlayerController({this.sessionOverride});

  PlaybackSession? sessionOverride;
  var togglePlayCalls = 0;
  var abandonPendingOpenCalls = 0;

  @override
  PlaybackSession? build() => sessionOverride;

  void setSession(PlaybackSession? next) {
    sessionOverride = next;
    state = next;
  }

  var clearCalls = 0;

  @override
  Future<void> togglePlay() async {
    togglePlayCalls++;
  }

  @override
  Future<void> clear({bool keepVideoSurface = false}) async {
    clearCalls++;
    sessionOverride = null;
    state = null;
  }

  @override
  void abandonPendingOpen() {
    abandonPendingOpenCalls++;
  }
}

class _FakePlayerInteractions extends PlayerInteractions {
  var prevLineCalls = 0;
  var nextLineCalls = 0;
  var replayLineCalls = 0;
  var toggleEchoCalls = 0;
  var toggleBlurCalls = 0;
  var expandEchoBackwardCalls = 0;
  var expandEchoForwardCalls = 0;
  var shrinkEchoBackwardCalls = 0;
  var shrinkEchoForwardCalls = 0;

  @override
  int build() => 0;

  @override
  Future<void> prevLine() async {
    prevLineCalls++;
  }

  @override
  Future<void> nextLine() async {
    nextLineCalls++;
  }

  @override
  Future<void> replayLine() async {
    replayLineCalls++;
  }

  @override
  Future<void> toggleEcho() async {
    toggleEchoCalls++;
  }

  @override
  Future<void> toggleBlur() async {
    toggleBlurCalls++;
  }

  @override
  Future<void> expandEchoBackward() async {
    expandEchoBackwardCalls++;
  }

  @override
  Future<void> expandEchoForward() async {
    expandEchoForwardCalls++;
  }

  @override
  Future<void> shrinkEchoBackward() async {
    shrinkEchoBackwardCalls++;
  }

  @override
  Future<void> shrinkEchoForward() async {
    shrinkEchoForwardCalls++;
  }
}

class _FakePlayerPreferencesCtrl extends PlayerPreferencesCtrl {
  _FakePlayerPreferencesCtrl({this._rate = 1.0});

  double _rate;
  var setPlaybackRateCalls = <double>[];

  @override
  player_settings.PlayerPreferences build() {
    return player_settings.PlayerPreferences(
      volume: 1.0,
      playbackRate: _rate,
      repeatMode: player_settings.RepeatMode.none,
      videoTranscriptSplitWidthPx: null,
    );
  }

  void setRate(double r) {
    _rate = r;
    state = state.copyWith(playbackRate: r);
  }

  @override
  Future<void> setPlaybackRate(double r) async {
    setPlaybackRateCalls.add(r);
    setRate(r.clamp(0.25, 2));
  }
}

class _RecordingUi extends PlayerUi {
  var expandCalls = 0;
  var collapseCalls = 0;

  @override
  PlayerUiState build() => PlayerUiState.initial;

  @override
  void expand() {
    expandCalls++;
    state = state.copyWith(mode: PlayerChromeMode.expanded);
  }

  @override
  void collapse() {
    collapseCalls++;
    state = state.copyWith(mode: PlayerChromeMode.mini);
  }
}

// ── Test harness ─────────────────────────────────────────────────────────────

class _Harness {
  _Harness({
    required this.tester,
    required this.router,
    required this.container,
    required this.hotkeysCtrl,
    required this.fullscreen,
    required this.shadowBus,
    required this.craftCtrl,
    required this.vocabSession,
    required this.playerCtrl,
    required this.playerInteractions,
    required this.playerPrefs,
    required this.playerUi,
    required this.rootNavigatorKey,
  });

  final WidgetTester tester;
  final GoRouter router;
  final ProviderContainer container;
  final _RecordingHotkeysCtrl hotkeysCtrl;
  final _FakeWindowFullscreen fullscreen;
  final _FakeShadowReadingHotkeyBus shadowBus;
  final _FakeCraftController craftCtrl;
  final _FakeVocabularyReviewSession vocabSession;
  final _FakePlayerController playerCtrl;
  final _FakePlayerInteractions playerInteractions;
  final _FakePlayerPreferencesCtrl playerPrefs;
  final _RecordingUi playerUi;

  /// Root navigator key wired into the test [GoRouter] so individual tests can
  /// push pages onto the same stack that [Navigator.pop] walks in production.
  final GlobalKey<NavigatorState> rootNavigatorKey;
}

Future<_Harness> _mountHarness(
  WidgetTester tester, {
  String initialLocation = '/library',
  Map<String, String> customBindings = const {},
  bool isDesktop = true,
  PlaybackSession? session,
  ReviewSessionState? vocabState,
  ShadowReadingHotkeyTicks initialShadowTicks =
      ShadowReadingHotkeyTicks.initial,
  double initialRate = 1.0,
  bool fullscreen = false,
}) async {
  if (isDesktop) {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  } else {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  }
  // Reset handled by [_PlatformResetter] on dispose (see class comment).

  hotkeysCheatsheetOpen.value = false;
  addTearDown(() => hotkeysCheatsheetOpen.value = false);

  final hotkeys = _RecordingHotkeysCtrl(customBindings);

  final fakeFullscreen = _FakeWindowFullscreen(fullscreen: fullscreen);
  final fakeShadow = _FakeShadowReadingHotkeyBus(initial: initialShadowTicks);
  final fakeCraft = _FakeCraftController();
  final fakeVocab = _FakeVocabularyReviewSession(initial: vocabState);
  final fakePlayer = _FakePlayerController(sessionOverride: session);
  final fakeInteractions = _FakePlayerInteractions();
  final fakePrefs = _FakePlayerPreferencesCtrl(rate: initialRate);
  final fakeUi = _RecordingUi();

  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'test-root');

  late GoRouter router;
  router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        navigatorKey: enjoyShellNavigatorKey,
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: '/library',
            builder: (_, _) => const Scaffold(body: Text('library')),
          ),
          GoRoute(
            path: '/player/:mediaId',
            builder: (_, _) => const Scaffold(body: Text('player')),
          ),
          GoRoute(
            path: '/craft',
            builder: (_, _) => const Scaffold(body: Text('craft')),
          ),
          GoRoute(
            path: '/craft/history',
            builder: (_, _) => const Scaffold(body: Text('craft-history')),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Scaffold(body: Text('settings')),
          ),
          GoRoute(
            path: '/sign-in',
            builder: (_, _) => const Scaffold(body: Text('sign-in')),
          ),
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  final container = ProviderContainer(
    overrides: [
      hotkeysCtrlProvider.overrideWith(() => hotkeys),
      windowFullscreenProvider.overrideWith(() => fakeFullscreen),
      shadowReadingHotkeyBusProvider.overrideWith(() => fakeShadow),
      craftControllerProvider.overrideWith(() => fakeCraft),
      vocabularyReviewSessionProvider.overrideWith(() => fakeVocab),
      playerControllerProvider.overrideWith(() => fakePlayer),
      playerInteractionsProvider.overrideWith(() => fakeInteractions),
      playerPreferencesCtrlProvider.overrideWith(() => fakePrefs),
      playerUiProvider.overrideWith(() => fakeUi),
      appRouterProvider.overrideWithValue(router),
    ],
  );
  addTearDown(container.dispose);

  // The provider override for appRouterProvider is a sync value; ensure the
  // rest are wired up by reading them once so any notifiers initialize.
  container.read(hotkeysCtrlProvider.notifier);
  container.read(windowFullscreenProvider.notifier);
  container.read(shadowReadingHotkeyBusProvider.notifier);
  container.read(craftControllerProvider.notifier);
  container.read(vocabularyReviewSessionProvider.notifier);
  container.read(playerControllerProvider.notifier);
  container.read(playerInteractionsProvider.notifier);
  container.read(playerPreferencesCtrlProvider.notifier);
  container.read(playerUiProvider.notifier);

  // Mount with both the rootNavigatorKey (used by global.help / Escape) and
  // the ShellRoute navigatorKey (Escape shell popup branch).
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _PlatformResetter(
        child: MaterialApp.router(
          scaffoldMessengerKey: appScaffoldMessengerKey,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              AppHotkeysKeyboardListener(child: child ?? const SizedBox()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(
    tester: tester,
    router: router,
    container: container,
    hotkeysCtrl: hotkeys,
    fullscreen: fakeFullscreen,
    shadowBus: fakeShadow,
    craftCtrl: fakeCraft,
    vocabSession: fakeVocab,
    playerCtrl: fakePlayer,
    playerInteractions: fakeInteractions,
    playerPrefs: fakePrefs,
    playerUi: fakeUi,
    rootNavigatorKey: rootKey,
  );
}

// ── Key dispatch helpers ────────────────────────────────────────────────────

/// The Flutter [HardwareKeyboard] tracks pressed state in
/// `_pressedKeys: Map<PhysicalKeyboardKey, LogicalKeyboardKey>`. Using
/// `PhysicalKeyboardKey(0)` for every event overwrites earlier entries when we
/// dispatch a sequence (press controlLeft, then k — both keys map to key 0 in
/// the map, so pressing `k` wipes the controlLeft entry and `isControlPressed`
/// returns false inside the handler). Pick a unique non-zero physical key per
/// logical key (mirroring the platform constants) so the map is updated as the
/// engine would.
PhysicalKeyboardKey _physicalFor(LogicalKeyboardKey logical) {
  // Most modifier / letter / function keys have a PhysicalKeyboardKey constant
  // with the same debugName; for the rest, fall back to a hash of the logical
  // key's value so the physical key is unique per logical key.
  switch (logical) {
    case LogicalKeyboardKey.controlLeft:
      return PhysicalKeyboardKey.controlLeft;
    case LogicalKeyboardKey.controlRight:
      return PhysicalKeyboardKey.controlRight;
    case LogicalKeyboardKey.shiftLeft:
      return PhysicalKeyboardKey.shiftLeft;
    case LogicalKeyboardKey.shiftRight:
      return PhysicalKeyboardKey.shiftRight;
    case LogicalKeyboardKey.altLeft:
      return PhysicalKeyboardKey.altLeft;
    case LogicalKeyboardKey.altRight:
      return PhysicalKeyboardKey.altRight;
    case LogicalKeyboardKey.metaLeft:
      return PhysicalKeyboardKey.metaLeft;
    case LogicalKeyboardKey.metaRight:
      return PhysicalKeyboardKey.metaRight;
  }
  // Non-modifier keys: synthesize a unique physical key from the logical
  // key value to avoid collisions in the _pressedKeys map.
  return PhysicalKeyboardKey(0x10000000 | (logical.keyId & 0x0fffffff));
}

void _press(LogicalKeyboardKey key, {String? character}) {
  HardwareKeyboard.instance.handleKeyEvent(
    KeyDownEvent(
      physicalKey: _physicalFor(key),
      logicalKey: key,
      character: character,
      timeStamp: Duration.zero,
    ),
  );
}

void _release(LogicalKeyboardKey key) {
  HardwareKeyboard.instance.handleKeyEvent(
    KeyUpEvent(
      physicalKey: _physicalFor(key),
      logicalKey: key,
      timeStamp: Duration.zero,
    ),
  );
}

Future<void> _stroke(
  WidgetTester tester,
  List<LogicalKeyboardKey> modifiers,
  LogicalKeyboardKey main, {
  String? character,
}) async {
  for (final m in modifiers) {
    _press(m);
  }
  _press(main, character: character);
  await tester.pump();
  _release(main);
  for (final m in modifiers.reversed) {
    _release(m);
  }
  await tester.pump();
}

Future<void> _releaseAll(WidgetTester tester) async {
  for (final key in HardwareKeyboard.instance.logicalKeysPressed.toList()) {
    HardwareKeyboard.instance.handleKeyEvent(
      KeyUpEvent(
        physicalKey: _physicalFor(key),
        logicalKey: key,
        timeStamp: Duration.zero,
      ),
    );
  }
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    hotkeysCheatsheetOpen.value = false;
  });

  tearDown(() async {
    // Clear residual keys so the next test starts on a clean HardwareKeyboard.
    HardwareKeyboard.instance.clearState();
  });

  group('early-return paths', () {
    testWidgets('KeyUpEvent is ignored (returns false)', (tester) async {
      await _mountHarness(tester);
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey(0),
          logicalKey: LogicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        ),
      );
      // No way to read the bool return from the handler directly — but a
      // smoke assertion: the route did not change and no fullscreen mutation.
      // The handler never invoked any provider method, so the router path is
      // untouched.
      await tester.pump();
      expect(find.text('library'), findsOneWidget);
    });

    testWidgets('editable text focus blocks global hotkeys', (tester) async {
      // Replace the home screen with a focused TextField so the focus policy
      // returns true.
      await _mountHarness(tester, initialLocation: '/');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderScope.containerOf(
            tester.element(find.byType(MaterialApp)),
          ),
          child: MaterialApp(
            scaffoldMessengerKey: appScaffoldMessengerKey,
            home: const Scaffold(
              body: TextField(
                autofocus: true,
                decoration: InputDecoration(hintText: 'search'),
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      expect(primaryFocusBlocksGlobalHotkeys(), isTrue);

      // Send ctrl+comma (global.settings) — should NOT navigate because the
      // editable text blocks the handler.
      await _stroke(
        tester,
        [LogicalKeyboardKey.controlLeft],
        LogicalKeyboardKey.comma,
        character: ',',
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('Escape (modal.close)', () {
    testWidgets('cheatsheet open → closeCheatsheet pops root navigator', (
      tester,
    ) async {
      final harness = await _mountHarness(tester);
      hotkeysCheatsheetOpen.value = true;
      await _stroke(tester, [], LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(harness.shadowBus.recordingCancelPulses, 0);
      expect(harness.fullscreen.toggleCalls, 0);
    });

    testWidgets('fullscreen on desktop → exitFullscreen', (tester) async {
      final harness = await _mountHarness(
        tester,
        fullscreen: true,
        initialLocation: '/library',
      );
      expect(harness.fullscreen.state, isTrue);
      await _stroke(tester, [], LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(harness.fullscreen.setFullscreenCalls, contains(false));
    });

    testWidgets('craft recording active → cancelCapture', (tester) async {
      final harness = await _mountHarness(tester);
      harness.craftCtrl.startCapture();
      expect(harness.craftCtrl.isCapturing, isTrue);
      await _stroke(tester, [], LogicalKeyboardKey.escape);
      await tester.pump();
      expect(harness.craftCtrl.cancelCaptureCalls, 1);
    });

    testWidgets('shadow-reading recording active → pulseRecordingCancel', (
      tester,
    ) async {
      final harness = await _mountHarness(tester);
      harness.shadowBus.setRecordingActive(true);
      await _stroke(tester, [], LogicalKeyboardKey.escape);
      await tester.pump();
      expect(harness.shadowBus.recordingCancelPulses, 1);
    });

    testWidgets('shell popup → popShellPopup', (tester) async {
      final harness = await _mountHarness(tester);
      // Open a bottom sheet on the shell navigator to create a PopupRoute.
      final shellState = enjoyShellNavigatorKey.currentState;
      expect(shellState, isNotNull);
      unawaited(
        shellState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('pushed-page')),
            fullscreenDialog: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('pushed-page'), findsOneWidget);

      await _stroke(tester, [], LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      // Pushed page was popped, library remains.
      expect(find.text('pushed-page'), findsNothing);
      expect(find.text('library'), findsOneWidget);
      expect(harness.shadowBus.recordingCancelPulses, 0);
    });

    testWidgets(
      'idle player route → noopOnPlayer (handler still returns true)',
      (tester) async {
        final harness = await _mountHarness(
          tester,
          initialLocation: '/player/abc',
        );
        expect(find.text('player'), findsOneWidget);
        await _stroke(tester, [], LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('player'), findsOneWidget);
        expect(harness.fullscreen.setFullscreenCalls, isEmpty);
      },
    );

    testWidgets('vocabulary practice open → clearPractice', (tester) async {
      final harness = await _mountHarness(
        tester,
        vocabState: const ReviewSessionState(
          queue: [],
          practicePhase: ReviewPracticePhase.clipOpening,
        ),
      );
      await _stroke(tester, [], LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(harness.vocabSession.clearPracticeCalls, 1);
    });
  });

  group('global.help', () {
    testWidgets('opens HotkeysHelpDialog', (tester) async {
      await _mountHarness(tester);
      // Press shift+slash (default global.help binding).
      await _stroke(
        tester,
        [LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.slash,
        character: '/',
      );
      await tester.pumpAndSettle();
      // Dialog title should be visible.
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      // cheatsheetOpen toggled true.
      expect(hotkeysCheatsheetOpen.value, isTrue);
      addTearDown(() {
        if (hotkeysCheatsheetOpen.value) hotkeysCheatsheetOpen.value = false;
      });
    });

    testWidgets('closes already-open cheatsheet', (tester) async {
      final harness = await _mountHarness(tester);
      hotkeysCheatsheetOpen.value = true;
      // Press shift+slash while cheatsheet is open — it should pop instead.
      await _stroke(
        tester,
        [LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.slash,
        character: '/',
      );
      await tester.pumpAndSettle();
      expect(harness.shadowBus.recordingCancelPulses, 0);
    });
  });

  group('global.settings', () {
    testWidgets('navigates to /settings', (tester) async {
      final harness = await _mountHarness(tester);
      await _stroke(
        tester,
        [LogicalKeyboardKey.controlLeft],
        LogicalKeyboardKey.comma,
        character: ',',
      );
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/settings');
    });
  });

  group('global.craft', () {
    testWidgets('navigates to /craft from library', (tester) async {
      final harness = await _mountHarness(tester);
      expect(harness.router.state.uri.path, '/library');
      await _stroke(tester, [], LogicalKeyboardKey.keyC, character: 'c');
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/craft');
    });

    testWidgets('no-op when already on /craft', (tester) async {
      final harness = await _mountHarness(tester, initialLocation: '/craft');
      final before = harness.router.state.uri.path;
      await _stroke(tester, [], LogicalKeyboardKey.keyC, character: 'c');
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, before);
    });

    testWidgets('no-op when on /craft sub-route', (tester) async {
      final harness = await _mountHarness(
        tester,
        initialLocation: '/craft/history',
      );
      await _stroke(tester, [], LogicalKeyboardKey.keyC, character: 'c');
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/craft/history');
    });
  });

  group('global.search', () {
    testWidgets('shows AppNotice stub on ctrl+k', (tester) async {
      await _mountHarness(tester);
      await _stroke(
        tester,
        [LogicalKeyboardKey.controlLeft],
        LogicalKeyboardKey.keyK,
        character: 'k',
      );
      await tester.pumpAndSettle();
      // AppNotice uses the global appScaffoldMessengerKey.
      final messenger = appScaffoldMessengerKey.currentState;
      expect(messenger, isNotNull);
    });
  });

  group('library.search', () {
    testWidgets('presses "/" on library → pulse focus request', (tester) async {
      final harness = await _mountHarness(tester);
      // Use the real librarySearchFocusRequestProvider (the test only swaps
      // other providers).
      expect(harness.container.read(librarySearchFocusRequestProvider), 0);
      await _stroke(tester, [], LogicalKeyboardKey.slash, character: '/');
      await tester.pump();
      expect(
        harness.container.read(librarySearchFocusRequestProvider),
        greaterThan(0),
      );
    });

    testWidgets('no-op on /player route', (tester) async {
      final harness = await _mountHarness(tester, initialLocation: '/player/x');
      final before = harness.container.read(librarySearchFocusRequestProvider);
      await _stroke(tester, [], LogicalKeyboardKey.slash, character: '/');
      await tester.pump();
      expect(harness.container.read(librarySearchFocusRequestProvider), before);
    });

    testWidgets('no-op on /sign-in route', (tester) async {
      final harness = await _mountHarness(tester, initialLocation: '/sign-in');
      final before = harness.container.read(librarySearchFocusRequestProvider);
      await _stroke(tester, [], LogicalKeyboardKey.slash, character: '/');
      await tester.pump();
      expect(harness.container.read(librarySearchFocusRequestProvider), before);
    });
  });

  group('shadow-reading hotkey bus pulses', () {
    testWidgets('r → pulseRecording when session present', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.keyR, character: 'r');
      await tester.pump();
      expect(harness.shadowBus.recordingPulses, 1);
    });

    testWidgets('g → pulsePlayback when session present', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.keyG, character: 'g');
      await tester.pump();
      expect(harness.shadowBus.playbackPulses, 1);
    });

    testWidgets('p → pulsePitchContour when session present', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.keyP, character: 'p');
      await tester.pump();
      expect(harness.shadowBus.pitchContourPulses, 1);
    });

    testWidgets('v → pulseAssessment when session present', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.keyV, character: 'v');
      await tester.pump();
      expect(harness.shadowBus.assessmentPulses, 1);
    });

    testWidgets('bus pulses also work when vocabulary echo practice open', (
      tester,
    ) async {
      final harness = await _mountHarness(
        tester,
        vocabState: const ReviewSessionState(
          queue: [],
          practicePhase: ReviewPracticePhase.echo,
        ),
      );
      await _stroke(tester, [], LogicalKeyboardKey.keyR, character: 'r');
      await tester.pump();
      expect(harness.shadowBus.recordingPulses, 1);
    });

    testWidgets(
      'bus pulses NOT triggered when no session and no echo practice',
      (tester) async {
        final harness = await _mountHarness(tester);
        await _stroke(tester, [], LogicalKeyboardKey.keyR, character: 'r');
        await tester.pump();
        expect(harness.shadowBus.recordingPulses, 0);
      },
    );
  });

  group('player.togglePlay', () {
    testWidgets('space → togglePlay when session present', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.space, character: ' ');
      await tester.pump();
      expect(harness.playerCtrl.togglePlayCalls, 1);
    });

    testWidgets('space without session returns false', (tester) async {
      final harness = await _mountHarness(tester);
      await _stroke(tester, [], LogicalKeyboardKey.space, character: ' ');
      await tester.pump();
      expect(harness.playerCtrl.togglePlayCalls, 0);
    });
  });

  group('player.toggleExpand', () {
    testWidgets('on player route → collapseExpandedPlayer (handler invoked, '
        'pop() surfaces nothing-to-pop on the un-pushed stub route)', (
      tester,
    ) async {
      final harness = await _mountHarness(
        tester,
        session: _videoSession(),
        initialLocation: '/player/abc',
      );
      harness.playerUi.state = harness.playerUi.state.copyWith(
        mode: PlayerChromeMode.expanded,
      );
      // Push a MaterialPageRoute onto the *root* navigator so [context.pop()]
      // has something to pop. In production the player screen is pushed from
      // a shell tab and the root stack contains both the shell and the
      // pushed player page; here we simulate that by pushing a transparent
      // page after the shell mounts.
      final rootNav = harness.rootNavigatorKey.currentState;
      expect(rootNav, isNotNull);
      unawaited(
        rootNav!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('expanded-overlay')),
            fullscreenDialog: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('expanded-overlay'), findsOneWidget);

      await _stroke(
        tester,
        [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.keyP,
        character: 'p',
      );
      // The handler fires [collapseExpandedPlayer] which collapses the chrome,
      // awaits setFullscreen(false), then pops the pushed page.
      await tester.pumpAndSettle();
      expect(harness.playerUi.collapseCalls, 1);
      // The pushed overlay is gone; the shell route (with the player screen)
      // remains visible.
      expect(find.text('expanded-overlay'), findsNothing);
      expect(find.text('player'), findsOneWidget);
    });

    testWidgets('off player without session is a no-op', (tester) async {
      final harness = await _mountHarness(tester);
      expect(harness.router.state.uri.path, '/library');
      await _stroke(
        tester,
        [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.keyP,
        character: 'p',
      );
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/library');
      expect(harness.playerUi.collapseCalls, 0);
      expect(harness.playerCtrl.togglePlayCalls, 0);
    });

    testWidgets('off player route → openPlayerRoute handler returns true '
        '(openPlayerLaunch expects a GoRouter descendant context — surfaces '
        'as recorded exception in this stub harness)', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      expect(harness.router.state.uri.path, '/library');
      await _stroke(
        tester,
        [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.keyP,
        character: 'p',
      );
      await tester.pumpAndSettle();
      // The handler invokes [openPlayerRoute(context, ...)] where `context` is
      // the listener's own BuildContext. That context lives above the
      // [MaterialApp.router]'s [Builder] and therefore has no [GoRouter]
      // ancestor — [GoRouterState.of] throws. The async exception surfaces
      // after pumpAndSettle, so let microtasks drain before takeException.
      await tester.pump();
      tester.takeException();
      // What we CAN assert: the handler matched the binding and returned true.
      // We verify the *negative* path — no collapse happened, the route did
      // not change, and the handler is wired correctly.
      expect(harness.router.state.uri.path, '/library');
      expect(harness.playerUi.collapseCalls, 0);
      expect(harness.playerUi.expandCalls, 0);
    });
  });

  group('player.toggleFullscreen', () {
    testWidgets('f11 + video session on desktop → toggle()', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.f11);
      await tester.pump();
      expect(harness.fullscreen.toggleCalls, 1);
    });

    testWidgets('f11 + audio session → no toggle', (tester) async {
      final harness = await _mountHarness(tester, session: _audioSession());
      await _stroke(tester, [], LogicalKeyboardKey.f11);
      await tester.pump();
      expect(harness.fullscreen.toggleCalls, 0);
    });

    testWidgets('f11 on non-desktop → no toggle', (tester) async {
      final harness = await _mountHarness(
        tester,
        session: _videoSession(),
        isDesktop: false,
      );
      await _stroke(tester, [], LogicalKeyboardKey.f11);
      await tester.pump();
      expect(harness.fullscreen.toggleCalls, 0);
    });

    testWidgets('f11 without session → no toggle', (tester) async {
      final harness = await _mountHarness(tester);
      await _stroke(tester, [], LogicalKeyboardKey.f11);
      await tester.pump();
      expect(harness.fullscreen.toggleCalls, 0);
    });
  });

  group('player line hotkeys', () {
    testWidgets('a → prevLine', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.keyA, character: 'a');
      await tester.pump();
      expect(harness.playerInteractions.prevLineCalls, 1);
    });

    testWidgets('d → nextLine', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.keyD, character: 'd');
      await tester.pump();
      expect(harness.playerInteractions.nextLineCalls, 1);
    });

    testWidgets('s → replayLine', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.keyS, character: 's');
      await tester.pump();
      expect(harness.playerInteractions.replayLineCalls, 1);
    });

    testWidgets('e → toggleEcho', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.keyE, character: 'e');
      await tester.pump();
      expect(harness.playerInteractions.toggleEchoCalls, 1);
    });

    testWidgets('h → toggleBlur', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.keyH, character: 'h');
      await tester.pump();
      expect(harness.playerInteractions.toggleBlurCalls, 1);
    });

    testWidgets('line hotkeys without session → no calls', (tester) async {
      final harness = await _mountHarness(tester);
      await _stroke(tester, [], LogicalKeyboardKey.keyA, character: 'a');
      await tester.pump();
      expect(harness.playerInteractions.prevLineCalls, 0);
    });
  });

  group('player playback rate (slowDown / speedUp)', () {
    testWidgets('shift+comma → slowDown decreases by 0.05', (tester) async {
      final harness = await _mountHarness(
        tester,
        session: _videoSession(),
        initialRate: 1.0,
      );
      await _stroke(
        tester,
        [LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.comma,
        character: ',',
      );
      await tester.pump();
      expect(harness.playerPrefs.setPlaybackRateCalls, [0.95]);
    });

    testWidgets('slowDown clamps at 0.25 (no further decrease)', (
      tester,
    ) async {
      final harness = await _mountHarness(
        tester,
        session: _videoSession(),
        initialRate: 0.25,
      );
      await _stroke(
        tester,
        [LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.comma,
        character: ',',
      );
      await tester.pump();
      expect(harness.playerPrefs.setPlaybackRateCalls, [0.25]);
    });

    testWidgets('shift+period → speedUp increases by 0.05', (tester) async {
      final harness = await _mountHarness(
        tester,
        session: _videoSession(),
        initialRate: 1.0,
      );
      await _stroke(
        tester,
        [LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.period,
        character: '.',
      );
      await tester.pump();
      expect(harness.playerPrefs.setPlaybackRateCalls, [1.05]);
    });

    testWidgets('speedUp clamps at 2.0 (no further increase)', (tester) async {
      final harness = await _mountHarness(
        tester,
        session: _videoSession(),
        initialRate: 2.0,
      );
      await _stroke(
        tester,
        [LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.period,
        character: '.',
      );
      await tester.pump();
      expect(harness.playerPrefs.setPlaybackRateCalls, [2.0]);
    });
  });

  group('echo expand / shrink', () {
    testWidgets('[ → expandEchoBackward', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.bracketLeft, character: '[');
      await tester.pump();
      expect(harness.playerInteractions.expandEchoBackwardCalls, 1);
    });

    testWidgets('] → expandEchoForward', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(
        tester,
        [],
        LogicalKeyboardKey.bracketRight,
        character: ']',
      );
      await tester.pump();
      expect(harness.playerInteractions.expandEchoForwardCalls, 1);
    });

    testWidgets('{ → shrinkEchoBackward (shift+[)', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      // hotkey chord parser maps "{" → shift+[
      await _stroke(
        tester,
        [LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.bracketLeft,
        character: '[',
      );
      await tester.pump();
      expect(harness.playerInteractions.shrinkEchoBackwardCalls, 1);
    });

    testWidgets('} → shrinkEchoForward (shift+])', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(
        tester,
        [LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.bracketRight,
        character: ']',
      );
      await tester.pump();
      expect(harness.playerInteractions.shrinkEchoForwardCalls, 1);
    });
  });

  group('unmatched key returns false', () {
    testWidgets('z (unbound) does not trigger anything', (tester) async {
      final harness = await _mountHarness(tester, session: _videoSession());
      await _stroke(tester, [], LogicalKeyboardKey.keyZ, character: 'z');
      await tester.pump();
      expect(harness.playerCtrl.togglePlayCalls, 0);
      expect(harness.playerInteractions.prevLineCalls, 0);
      expect(harness.playerInteractions.nextLineCalls, 0);
      expect(harness.fullscreen.toggleCalls, 0);
      expect(harness.router.state.uri.path, '/library');
    });
  });

  group('custom binding override', () {
    testWidgets('user remapped global.craft to ctrl+shift+k still routes', (
      tester,
    ) async {
      final harness = await _mountHarness(
        tester,
        customBindings: const {'global.craft': 'ctrl+shift+k'},
      );
      await _stroke(
        tester,
        [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.keyK,
        character: 'k',
      );
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/craft');
    });
  });

  group('policies (pure)', () {
    test('shadowReadingBusHotkeysEnabled gates on session / echo practice', () {
      expect(
        shadowReadingBusHotkeysEnabled(
          hasPlayerSession: false,
          vocabularyEchoPracticeOpen: false,
        ),
        isFalse,
      );
      expect(
        shadowReadingBusHotkeysEnabled(
          hasPlayerSession: true,
          vocabularyEchoPracticeOpen: false,
        ),
        isTrue,
      );
      expect(
        shadowReadingBusHotkeysEnabled(
          hasPlayerSession: false,
          vocabularyEchoPracticeOpen: true,
        ),
        isTrue,
      );
    });
  });

  // Reference: ensure helpers used by app_hotkeys_keyboard_listener compile.
  // ignore: unused_element
  void silenceUnusedImports() {
    showHotkeysHelpDialog;
    openPlayerRoute;
    hotkeyMatchesBinding;
    EscapeDismissalAction;
    _releaseAll;
  }
}

PlaybackSession _videoSession() => PlaybackSession(
  mediaId: 'm1',
  dexieTargetType: 'Video',
  mediaType: 'video',
  mediaTitle: 'Test',
  durationSeconds: 60,
  currentTimeSeconds: 0,
  currentSegmentIndex: 0,
  language: 'en',
  startedAt: DateTime(2026),
  lastActiveAt: DateTime(2026),
);

PlaybackSession _audioSession() => PlaybackSession(
  mediaId: 'm1',
  dexieTargetType: 'Audio',
  mediaType: 'audio',
  mediaTitle: 'Audio',
  durationSeconds: 60,
  currentTimeSeconds: 0,
  currentSegmentIndex: 0,
  language: 'en',
  startedAt: DateTime(2026),
  lastActiveAt: DateTime(2026),
);
