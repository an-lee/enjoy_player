/// Root Material app with router + theming.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/layout/constrained_app_viewport.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/recovery/recovery_actions.dart';
import 'package:enjoy_player/core/recovery/recovery_surface.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/window/desktop_window.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/routing/app_router.dart';
import 'package:enjoy_player/core/theme/app_theme.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_deep_link_listener.dart';
import 'package:enjoy_player/features/hotkeys/presentation/app_hotkeys_keyboard_listener.dart';
import 'package:enjoy_player/features/update/presentation/update_prompt_host.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Backs up + wipes the local database, then invalidates every DB-derived
/// provider so the app recovers in place instead of leaving the user stuck
/// on [RecoverySurface] until they manually relaunch.
///
/// A top-level function (taking [Ref] rather than being a method on
/// [EnjoyApp]'s state) so it can be exercised directly against a plain
/// [ProviderContainer] in tests — real `dart:io` file operations never
/// resolve inside `testWidgets`' fake-async zone when driven through a
/// tapped button's callback, so the meaningful test for this logic runs
/// with a real event loop instead of pumped widget frames.
Future<RecoveryResetOutcome> performRecoveryReset(Ref ref) async {
  // Close whatever Drift connection is currently open (device-global or the
  // signed-in user's per-user DB) before touching files on disk — some
  // platforms refuse to delete a file that's still memory-mapped by an
  // open connection.
  try {
    await closeAndClearAllAppDatabases();
  } on Object {
    // Never opened / already closed — fine, we're about to delete the file.
  }

  final outcome = await resetLocalLibraryWithBackup();
  if (outcome == RecoveryResetOutcome.success) {
    ref.invalidate(deviceGlobalAppDatabaseProvider);
    ref.invalidate(appDatabaseProvider);
    ref.invalidate(appPreferencesCtrlProvider);
  }
  return outcome;
}

/// Wraps [performRecoveryReset] behind a provider so it can be invoked from
/// a [WidgetRef] (`_errorMaterialApp`'s `onReset` callback) or a plain
/// [ProviderContainer] (tests) alike — neither type implements [Ref]
/// directly, but both support `read`/`invalidate` on a [ProviderListenable],
/// which is all that's needed to reach the real [Ref] supplied internally.
@visibleForTesting
final recoveryResetResultProvider = FutureProvider<RecoveryResetOutcome>(
  performRecoveryReset,
);

class EnjoyApp extends ConsumerStatefulWidget {
  const EnjoyApp({super.key, @visibleForTesting this.themeBuilder});

  /// When set (widget tests only), skips [buildAppTheme] / Google Fonts fetches.
  @visibleForTesting
  final ThemeData Function()? themeBuilder;

  @override
  ConsumerState<EnjoyApp> createState() => _EnjoyAppState();
}

