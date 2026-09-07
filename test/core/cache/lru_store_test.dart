import 'package:enjoy_player/core/cache/lru_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tests use a 1-second TTL by default — the entry survives the test body
  // and is only expired by the explicit `ttl_returns_null_after_elapse`
  // test below.
  const ttl = Duration(seconds: 1);

  group('L1Store', () {
    test('peek returns cached value after put', () {
      final store = L1Store<String, int>(capacity: 4, ttl: ttl);
      store.put('a', 1);
      expect(store.peek('a'), 1);
      expect(store.size, 1);
    });

    test('peek returns null on miss', () {
      final store = L1Store<String, int>(capacity: 4, ttl: ttl);
      expect(store.peek('nope'), isNull);
    });

    test('lru evicts oldest on overflow', () {
      final store = L1Store<String, int>(capacity: 3, ttl: ttl);
      store.put('a', 1);
      store.put('b', 2);
      store.put('c', 3);
      store.put('d', 4);
      expect(store.peek('a'), isNull);
      expect(store.peek('b'), 2);
      expect(store.peek('c'), 3);
      expect(store.peek('d'), 4);
      expect(store.size, 3);
    });

    test('peek updates lru position so a touched entry survives eviction', () {
      final store = L1Store<String, int>(capacity: 3, ttl: ttl);
      store.put('a', 1);
      store.put('b', 2);
      store.put('c', 3);
      // Touch 'a' so it becomes MRU; 'b' is now LRU.
      expect(store.peek('a'), 1);
      store.put('d', 4);
      expect(store.peek('a'), 1);
      expect(store.peek('b'), isNull);
      expect(store.peek('c'), 3);
      expect(store.peek('d'), 4);
    });

    test('peek returns null after ttl elapses and removes the entry', () {
      final store = L1Store<String, int>(
        capacity: 4,
        ttl: const Duration(milliseconds: 10),
      );
      store.put('a', 1);
      expect(store.peek('a'), 1);
      return Future<void>.delayed(const Duration(milliseconds: 25)).then((_) {
        expect(store.peek('a'), isNull);
        // The expired entry was removed lazily on the miss.
        expect(store.size, 0);
      });
    });

    test('put overwrites existing key and resets position', () {
      final store = L1Store<String, int>(capacity: 3, ttl: ttl);
      store.put('a', 1);
      store.put('b', 2);
      store.put('c', 3);
      store.put('a', 99);
      // After overwrite, 'a' is MRU. Inserting 'd' should evict 'b' (LRU).
      store.put('d', 4);
      expect(store.peek('a'), 99);
      expect(store.peek('b'), isNull);
      expect(store.peek('c'), 3);
      expect(store.peek('d'), 4);
    });

    test('clear drops every entry', () {
      final store = L1Store<String, int>(capacity: 4, ttl: ttl);
      store.put('a', 1);
      store.put('b', 2);
      store.clear();
      expect(store.size, 0);
      expect(store.peek('a'), isNull);
      expect(store.peek('b'), isNull);
    });

    test('invalidate removes a single entry', () {
      final store = L1Store<String, int>(capacity: 4, ttl: ttl);
      store.put('a', 1);
      store.put('b', 2);
      store.invalidate('a');
      expect(store.peek('a'), isNull);
      expect(store.peek('b'), 2);
      expect(store.size, 1);
    });

    test('invalidate is a no-op for absent key', () {
      final store = L1Store<String, int>(capacity: 4, ttl: ttl);
      store.invalidate('nope');
      expect(store.size, 0);
    });

    test('size returns current entry count', () {
      final store = L1Store<String, int>(capacity: 4, ttl: ttl);
      expect(store.size, 0);
      store.put('a', 1);
      expect(store.size, 1);
      store.put('b', 2);
      expect(store.size, 2);
      store.invalidate('a');
      expect(store.size, 1);
    });

    test('asserts on non-positive capacity', () {
      expect(
        () => L1Store<String, int>(capacity: 0, ttl: ttl),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts on negative ttl', () {
      expect(
        () =>
            L1Store<String, int>(capacity: 4, ttl: const Duration(seconds: -1)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('zero ttl expires on any subsequent read', () {
      // With TTL = 0 the expiry condition is `now - createdAt >= 0`, so
      // even an immediate subsequent read is a miss.
      final store = L1Store<String, int>(capacity: 4, ttl: Duration.zero);
      store.put('a', 1);
      expect(store.peek('a'), isNull);
    });
  });
}
