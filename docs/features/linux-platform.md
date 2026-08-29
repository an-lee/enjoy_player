# Linux Platform

Linux is a **first-class supported desktop platform** since v0.5.0 (ADR-0048). The Linux build produces an AppImage that runs on Ubuntu 22.04 LTS, Fedora 39, and Debian 12 without `apt install` of project-specific dependencies.

## Supported distributions

| Distribution | Status |
|-------------|--------|
| Ubuntu 22.04 LTS (jammy) | Supported (x86_64) |
| Ubuntu 24.04 LTS (noble) | Supported (x86_64) |
| Fedora 39+ | Supported (x86_64) |
| Debian 12 (bookworm) | Supported (x86_64) |
| Arch Linux | Best-effort (x86_64) |
| Other x86_64 distros with glibc 2.35+ and GTK 3 | Should work; not regularly tested |

AArch64 (ARM64) Linux is **not supported** for v1. A follow-up ADR will add multi-arch support.

## Download and install

1. Go to **[https://get.enjoy.bot](https://get.enjoy.bot)** on your Linux machine.
2. Download the AppImage (`enjoy-player-<version>-x86_64.AppImage`).
3. Make it executable:
   ```bash
   chmod +x enjoy-player-*.AppImage
   ```
4. Run it:
   ```bash
   ./enjoy-player-*.AppImage
   ```

No `apt install`, no `sudo`, no Snap/Flatpak abstraction layer. The AppImage is self-contained and includes the Flutter runtime, `media_kit`'s bundled `libmpv`, and a bundled `ffmpeg` from `media_kit_libs_video`.

## What works

| Feature | Linux status |
|---------|-------------|
| Local audio/video playback | Full support (same engine as Windows/macOS) |
| Transcripts (SRT/VTT) | Full support |
| Echo mode (shadow reading) | Works; recording via `record: ^7.0.0` is enabled. Disabled gracefully if the PulseAudio/PipeWire backend is unavailable. |
| Dictionary lookup | Full support |
| Library management | Full support (import, delete, sort, tag) |
| Cloud sync (Enjoy account) | Full support (metadata sync, re-download manifests). Sign-in via **email OTP** or **Other sign-in options** (web PKCE); native Google is hidden ([ADR-0084](../decisions/0084-linux-google-signin-off-and-pkce-deeplink.md)). |
| Recording uploads | Upload `client_platform=linux` to the existing endpoint |
| Keyboard hotkeys | Full support (desktop shortcuts) |
| Settings / preferences | Full support (libsecret / GNOME Keyring backed secure storage) |

## What is not yet available

| Feature | Linux status |
|---------|-------------|
| **YouTube import / playback** | **Not available** (coming soon). `flutter_inappwebview` ships no Linux backend (Android/iOS/macOS/Windows/web only), so the WebView engine can never mount. Opening a YouTube video — or opening the YouTube sign-in screen — shows the localized "YouTube is not yet available on Linux — coming soon" notice instead ([ADR-0048](../decisions/0048-linux-platform-support.md)). |
| **In-app auto-update** | **Not available.** The `auto_updater: ^1.0.0` plugin is Windows/macOS-only. To update, download a new AppImage from the landing page. AppImageUpdate integration is planned for a future release. |
| **Package manager installs (.deb / .rpm / Flatpak / snap)** | Not available. Only AppImage for v1. |

## Developer setup (build from source)

Install the full set of Linux build packages:

```bash
sudo apt-get install -y \
  clang cmake curl git jq ninja-build pkg-config unzip xz-utils zip \
  libgtk-3-dev liblzma-dev libsqlite3-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libsecret-1-dev libmpv-dev ffmpeg
```

Then follow the standard README build instructions:

```bash
flutter pub get
flutter build linux --debug   # debug build
flutter build linux --release # release build
```

The binary is produced at `build/linux/x64/release/bundle/enjoy_player`.

## Release packaging

The release pipeline produces a single AppImage:

```bash
bash .github/scripts/release.sh --platform linux
```

The AppImage is published at `dl.enjoy.bot/player/v<version>/enjoy-player-<version>-x86_64.AppImage` and listed in the release manifest `dl.enjoy.bot/player/latest.json` under the `"linux"` key.

## Performance

| Metric | Target | Measured (v0.5.0, Ubuntu 22.04 LTS) |
|--------|--------|--------------------------------------|
| Cold-start to window | ≤ 6 s (median) | TBD — first release |
| CI Linux build wall time | ≤ 15 min | TBD — first CI run |

Performance budgets for playback, scrolling, and transcript rendering are identical to Windows/macOS — the same engine (`media_kit`), the same widget tree, and the same Drift queries are used on all desktops.

## Troubleshooting

### "YouTube is not yet available on Linux — coming soon"

This is expected. YouTube will be enabled in a future release. The notice replaces the player screen (with a back button) and the YouTube sign-in screen. In the meantime, download the video locally (e.g., with `yt-dlp`) and import the local file — the transcript and everything else work.

The open fails **before any engine swap**: a YouTube open never installs the WebView engine and never disposes the running `media_kit` engine, so audio/video playback opened afterwards keeps working (the 2026-08-29 regression briefly left every later open stuck on the loading skeleton after a failed YouTube open). Local/URL opens are additionally bounded by a 30 s `engine.open` timeout that surfaces a wedged native layer as an open failure instead of an infinite spinner.

### AppImage won't run: "Permission denied"

Run `chmod +x enjoy-player-*.AppImage` first.

### Black video screen / EGL_BAD_DISPLAY on Wayland

The app uses `hwdec: 'auto-safe'` and `enableHardwareAcceleration: false` for the `media_kit` video output on Linux — the same software path as Windows and macOS. If the screen is still black, try running:

```bash
__GLX_VENDOR_LIBRARY_NAME=mesa ./enjoy-player-*.AppImage
```

If the issue persists, open a GitHub issue with your distribution, GPU model, and windowing system (X11 / Wayland).

### Echo recording doesn't work

Recording may fail if PulseAudio/PipeWire is not running or the microphone permission is denied. The echo practice flow will still work without recording (shadow reading without feedback). Check your sound settings.

### Sign-in redirect can't find the app

After completing "Other sign-in options" in the browser, the browser opens `enjoyplayer://auth/callback`. If it reports "No application can open this link", the URL-scheme handler is not registered. The app registers it automatically when it starts (and again right before opening the sign-in browser), so:

1. Start the app once after installing/updating, then retry sign-in from the app (don't reuse an old browser tab).
2. Verify the registration:

```bash
gio mime x-scheme-handler/enjoyplayer
# → Default application for “x-scheme-handler/enjoyplayer”: enjoy-player-scheme.desktop
```

3. Manual repair (e.g. `$XDG_DATA_HOME` on a non-standard location):

```bash
xdg-mime default enjoy-player-scheme.desktop x-scheme-handler/enjoyplayer
```

The app must be running when you finish sign-in in the browser — the running instance receives the callback (a fresh launch forwards to it over D-Bus and exits). If the app was closed mid-sign-in, the flow cannot resume (the one-time code verifier lived in memory); start sign-in again from the app.

### Database won't open ("corrupt local database")

The recovery surface works on Linux — it uses `xdg-open` to reveal the database directory (same code path as macOS uses `open` and Windows uses `explorer`). Tap "Copy error" or "Open logs folder" as needed.

## See also

- [ADR-0048: Linux as a first-class supported desktop platform](../decisions/0048-linux-platform-support.md)
- [ADR-0084: Linux Google Sign-In off + PKCE deep-link plumbing](../decisions/0084-linux-google-signin-off-and-pkce-deeplink.md)
- [Auth — Deep links (PKCE callback)](auth.md#deep-links-pkce-callback)
- [Packaging — Linux AppImage](../packaging.md#linux-appimage)
- [CI — build_linux.yml and the self-hosted Linux runner](../ci-self-hosted-runners.md)
