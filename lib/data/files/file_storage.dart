/// Prefer lasting external links; fall back to copying into app documents.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'chunked_file_hash.dart';
import 'lasting_local_access.dart';
import 'security_scoped_bookmark.dart';

class FileImportResult {
  const FileImportResult({
    required this.localPath,
    required this.contentHashHex,
    required this.fileSize,
    required this.title,
    this.mtimeMs,
    this.bookmarkData,
  });

  final String localPath;

  /// Web-aligned partial SHA-256 fingerprint (see [chunkedContentSha256HexFromFileSync]).
  final String contentHashHex;
  final int fileSize;
  final String title;

  /// [File.stat] modified time in ms since epoch when available.
  final int? mtimeMs;

  /// Security-scoped bookmark bytes captured while the implicit
  /// `NSOpenPanel` grant was still alive. Only set on macOS when the file
  /// is *externally linked* (lives outside the app sandbox container);
  /// `null` for files copied into app-managed `media/`, on non-macOS
  /// platforms, and when bookmark creation failed.
  ///
  /// Persist alongside `localUri` so future opens can re-establish the
  /// security scope. See ADR-0060.
  final Uint8List? bookmarkData;

  String get fileUri => Uri.file(localPath).toString();
}

/// Arguments for [_importMediaFileInIsolate]; only plain data for [Isolate.run].
typedef _ImportIsolateArgs = ({
  String sourcePath,
  String mediaDirPath,
  String tempFileName,
  String ext,
  String title,
  String? expectedHashHex,
  bool linkExternally,
});

typedef _ImportIsolateResult = ({
  String localPath,
  String contentHashHex,
  int fileSize,
  String title,
});

/// Copy bytes from source to temp; no hashing (hash computed separately).
Future<void> _streamCopyFile(String sourcePath, String destPath) async {
  final source = File(sourcePath);
  final dest = File(destPath);
  final sink = dest.openWrite();
  await for (final chunk in source.openRead()) {
    sink.add(chunk);
  }
  await sink.flush();
  await sink.close();
}

Future<_ImportIsolateResult> _importMediaFileInIsolate(
  _ImportIsolateArgs args,
) async {
  final contentHashHex = chunkedContentSha256HexFromFileSync(args.sourcePath);

  final expected = args.expectedHashHex;
  if (expected != null && expected.isNotEmpty && expected != contentHashHex) {
    throw 'HASH_MISMATCH';
  }

  if (args.linkExternally) {
    final length = await File(args.sourcePath).length();
    return (
      localPath: args.sourcePath,
      contentHashHex: contentHashHex,
      fileSize: length,
      title: args.title,
    );
  }

  final tempPath = p.join(args.mediaDirPath, args.tempFileName);
  final tempFile = File(tempPath);

  await _streamCopyFile(args.sourcePath, tempPath);
  final writtenLength = await tempFile.length();

  final destPath = p.join(args.mediaDirPath, '$contentHashHex${args.ext}');
  final destFile = File(destPath);
  if (await destFile.exists()) {
    await tempFile.delete();
    return (
      localPath: destPath,
      contentHashHex: contentHashHex,
      fileSize: await destFile.length(),
      title: args.title,
    );
  }

  await tempFile.rename(destPath);

  return (
    localPath: destPath,
    contentHashHex: contentHashHex,
    fileSize: writtenLength,
    title: args.title,
  );
}

Future<int?> _mtimeMsForPath(String path) async {
  try {
    final stat = await File(path).stat();
    return stat.modified.millisecondsSinceEpoch;
  } on Object {
    return null;
  }
}

class FileStorage {
  // ignore: prefer_const_constructors
  static final Uuid _uuid = Uuid();

