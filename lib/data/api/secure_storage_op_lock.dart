/// App-wide serialization for `flutter_secure_storage` operations.
library;

/// Async lock shared by every secure-storage-backed store in the app.
final sharedSecureStorageOpLock = SecureStorageOpLock();

/// Serializes keyring operations behind a single in-flight [Future].
///
/// `flutter_secure_storage`'s Linux backend keeps **all keys in one libsecret
/// item** (a JSON blob) and services every read/write/delete with a
/// read-modify-write of that whole blob. Its sync libsecret calls pump the
/// GTK main loop while they wait on D-Bus, so a platform-channel call issued
/// by another async flow is dispatched *re-entrantly* inside the first
/// call's wait. Two overlapping writers then read the same snapshot and the
/// second store clobbers the first — mid-sign-in that erases the tokens that
/// were just written, every subsequent read returns `null`, and the 401
/// cascade signs the user out of a login the server actually accepted.
/// Overlapping creates also make gnome-keyring collide on the item
/// (`asked to register item … but it's already registered`) and can leave
/// the item corrupted (garbled `xdg:schema` attribute, empty secret).
///
/// Chaining every operation behind one [Future] keeps a single storage
/// operation in flight at a time, which makes the blob's read-modify-write
/// atomic from the backend's point of view.
final class SecureStorageOpLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    // Keep the chain alive regardless of the operation's outcome, but hand
    // the caller the original future so errors still propagate to them.
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
