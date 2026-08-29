/// Tuning constants for [MediaKitPlayerEngine] video controller dimensions,
/// aspect-ratio dedup epsilon, normalised-volume mapping, and texture kicks.
library;

/// Default width for the [media_kit] [VideoController] on non-mobile platforms.
const int kVideoControllerWidth = 1920;

/// Default height for the [media_kit] [VideoController] on non-mobile platforms.
const int kVideoControllerHeight = 1080;

/// Two aspect ratios within this epsilon are considered equal (dedup guard for
/// the [MediaKitPlayerEngine.videoAspectRatioStream]).
const double kAspectRatioEpsilon = 0.0001;

/// Scale factor mapping a 0.0–1.0 normalised volume to `media_kit` volume units.
const double kVolumeScale = 100;

/// Relayout [Video] again when the host viewport jumps by at least this many
/// logical pixels (loading 16:9 → side-by-side chrome).
const double kVideoTextureKickMinViewportDelta = 32;

/// Temporary inset applied for one frame to force a Texture present.
const double kVideoTextureKickInset = 1;

/// Ceiling for [PlayerEngine.open] before the open fails with a timeout.
///
/// `media_kit`'s `open` completes on the mpv `loadlist` command ACK (not on
/// buffering), so even slow network sources settle far below this. The bound
/// exists for the wedge class where the native event pump stops delivering
/// events: without it `openMedia` awaits forever and the player screen shows
/// the loading skeleton indefinitely (issue: YouTube open on Linux wedged
/// every later audio open — 2026-08-29 field report).
const Duration kEngineOpenTimeout = Duration(seconds: 30);