class _EnjoyAppState extends ConsumerState<EnjoyApp>
    with WidgetsBindingObserver {
  /// Keeps locale/prefs visible while [appPreferencesCtrlProvider] reloads after
  /// auth-scoped DB switches (signed-in), avoiding a full-app loading flash.
  AppPreferencesState? _lastResolvedPrefs;

  /// Logger for app-lifecycle shutdown.
  static final Logger _log = logNamed('app-shutdown');

  /// Shared by every [MaterialApp] instance built here — including the
  /// loading/error fallbacks, which run before [appPreferencesCtrlProvider]
  /// resolves a locale. Without these, `AppLocalizations.of(context)` (used
  /// by e.g. [RecoverySurface]) returns null and crashes on the very screen
  /// meant to explain a local-database problem to the user.
  static const _fallbackLocalizationsDelegates = <LocalizationsDelegate>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Centralized MaterialApp/MaterialApp.router construction for every
  /// branch of [build].
  ///
  /// The loading, error, and router branches all configure the same
  /// fallback localization delegates, supported locales, scaffold
  /// messenger key, and theme; only `home` (loading/error) vs
  /// `routerConfig + locale` (router) differs. Routing all three through
  /// this single factory makes the missing-delegates bug fixed in 8f7d301
  /// [RecoverySurface] crashing on `AppLocalizations.of(context)` in the
  /// loading/error fallbacks structurally impossible to reintroduce.
  ///
  /// Pass `router: null` to build a plain `MaterialApp` with [home];
  /// pass a [GoRouter] to build a `MaterialApp.router` with the supplied
  /// [prefs] as the locale source.
  Widget _baseMaterialApp({
    required ThemeData theme,
    required Widget home,
    GoRouter? router,
    AppPreferencesState? prefs,
  }) {
    if (router != null) {
      return MaterialApp.router(
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
        theme: theme,
        locale: prefs?.locale,
        localizationsDelegates: _fallbackLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: _shellBuilder,
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: theme,
      localizationsDelegates: _fallbackLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  /// Wraps the router-configured app in its system-chrome overlay,
  /// deep-link listener, update prompt, and (on desktop) hotkey listener.
  /// Only the router variant needs a `builder`; the loading + error
  /// fallbacks render their `home` directly.
  Widget _shellBuilder(BuildContext context, Widget? child) {
    const overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF09090B),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    );
    final viewport = ConstrainedAppViewport(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: child ?? const SizedBox.shrink(),
      ),
    );
    final hosted = AuthDeepLinkListener(
      child: UpdatePromptHost(child: viewport),
    );
    return isDesktop ? AppHotkeysKeyboardListener(child: hosted) : hosted;
  }

  Widget _loadingBranch(ThemeData theme) {
    return _baseMaterialApp(
      theme: theme,
      home: const ConstrainedAppViewport(
        child: Scaffold(body: Center(child: SkeletonAppBootstrap())),
      ),
    );
  }

  Widget _errorBranch(ThemeData theme, Object error, StackTrace? stack) {
    final isDb = isUnrecoverableDatabaseError(error);
    return _baseMaterialApp(
      theme: theme,
      home: isDb
          ? RecoverySurface(
              error: error,
              stack: stack,
              onReset: () {
                ref.invalidate(recoveryResetResultProvider);
                return ref.read(recoveryResetResultProvider.future);
              },
            )
          : ConstrainedAppViewport(
              child: Scaffold(
                body: Center(
                  child: Text(
                    AppLocalizations.of(context)!.errorGenericLoadFailed,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _routerBranch({
    required GoRouter router,
    required ThemeData theme,
    required AppPreferencesState prefs,
  }) {
    return _baseMaterialApp(
      theme: theme,
      home: const SizedBox.shrink(),
      router: router,
      prefs: prefs,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      // Desktop quit path (Cmd+Q, window close → -[NSApplication terminate:]).
      // `ref.onDispose` callbacks on the keep-alive DB providers never fire on
      // app exit (Riverpod only disposes when its [ProviderContainer] is torn
      // down — tests and hot restart, not normal quit), so without this hook
      // the two Drift "DartWorker" background isolates are torn down by the
      // VM mid-shutdown and race `sqlite3_finalize` on stale prepared-statement
      // handles (see ADR-0002 + macOS crash signature
      // `EXC_BAD_ACCESS / sqlite3_finalize + 36`).
      //
      // Best-effort: the Dart VM may exit before the close completes, but in
      // practice each Drift worker isolate drains its prepared-statement cache
      // + `sqlite3_close_v2` chain within a few hundred ms, well before
      // macOS escalates to SIGKILL. Fire-and-forget here is the documented
      // "drain the worker isolate before the engine tears down" recipe —
      // awaiting in this method would deadlock (it's a void callback).
      unawaited(
        closeAndClearAllAppDatabases().catchError((
          Object error,
          StackTrace st,
        ) {
          _log.warning(
            'shutdown: closeAndClearAllAppDatabases failed',
            error,
            st,
          );
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppPreferencesState>>(appPreferencesCtrlProvider, (
      prev,
      next,
    ) {
      final nextPrefs = next.valueOrNull;
      if (nextPrefs == null) return;
      if (identical(nextPrefs, _lastResolvedPrefs)) return;
      setState(() {
        _lastResolvedPrefs = nextPrefs;
      });
    });

    final router = ref.watch(appRouterProvider);
    final prefsAsync = ref.watch(appPreferencesCtrlProvider);
    final theme = widget.themeBuilder?.call() ?? buildAppTheme();

    final live = prefsAsync.valueOrNull;
    final effective = live ?? _lastResolvedPrefs;

    if (prefsAsync.hasError && effective == null) {
      return _errorBranch(theme, prefsAsync.error!, prefsAsync.stackTrace);
    }

    if (prefsAsync.isLoading && effective == null) {
      return _loadingBranch(theme);
    }

    return _routerBranch(
      router: router,
      theme: theme,
      prefs: effective ?? AppPreferencesState.initial,
    );
  }
}
