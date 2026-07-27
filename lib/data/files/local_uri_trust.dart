/// Cheap local-file trust checks for open (size + optional mtime).
library;

import 'dart:io';

/// Resolves a stored local media reference to a [File].
///
/// Accepts both `file:` URIs and bare filesystem paths. Bare Windows paths
/// like `C:\…` must not go through [Uri.parse] alone — that treats the drive
/// letter as a URI scheme and [File.fromUri] then throws.
File fileFromLocalUri(String localUri) {
  if (localUri.startsWith('file:')) {
    return File.fromUri(Uri.parse(localUri));
  }
  return File(localUri);
}

/// Returns true when [localUri] exists and matches stored trust metadata.
///
/// Full content hashing is intentionally not performed here (see FR-004a).
Future<bool> localUriTrusted({
  required String? localUri,
  required int? storedSize,
  required int? storedMtimeMs,
}) async {
  if (localUri == null || localUri.isEmpty) return false;
  try {
    final file = fileFromLocalUri(localUri);
    if (!await file.exists()) return false;

    final stat = await file.stat();
    if (storedSize != null && stat.size != storedSize) return false;
    if (storedMtimeMs != null &&
        stat.modified.millisecondsSinceEpoch != storedMtimeMs) {
      return false;
    }
    return true;
  } on Object {
    return false;
  }
}
