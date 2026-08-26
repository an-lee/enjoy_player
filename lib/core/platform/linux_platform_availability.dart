/// Centralized Linux-platform predicates.
///
/// Every call site that branches on [isLinux], [youtubeEngineAvailableOnLinux],
/// etc. should import this module instead of scattering `Platform.isLinux` checks.
/// This makes future ADRs (e.g. flipping YouTube to `true` on Linux) a one-line
/// change in a single file.
library;

import 'dart:io' show Platform;

/// True when running on a Linux host.
bool get isLinux => Platform.isLinux;

/// YouTube engine is **not** available on Linux for v1.
///
/// The engine depends on `flutter_inappwebview`'s Linux backend, which requires
/// `webkit2gtk-4.0` — not present on a default Ubuntu 22.04 LTS install.
/// Re-evaluate in a follow-up ADR (ADR-0048, R1 / R6).
const youtubeEngineAvailableOnLinux = false;

/// Google native sign-in is **not available** on Linux.
///
/// First smoke on real Linux installs showed the `google_sign_in`
/// browser-based OAuth flow failing (ADR-0048, R10 kill switch). Linux users
/// sign in with email OTP or the web PKCE fallback instead (ADR-0084). Flip
/// back to `true` only after the provider flow is verified end-to-end.
const googleSignInAvailableOnLinux = false;

/// In-app auto-updater (`auto_updater: 0.2.1`) is **not** available on Linux.
///
/// `auto_updater` is Windows/macOS-only. Linux uses the direct-download update
/// model (ADR-0048, R7).
const autoUpdaterAvailableOnLinux = false;

/// Echo-mode recording (`record: ^7.0.0`) is **enabled** on Linux by default.
///
/// Flip to `false` if first smoke shows a crash; the rest of echo practice
/// works without recording (ADR-0048, R8).
const echoRecordingAvailableOnLinux = true;

/// ASR (Azure speech) audio extraction over FFmpeg is **enabled** on Linux.
///
/// The extraction code falls through to system `ffmpeg` on PATH for non-Windows
/// platforms. Flip to `false` if smoke shows a regression (ADR-0048).
const nativeLinuxAsrAvailable = true;
