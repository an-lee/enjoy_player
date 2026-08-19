/// Dart-side bridge to `macos/Runner/SecurityScopedBookmarkChannel.swift`.
///
/// ## Why this exists
///
/// Enjoy Player's macOS build is sandboxed with only
/// `com.apple.security.files.user-selected.read-write`. `NSOpenPanel` grants
/// a *temporary* security-scoped URL: it covers the picked file for the
/// current process only and is gone by the next launch. Without help,
/// `mk.Player.open(localUri)` (libmpv / libffmpeg) gets `EACCES` and the UI
/// gets stuck on a loading spinner.
///
/// The fix is a security-scoped bookmark: capture
/// `URL.bookmarkData(options: .withSecurityScope, …)` while the implicit
/// `NSOpenPanel` scope is still alive, persist the bytes next to the local
/// file URI, and on every open resolve them + `startAccessingSecurity…`.
///
/// ## Platform behavior
///
/// * **macOS**: real `MethodChannel` (`enjoy.player/security_scoped_bookmark`)
///   handled by `SecurityScopedBookmarkChannel.swift`.
/// * **iOS / Android / Windows / Web / Tests**: no native handler is
///   registered, so `invokeMethod` throws `MissingPluginException` and
///   every method here returns `null` / no-op. Library import on those
///   platforms keeps working unchanged — they either don't need bookmarks
///   or will adopt the same pattern behind a per-platform shim later.
///
/// ## Lifecycle invariant
///
/// `resolveBookmark` returns a `token` that MUST be paired with
/// `releaseBookmark` once the player is done with the file (i.e. before
/// the next `open()` or on engine `dispose`). Failure to pair the calls
/// leaks sandbox extensions and will eventually block subsequent
/// `startAccessing…` from succeeding on that URL.
///
/// See ADR-0060.
library;

import 'package:flutter/services.dart';

import 'package:enjoy_player/core/logging/log.dart';

final _log = logNamed('securityScopedBookmark');

/// Result of resolving a security-scoped bookmark on macOS.
class ResolvedBookmark {
  const ResolvedBookmark({
    required this.path,
    required this.token,
    required this.stale,
  });

  /// Absolute filesystem path of the file the bookmark currently resolves
  /// to. Use this as the URI handed to `mk.Player.open`.
  final String path;

  /// Opaque integer handle for the started
  /// `startAccessingSecurityScopedResource()` grant. Pair with
  /// [SecurityScopedBookmarkChannel.releaseBookmark] when finished.
  final int token;

  /// `true` when the underlying URL has moved (or the bookmark has become
  /// otherwise stale) since it was created. The OS will usually have
  /// rebound transparently — callers can still use [path], but should
  /// re-persist a fresh bookmark at the next save opportunity.
  final bool stale;
}

/// Cross-platform wrapper around the macOS security-scoped bookmark
/// `MethodChannel`. All calls are best-effort and never throw: when the
/// native shim is absent (non-macOS, tests, or a build without the
/// `bookmarks.app-scope` entitlement) they return `null` / no-op and log
/// at `FINE`.
class SecurityScopedBookmarkChannel {
  SecurityScopedBookmarkChannel._();

  static const String _channelName = 'enjoy.player/security_scoped_bookmark';

  /// The channel name; exposed so tests can mock the binary messenger.
  static String get channelName => _channelName;

  /// Internal hook so tests can inject a fake channel.
  static MethodChannel? overrideChannel;

  static MethodChannel _channel() =>
      overrideChannel ?? const MethodChannel(_channelName);

  /// Creates a security-scoped bookmark for [path] while the implicit
  /// `NSOpenPanel` scope is still alive. Returns `null` when the platform
  /// shim is unavailable or the bookmark could not be created (e.g. the
  /// file is gone, or the caller is not in the app sandbox).
  static Future<Uint8List?> createBookmark(String path) async {
    if (path.isEmpty) return null;
    try {
      final typed = await _channel().invokeMethod<Uint8List>(
        'createBookmark',
        <String, Object?>{'path': path},
      );
      return typed;
    } on MissingPluginException {
      _log.fine('createBookmark skipped: no native shim (non-macOS)');
      return null;
    } on PlatformException catch (e, st) {
      _log.fine(
        'createBookmark failed for $path: ${e.code} ${e.message ?? ""}',
        e,
        st,
      );
      return null;
    }
  }

  /// Resolves [data] into a current filesystem path and starts the
  /// security-scoped access grant. Returns `null` on any failure
  /// (missing shim, stale + unrecoverable, scope denied, file gone).
  static Future<ResolvedBookmark?> resolveBookmark(Uint8List data) async {
    if (data.isEmpty) return null;
    try {
      final raw = await _channel().invokeMapMethod<String, Object?>(
        'resolveBookmark',
        <String, Object?>{'data': data},
      );
      if (raw == null) return null;
      final path = raw['path'];
      final token = raw['token'];
      final stale = raw['stale'];
      if (path is! String || path.isEmpty || token is! int) {
        _log.warning(
          'resolveBookmark returned malformed payload: '
          '${raw.keys.toList()..sort()}',
        );
        return null;
      }
      return ResolvedBookmark(path: path, token: token, stale: stale == true);
    } on MissingPluginException {
      _log.fine('resolveBookmark skipped: no native shim (non-macOS)');
      return null;
    } on PlatformException catch (e, st) {
      _log.fine('resolveBookmark failed: ${e.code} ${e.message ?? ""}', e, st);
      return null;
    }
  }

  /// Releases the security-scoped grant previously returned by
  /// [resolveBookmark]. Always succeeds: a stale or unknown [token] is a
  /// no-op (the registry entry simply isn't there any more).
  static Future<void> releaseBookmark(int token) async {
    try {
      await _channel().invokeMethod<void>('releaseBookmark', <String, Object?>{
        'token': token,
      });
    } on MissingPluginException {
      // No shim — nothing to release.
    } on PlatformException catch (e, st) {
      _log.fine(
        'releaseBookmark($token) failed: ${e.code} ${e.message ?? ""}',
        e,
        st,
      );
    }
  }
}
