import 'package:enjoy_player/data/api/secure_storage_op_lock.dart';
import 'package:enjoy_player/data/api/secure_token_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tracks in-flight operation concurrency to assert the store serializes
/// its calls, and can silently drop writes to simulate a misbehaving
/// Linux libsecret backend.
class _LossyConcurrentTrackingStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};
  final List<String> deletedKeys = [];
  int inFlight = 0;
  int maxInFlight = 0;
  bool dropNextWrite = false;

  Future<T> _track<T>(Future<T> Function() op) async {
    inFlight++;
    maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      return await op();
    } finally {
      inFlight--;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _track(() async => values[key]);

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _track(() async {
    if (dropNextWrite) {
      dropNextWrite = false;
      return; // silently "succeed" without persisting
    }
    values[key] = value!;
  });

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _track(() async {
    deletedKeys.add(key);
    values.remove(key);
  });
}

void main() {
  // The Linux write-verification path is gated on TargetPlatform.linux;
  // flutter_test defaults to android, so pin it for these tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('SecureTokenStore serialization', () {
    test('concurrent operations never overlap', () async {
      final storage = _LossyConcurrentTrackingStorage();
      final store = SecureTokenStore(storage, opLock: SecureStorageOpLock());

      await Future.wait([
        store.writeAccessToken('access'),
        store.readAccessToken(),
        store.writeRefreshToken('refresh'),
        store.writeTokenExpiresAt('2026-01-01T00:00:00Z'),
        store.readRefreshToken(),
        store.clearAccessToken(),
        store.writeCachedProfileJson('{"id":"u1"}'),
      ]);

      expect(
        storage.maxInFlight,
        1,
        reason:
            'flutter_secure_storage on Linux services every operation '
            'with a read-modify-write of one shared blob; overlapping '
            'calls lose writes',
      );
    });
  });

  group('SecureTokenStore Linux write verification', () {
    test('retries once when a write silently does not stick', () async {
      final storage = _LossyConcurrentTrackingStorage()..dropNextWrite = true;
      final store = SecureTokenStore(storage, opLock: SecureStorageOpLock());

      await store.writeAccessToken('token-123');

      expect(storage.deletedKeys, ['enjoy_player.access_token']);
      expect(storage.values['enjoy_player.access_token'], 'token-123');
    });

    test('throws when the backend keeps losing the value', () async {
      final storage = _BrokenStorage();
      final store = SecureTokenStore(storage, opLock: SecureStorageOpLock());

      await expectLater(
        store.writeAccessToken('token-123'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'secure_storage_write_lost',
          ),
        ),
      );
    });
  });
}

class _BrokenStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    // Reports success but never persists — mirrors the corrupted gnome-keyring
    // item observed in issue investigation (empty secret, garbled schema).
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}
