/// Off-UI-thread existence check for a media item's local thumbnail.
library;

import 'dart:io' show File;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/utils/local_thumbnail.dart';

/// Resolves the thumbnail file for a stored thumbnail path.
///
/// Keyed on the path (one path per media item) so a loading stage that
/// rebuilds — the player body rebuilds on every open resolve — stats the
/// filesystem once instead of on every build, and does it off the UI thread
/// ([resolveLocalThumbnailFile], issue #663).
///
/// Auto-dispose on purpose: a poster can be captured *after* an open that
/// found none ([VideoPosterCaptureService]), so a negative answer must not
/// outlive the screen that asked for it.
final localThumbnailFileProvider = FutureProvider.autoDispose
    .family<File?, String?>((ref, path) {
      return resolveLocalThumbnailFile(path);
    });
