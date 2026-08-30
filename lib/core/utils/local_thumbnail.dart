/// Resolve a local filesystem thumbnail path.
library;

import 'dart:io' show File;

File? localThumbnailFile(String? path) {
  if (path == null || path.isEmpty) return null;
  final f = File(path);
  return f.existsSync() ? f : null;
}

/// Async counterpart of [localThumbnailFile].
///
/// `File.existsSync` is a blocking `stat()` — fine at import time, but not in
/// a widget `build`, where it runs on the UI thread for every rebuild
/// (issue #663).
Future<File?> resolveLocalThumbnailFile(String? path) async {
  if (path == null || path.isEmpty) return null;
  final f = File(path);
  return await f.exists() ? f : null;
}

/// Decode width to pass as `Image.cacheWidth` for a slot [renderedWidthPx]
/// logical pixels wide.
///
/// A thumbnail is drawn into a fixed 16:9 slot (and usually cropped by
/// `BoxFit.cover`), so decoding the stored full-resolution image — often
/// several megapixels — costs megabytes of glyph-free bitmap for pixels that
/// are never shown. Two times the slot width keeps the upscaled crop sharp on
/// retina densities without decoding the original, and the cap bounds the
/// worst case on very wide desktop stages.
int thumbnailCacheWidthFor(double renderedWidthPx) {
  if (renderedWidthPx <= 0 || !renderedWidthPx.isFinite) return 1;
  return (renderedWidthPx * 2).round().clamp(1, 2048);
}
