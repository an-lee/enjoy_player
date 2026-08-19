/// Provides [AppDatabase] for the current auth session (per-user SQLite file).
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'app_database.dart';

part 'app_database_provider.g.dart';

/// Maximum number of per-user [AppDatabase] instances kept open simultaneously.
///
/// Only the device-global settings DB and the most recently used per-user DB
/// need to be live at the same time — signing in as a new user closes the
/// previous one. Two is enough because the device-global DB is owned by
/// [deviceGlobalAppDatabaseProvider] (a separate keep-alive provider with its
/// own onDispose), and only one per-user DB is "current" at a time. Anything
/// older is evicted.
const int _kMaxUserSessionDatabases = 2;

/// Process-wide device-global [AppDatabase] (`enjoy_player.sqlite`) — Drift
/// warns when two instances wrap the same `driftDatabase(name: …)` executor.
AppDatabase? _deviceGlobalDatabaseInstance;
int _deviceGlobalDatabaseRefCount = 0;

/// One [AppDatabase] per signed-in session name — avoids constructing a new
/// [AppDatabase] on every [appDatabase] rebuild (Drift multiple-instances warning).
///
/// Bounded to [_kMaxUserSessionDatabases] entries; the oldest is evicted (and
/// closed) before inserting a new one.
final LinkedHashMap<String, AppDatabase> _userSessionDatabases =
    LinkedHashMap<String, AppDatabase>();

AppDatabase _acquireDeviceGlobalDatabase() {
  _deviceGlobalDatabaseRefCount++;
  return _deviceGlobalDatabaseInstance ??= AppDatabase(
    name: AppDatabase.deviceGlobalDatabaseName,
  );
}

Future<void> _releaseDeviceGlobalDatabase() async {
  if (_deviceGlobalDatabaseRefCount <= 0) return;
  _deviceGlobalDatabaseRefCount--;
  // Intentionally keep [_deviceGlobalDatabaseInstance] open until
  // [closeAndClearAllAppDatabases] — closing on every Riverpod dispose
  // (widget tests, hot restart) and re-opening the same drift file triggers
  // Drift's multiple-[AppDatabase] warning while the prior close is still
  // settling.
}

/// Closes every open device-global / per-user [AppDatabase] and clears caches.
Future<void> closeAndClearAllAppDatabases() async {
  debugOnShutdownDatabaseClose?.call();
  _deviceGlobalDatabaseRefCount = 0;
  final deviceGlobal = _deviceGlobalDatabaseInstance;
  _deviceGlobalDatabaseInstance = null;

  final userDbs = List<AppDatabase>.from(_userSessionDatabases.values);
  _userSessionDatabases.clear();

  final toClose = <AppDatabase>{};
  if (deviceGlobal != null) toClose.add(deviceGlobal);
  toClose.addAll(userDbs);

  for (final db in toClose) {
    try {
      await db.close();
    } on Object {
      // Best-effort — recovery is about to delete files anyway.
    }
  }
}

/// Test-only observer fired on every entry into [closeAndClearAllAppDatabases].
///
/// Lets regression tests for the app-shutdown lifecycle hook (see
/// `_EnjoyAppState.didChangeAppLifecycleState` in `lib/app.dart`) verify the
/// hook fires without having to plumb the singleton maps through a public
/// surface. Production callers leave this `null`.
@visibleForTesting
void Function()? debugOnShutdownDatabaseClose;

/// Signed-in user's Drift file base name, or `null` when unauthenticated.
String? _signedInSessionDbBaseName(AsyncValue<AuthState> auth) {
  return auth.when(
    data: (state) {
      if (state is AuthSignedIn && state.profile.id.isNotEmpty) {
        final safe = _sanitizeUserIdForDbName(state.profile.id);
        return '${AppDatabase.deviceGlobalDatabaseName}_$safe';
      }
      return null;
    },
    loading: () => null,
    error: (Object? error, StackTrace stackTrace) => null,
  );
}

/// Device-global Drift DB (`enjoy_player`) — API base URL, diagnostics, and
/// other settings that must be readable before sign-in (ADR-0012, ADR-0031).
///
/// Kept separate from [appDatabaseProvider] so [ApiBaseUrl] does not depend on
/// auth-scoped DB (avoids Riverpod cycles with [authCtrlProvider]).
@Riverpod(keepAlive: true)
AppDatabase deviceGlobalAppDatabase(Ref ref) {
  final db = _acquireDeviceGlobalDatabase();
  ref.onDispose(() {
    unawaited(_releaseDeviceGlobalDatabase());
  });
  return db;
}

/// Short-lived device-global DB access before [ProviderScope] exists (startup).
Future<T> withDeviceGlobalAppDatabaseForBootstrap<T>(
  Future<T> Function(AppDatabase db) run,
) async {
  final db = _acquireDeviceGlobalDatabase();
  try {
    return await run(db);
  } finally {
    await _releaseDeviceGlobalDatabase();
  }
}

/// Per-user library + prefs (`enjoy_player_<userId>`). Requires sign-in
/// (ADR-0031 login-only access); use [deviceGlobalAppDatabaseProvider] for
/// device-global settings.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final sessionName = ref.watch(
    authCtrlProvider.select(_signedInSessionDbBaseName),
  );
  if (sessionName == null) {
    throw StateError(
      'appDatabaseProvider requires AuthSignedIn; '
      'use deviceGlobalAppDatabaseProvider for device-global settings.',
    );
  }

  // Re-inserting an existing key moves it to the end (most recently used) so
  // the eviction loop below drops the truly idle DBs first.
  final existing = _userSessionDatabases.remove(sessionName);
  if (existing != null) {
    _userSessionDatabases[sessionName] = existing;
    ref.onDispose(() {
      unawaited(_userSessionDatabases.remove(sessionName)?.close());
    });
    return existing;
  }

  while (_userSessionDatabases.length >= _kMaxUserSessionDatabases) {
    final oldestKey = _userSessionDatabases.keys.first;
    final oldest = _userSessionDatabases.remove(oldestKey);
    unawaited(oldest?.close());
  }

  final db = AppDatabase(name: sessionName);
  _userSessionDatabases[sessionName] = db;
  ref.onDispose(() {
    unawaited(_userSessionDatabases.remove(sessionName)?.close());
  });
  return db;
}

String _sanitizeUserIdForDbName(String id) =>
    id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
