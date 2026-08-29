/// Encrypted storage for API bearer token.
library;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/api/secure_storage_op_lock.dart';

part 'secure_token_store.g.dart';

final Logger _log = logNamed('secureTokenStore');

const _kAccessTokenKey = 'enjoy_player.access_token';
const _kRefreshTokenKey = 'enjoy_player.refresh_token';
const _kCachedProfileJsonKey = 'enjoy_player.cached_profile_json';
const _kTokenExpiresAtKey = 'enjoy_player.token_expires_at';

/// Pin Android to the v10 default RSA-OAEP / AES-GCM ciphers (migrates from
/// the deprecated Jetpack Security `encryptedSharedPreferences` on first read)
/// and iOS to `first_unlock` so tokens survive device reboot but stay
/// inaccessible until the user has unlocked the device at least once.
const _kAndroidOptions = AndroidOptions();
const _kIosOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock,
);
const _kMacOsOptions = MacOsOptions(
  accessibility: KeychainAccessibility.first_unlock,
  usesDataProtectionKeychain: false,
);

@Riverpod(keepAlive: true)
SecureTokenStore secureTokenStore(Ref ref) {
  return SecureTokenStore(
    const FlutterSecureStorage(
      aOptions: _kAndroidOptions,
      iOptions: _kIosOptions,
      mOptions: _kMacOsOptions,
    ),
  );
}

/// Thin wrapper around [FlutterSecureStorage].
///
/// Every operation is routed through [sharedSecureStorageOpLock]: on Linux
/// the backend keeps all keys in a single libsecret item and overlapping
/// operations interleave inside the GTK main loop, corrupting or losing the
/// freshly written session (see [SecureStorageOpLock]).
class SecureTokenStore {
  SecureTokenStore(this._storage, {SecureStorageOpLock? opLock})
    : _opLock = opLock ?? sharedSecureStorageOpLock;

  final FlutterSecureStorage _storage;
  final SecureStorageOpLock _opLock;

  Future<String?> readAccessToken() =>
      _serialized(() => _storage.read(key: _kAccessTokenKey));

  Future<void> writeAccessToken(String token) =>
      _serialized(() => _writeResilient(_kAccessTokenKey, token));

  Future<String?> readRefreshToken() =>
      _serialized(() => _storage.read(key: _kRefreshTokenKey));

  Future<void> writeRefreshToken(String token) =>
      _serialized(() => _writeResilient(_kRefreshTokenKey, token));

  Future<void> clearAccessToken() =>
      _serialized(() => _deleteBestEffort(_kAccessTokenKey));

  Future<void> clearRefreshToken() =>
      _serialized(() => _deleteBestEffort(_kRefreshTokenKey));

  /// JSON from [UserProfile.toJson] for cold-start UI before network fetch.
  Future<String?> readCachedProfileJson() =>
      _serialized(() => _storage.read(key: _kCachedProfileJsonKey));

  Future<void> writeCachedProfileJson(String json) =>
      _serialized(() => _writeResilient(_kCachedProfileJsonKey, json));

  Future<void> clearCachedProfile() =>
      _serialized(() => _deleteBestEffort(_kCachedProfileJsonKey));

  /// ISO 8601 UTC timestamp when the stored access token expires.
  Future<String?> readTokenExpiresAt() =>
      _serialized(() => _storage.read(key: _kTokenExpiresAtKey));

  Future<void> writeTokenExpiresAt(String expiresAt) =>
      _serialized(() => _writeResilient(_kTokenExpiresAtKey, expiresAt));

  Future<void> clearTokenExpiresAt() =>
      _serialized(() => _deleteBestEffort(_kTokenExpiresAtKey));

  /// Clears bearer token, refresh token, cached profile, and token expiry (sign out / invalid session).
  ///
  /// Best-effort by design: sign-out must always complete (the caller flips
  /// the UI to signed-out right after), so each delete failure is logged and
  /// the remaining keys are still attempted instead of aborting on the first.
  Future<void> clearAllAuthSecrets() => _serialized(() async {
    for (final key in const [
      _kAccessTokenKey,
      _kRefreshTokenKey,
      _kCachedProfileJsonKey,
      _kTokenExpiresAtKey,
    ]) {
      try {
        await _deleteRaw(key);
      } on PlatformException catch (e) {
        _log.warning('secure storage delete failed for "$key"', e);
      }
    }
  });

  Future<T> _serialized<T>(Future<T> Function() operation) =>
      _opLock.run(operation);

  Future<void> _deleteBestEffort(String key) async {
    try {
      await _deleteRaw(key);
    } on PlatformException catch (e) {
      _log.warning('secure storage delete failed for "$key"', e);
    }
  }

  Future<void> _deleteRaw(String key) => _storage.delete(key: key);

  /// Writes to the keychain/keystore, self-healing from a stale entry that
  /// conflicts with the current write, and — on Linux — verifying the value
  /// actually stuck.
  ///
  /// On iOS/macOS, `flutter_secure_storage`'s `write()` first checks
  /// existence with a query that includes `kSecAttrAccessible` (our pinned
  /// `first_unlock`), then falls back to `SecItemAdd` when nothing matches.
  /// `kSecAttrAccessible` is **not** part of a keychain item's primary key,
  /// so a leftover item for the same account/service stored under a
  /// *different* accessibility (e.g. from an older app build, or a run that
  /// was killed mid-write) makes that existence check report "not found"
  /// while `SecItemAdd` still finds a primary-key collision — surfacing as
  /// `PlatformException(Unexpected security result code, ..., -25299 /
  /// errSecDuplicateItem, ...)` and permanently blocking sign-in (see the
  /// PKCE callback failure this was introduced to fix). Deleting the key
  /// (which searches without an accessibility filter) and retrying once
  /// clears any such stale entry regardless of its accessibility level.
  Future<void> _writeResilient(String key, String value) async {
    await _writeWithDuplicateHeal(key, value);
    if (defaultTargetPlatform != TargetPlatform.linux) return;

    // The Linux backend stores all keys in a single libsecret item and its
    // D-Bus round-trips can silently misfire under gnome-keyring (observed:
    // item left with an empty secret and a garbled `xdg:schema` attribute),
    // so a write that reports success may not be readable back. Verify and
    // self-heal once; if it still doesn't stick, fail loudly instead of
    // silently dropping the session. (Empty values are unverifiable because
    // the backend maps a stored "" back to null — never written here, but
    // guard anyway so verification can't false-fail.)
    if (value.isEmpty || await _storage.read(key: key) == value) return;
    _log.warning(
      'secure storage write did not stick for "$key"; deleting and retrying',
    );
    await _deleteRaw(key);
    await _writeWithDuplicateHeal(key, value);
    if (value.isEmpty || await _storage.read(key: key) == value) return;
    throw PlatformException(
      code: 'secure_storage_write_lost',
      message:
          'Secure storage failed to persist "$key" (write not readable back '
          'after retry). The system keyring may be broken or locked.',
    );
  }

  Future<void> _writeWithDuplicateHeal(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (e) {
      if (!_isDuplicateKeychainItem(e)) rethrow;
      _log.warning(
        'secure storage write hit a stale keychain item for "$key" '
        '(errSecDuplicateItem); deleting and retrying once',
        e,
      );
      await _deleteRaw(key);
      await _storage.write(key: key, value: value);
    }
  }

  static bool _isDuplicateKeychainItem(PlatformException e) {
    const duplicateItemStatus = -25299; // errSecDuplicateItem
    return e.details == duplicateItemStatus ||
        (e.message?.contains('$duplicateItemStatus') ?? false);
  }
}
