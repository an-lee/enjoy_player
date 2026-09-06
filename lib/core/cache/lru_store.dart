/// Bounded LRU + TTL in-memory key/value store.
///
/// Used as the L1 tier of [AiResultCache]. Lives under `lib/core/cache/`
/// because the primitive is intentionally generic and reusable beyond AI
/// result caching.
///
/// Eviction policy:
///   * LRU: when [put] exceeds [capacity], the least-recently touched
///     entry is evicted.
///   * TTL: when [peek] finds an entry whose age is greater than or equal
///     to [ttl], the entry is treated as a miss and removed.
library;

import 'dart:collection';

class L1Store<K, V> {
  L1Store({required this.capacity, required this.ttl})
    : assert(capacity > 0, 'capacity must be positive'),
      assert(!ttl.isNegative, 'ttl must be non-negative');

  /// Maximum number of entries. The LRU tail is evicted on overflow.
  final int capacity;

  /// Per-entry time-to-live. Entries whose age is greater than or equal to
  /// this duration are treated as misses.
  final Duration ttl;

  final LinkedHashMap<K, _Entry<V>> _map = LinkedHashMap<K, _Entry<V>>();

  /// Returns the cached value for [key], or `null` if absent or expired.
  /// On a fresh hit, the entry's LRU position is updated to MRU.
  V? peek(K key) {
    final entry = _map[key];
    if (entry == null) return null;
    final now = DateTime.now();
    if (now.difference(entry.createdAt) >= ttl) {
      _map.remove(key);
      return null;
    }
    _map.remove(key);
    _map[key] = entry;
    return entry.value;
  }

  /// Stores [value] under [key]. If the store is at capacity, the LRU
  /// tail is evicted first. Existing entries are overwritten and moved to MRU.
  void put(K key, V value) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    } else if (_map.length >= capacity) {
      final oldestKey = _map.keys.first;
      _map.remove(oldestKey);
    }
    _map[key] = _Entry<V>(value, DateTime.now());
  }

  /// Removes the entry for [key] if present. No-op if absent.
  void invalidate(K key) {
    _map.remove(key);
  }

  /// Removes every entry.
  void clear() {
    _map.clear();
  }

  /// Current number of entries (including expired-but-not-yet-evicted).
  int get size => _map.length;
}

class _Entry<V> {
  const _Entry(this.value, this.createdAt);
  final V value;
  final DateTime createdAt;
}
