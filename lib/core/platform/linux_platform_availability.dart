/// Centralized Linux-platform predicates.
///
/// Every call site that branches on [youtubeEngineAvailableOnLinux],
/// [googleSignInAvailableOnLinux], etc. should import this module instead of
/// scattering `Platform.isLinux` checks.
/// This makes future ADRs (e.g. flipping YouTube to `true` on Linux) a one-line
/// change in a single file.
library;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// YouTube engine is **not** available on Linux for v1.
///
/// The engine depends on `flutter_inappwebview`'s Linux backend, which requires
/// `webkit2gtk-4.0` — not present on a default Ubuntu 22.04 LTS install.
/// Re-evaluate in a follow-up ADR (ADR-0048, R1 / R6).
const youtubeEngineAvailableOnLinux = false;

/// True when this runtime is Linux **and** the [youtubeEngineAvailableOnLinux]
/// opt-out applies — every YouTube engine install/mount gate uses this single
/// predicate (ADR-0048).
///
/// Reads [defaultTargetPlatform] (not `Platform.isLinux`) so tests can flip it
/// with `debugDefaultTargetPlatformOverride` on any host. When a future ADR
/// flips [youtubeEngineAvailableOnLinux] to `true`, this becomes `false`
/// everywhere with no call-site changes.
bool get youTubeEngineOptedOutHere =>
    !youtubeEngineAvailableOnLinux &&
    defaultTargetPlatform == TargetPlatform.linux;

/// Google native sign-in is **not available** on Linux.
///
/// First smoke on real Linux installs showed the `google_sign_in`
/// browser-based OAuth flow failing (ADR-0048, R10 kill switch). Linux users
/// sign in with email OTP or the web PKCE fallback instead (ADR-0084). Flip
/// back to `true` only after the provider flow is verified end-to-end.
const googleSignInAvailableOnLinux = false;
