import Cocoa
import FlutterMacOS

/// Bridges macOS security-scoped bookmark APIs to Flutter so the sandboxed
/// app can re-open user-picked local files across launches (ADR-0060).
///
/// Without this, the implicit `NSOpenPanel` security scope only lasts for
/// the current process; on next open `mk.Player.open(localUri)` would call
/// into libmpv, hit `EACCES`, and leave the UI stuck on the loading
/// spinner.
///
/// The plugin is intentionally tiny — only the three primitives the Dart
/// side needs:
///   * `createBookmark(path)`  -> `Uint8List` (opaque blob to persist)
///   * `resolveBookmark(data)` -> `{path, token, stale}`
///   * `releaseBookmark(token)` -> `null`
///
/// The [token] is an opaque integer handle for a started
/// `URL.startAccessingSecurityScopedResource()` grant kept in [scopedURLs].
/// `releaseBookmark` looks it up and calls the matching
/// `stopAccessingSecurityScopedResource()`.
final class SecurityScopedBookmarkChannel {
  static let channelName = "enjoy.player/security_scoped_bookmark"

  /// Monotonic handle counter handed back to Dart as the `token` field.
  private var nextToken: Int = 0

  /// Active security-scoped URLs keyed by their [nextToken] handle. Only
  /// touched from the platform / main thread (Flutter method-channel
  /// callbacks run on main by default), so no locking.
  private var scopedURLs: [Int: URL] = [:]

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    let instance = SecurityScopedBookmarkChannel()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  private func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "createBookmark":
      handleCreate(call.arguments, result: result)
    case "resolveBookmark":
      handleResolve(call.arguments, result: result)
    case "releaseBookmark":
      handleRelease(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - createBookmark

  private func handleCreate(
    _ arguments: Any?,
    result: @escaping FlutterResult
  ) {
    guard let path = (arguments as? [String: Any])?["path"] as? String,
      !path.isEmpty
    else {
      result(
        FlutterError(
          code: "BAD_ARGS",
          message: "createBookmark requires a non-empty `path` String",
          details: nil
        ))
      return
    }
    let url = URL(fileURLWithPath: path)
    do {
      let data = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      result(FlutterStandardTypedData(bytes: data))
    } catch {
      // The implicit NSOpenPanel scope may already have lapsed, the file
      // may not be inside the sandbox container, or the path may not
      // exist any more. The Dart layer treats nil as "no bookmark" and
      // falls back to the legacy localUri path.
      result(
        FlutterError(
          code: "BOOKMARK_FAILED",
          message: "Could not create security-scoped bookmark for \(path): \(error)",
          details: nil
        ))
    }
  }

  // MARK: - resolveBookmark

  private func handleResolve(
    _ arguments: Any?,
    result: @escaping FlutterResult
  ) {
    guard let typed = (arguments as? [String: Any])?["data"] as? FlutterStandardTypedData
    else {
      result(
        FlutterError(
          code: "BAD_ARGS",
          message: "resolveBookmark requires a `data` Uint8List",
          details: nil
        ))
      return
    }
    var isStale = false
    let url: URL
    do {
      url = try URL(
        resolvingBookmarkData: typed.data,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
    } catch {
      result(
        FlutterError(
          code: "RESOLVE_FAILED",
          message: "Could not resolve security-scoped bookmark: \(error)",
          details: nil
        ))
      return
    }
    let didStart = url.startAccessingSecurityScopedResource()
    guard didStart else {
      result(
        FlutterError(
          code: "SCOPE_DENIED",
          message:
            "startAccessingSecurityScopedResource returned false for \(url.path)",
          details: nil
        ))
      return
    }
    nextToken += 1
    let token = nextToken
    scopedURLs[token] = url
    result([
      "path": url.path,
      "token": token,
      "stale": isStale,
    ])
  }

  // MARK: - releaseBookmark

  private func handleRelease(
    _ arguments: Any?,
    result: @escaping FlutterResult
  ) {
    guard let token = (arguments as? [String: Any])?["token"] as? Int else {
      result(
        FlutterError(
          code: "BAD_ARGS",
          message: "releaseBookmark requires an integer `token`",
          details: nil
        ))
      return
    }
    if let url = scopedURLs.removeValue(forKey: token) {
      url.stopAccessingSecurityScopedResource()
    }
    // Always succeed: a stale token (e.g. already released) is not a
    // programming error worth surfacing.
    result(nil)
  }
}