  /// Prefer lasting external link; otherwise copy into app `media/`.
  ///
  /// When [expectedHashHex] is set, fails with [FileFailure] if the chunked
  /// hash does not match (without leaving orphan `.tmp_` files).
  Future<FileImportResult> importOrLinkPickedFile(
    XFile file, {
    String? expectedHashHex,
  }) async {
    try {
      final path = file.path;
      if (path.isEmpty) {
        throw const FileFailure('Import failed: no file path');
      }

      final docs = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(docs.path, 'media'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final ext = p.extension(file.name).toLowerCase();
      final tempFileName = '.tmp_${_uuid.v4()}$ext';
      final title = p.basenameWithoutExtension(file.name);
      final linkExternally = await canLinkExternally(path);

      // Capture the macOS security-scoped bookmark *before* the isolate
      // hops away from the main isolate (and while the implicit
      // `NSOpenPanel` grant is still alive). Only persist when the file
      // is going to be externally linked — copied bytes inside the app
      // sandbox container don't need one.
      final bookmarkData = linkExternally
          ? await SecurityScopedBookmarkChannel.createBookmark(path)
          : null;

      final worker = await Isolate.run(
        () => _importMediaFileInIsolate((
          sourcePath: path,
          mediaDirPath: mediaDir.path,
          tempFileName: tempFileName,
          ext: ext,
          title: title,
          expectedHashHex: expectedHashHex,
          linkExternally: linkExternally,
        )),
      );

      return FileImportResult(
        localPath: worker.localPath,
        contentHashHex: worker.contentHashHex,
        fileSize: worker.fileSize,
        title: worker.title,
        mtimeMs: await _mtimeMsForPath(worker.localPath),
        bookmarkData: bookmarkData,
      );
    } catch (e, st) {
      if (e is FileFailure) {
        Error.throwWithStackTrace(e, st);
      }
      if (e == 'HASH_MISMATCH') {
        Error.throwWithStackTrace(
          const FileFailure('Hash mismatch: file does not match synced media.'),
          st,
        );
      }
      Error.throwWithStackTrace(FileFailure('Import failed: $e'), st);
    }
  }

  Future<FileImportResult> importPickedFile(XFile file) =>
      importOrLinkPickedFile(file);

  /// Like [importPickedFile], but only succeeds when the file's chunked SHA-256
  /// hex matches [expectedHashHex] (same value stored in Drift `md5` column).
  Future<FileImportResult> importPickedFileExpectingHash(
    XFile file, {
    required String expectedHashHex,
  }) => importOrLinkPickedFile(file, expectedHashHex: expectedHashHex);

  /// Best-effort delete when [fileUri] points at app-managed `media/`.
  /// No-op for external links, null, or missing files.
  Future<void> deleteAppManagedMedia(String? fileUri) async {
    if (fileUri == null || fileUri.isEmpty) return;
    if (!await isAppManagedMediaPath(fileUri)) return;
    try {
      final file = File.fromUri(Uri.parse(fileUri));
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // Best-effort cleanup only.
    }
  }

  /// Writes raw bytes (e.g. synthesized TTS audio) into app media storage
  /// and returns the same [FileImportResult] shape as file-based imports.
  ///
  /// Used by the Craft from text flow to persist TTS audio bytes alongside
  /// regular media imports so the same playback / sync path applies.
  /// The SHA-256 is computed from the raw bytes directly (not chunked file
  /// hash) because the bytes never exist on disk before this call.
  Future<FileImportResult> importBytes(
    Uint8List bytes, {
    required String extension,
    String title = 'Crafted audio',
  }) async {
    try {
      if (bytes.isEmpty) {
        throw const FileFailure('Import failed: empty audio bytes');
      }

      final docs = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(docs.path, 'media'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final contentHashHex = sha256.convert(bytes).toString();
      final ext = extension.startsWith('.') ? extension : '.$extension';
      final destPath = p.join(mediaDir.path, '$contentHashHex$ext');
      final destFile = File(destPath);

      if (!await destFile.exists()) {
        final raf = await destFile.open(mode: FileMode.write);
        try {
          await raf.writeFrom(bytes);
        } finally {
          await raf.close();
        }
      }

      return FileImportResult(
        localPath: destPath,
        contentHashHex: contentHashHex,
        fileSize: bytes.length,
        title: title,
        mtimeMs: await _mtimeMsForPath(destPath),
      );
    } catch (e, st) {
      if (e is FileFailure) {
        Error.throwWithStackTrace(e, st);
      }
      Error.throwWithStackTrace(FileFailure('Import failed: $e'), st);
    }
  }
}
