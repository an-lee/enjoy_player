#!/usr/bin/env bash
# Wrap the Flutter Linux release bundle into a self-contained AppImage.
#
# Usage:
#   bash linux/packaging/make_appimage.sh --version 0.5.0 --bundle build/linux/x64/release/bundle --output dist/
#
# Produces: dist/enjoy-player-<version>-x86_64.AppImage
#
# Requires: appimagetool-x86_64.AppImage (downloaded on first run, cached under ~/.cache/appimagetool/).
set -euo pipefail

VERSION=""
BUNDLE_DIR=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --bundle)  BUNDLE_DIR="$2"; shift 2 ;;
    --output)  OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$VERSION" || -z "$BUNDLE_DIR" || -z "$OUTPUT_DIR" ]]; then
  echo "Usage: make_appimage.sh --version <v> --bundle <dir> --output <dir>" >&2
  exit 1
fi

BUNDLE_DIR="$(realpath "$BUNDLE_DIR")"
OUTPUT_DIR="$(realpath "$OUTPUT_DIR")"
APP_NAME="enjoy-player-${VERSION}-x86_64"
APPDIR="$(mktemp -d)"
trap 'rm -rf "$APPDIR"' EXIT

echo "==> Preparing AppDir from $BUNDLE_DIR"
cp -a "$BUNDLE_DIR"/* "$APPDIR"/

# Desktop entry (required by AppImage spec — must be at AppDir root AND in usr/share/applications).
# `%u` passes the launched URI (e.g. enjoyplayer://auth/callback) and
# `MimeType=x-scheme-handler/enjoyplayer` registers the PKCE callback scheme
# so browsers/xdg-open can find the app (ADR-0084).
mkdir -p "$APPDIR"/usr/share/applications
cat > "$APPDIR"/enjoy-player.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Enjoy Player
Comment=Cross-platform language-learning player
Exec=enjoy_player %u
Icon=enjoy_player
Categories=AudioVideo;Player;Education;
MimeType=x-scheme-handler/enjoyplayer;
Terminal=false
EOF
cp "$APPDIR"/enjoy-player.desktop "$APPDIR"/usr/share/applications/enjoy-player.desktop

# Icon (use the app's logo; a minimal placeholder if not found)
mkdir -p "$APPDIR"/usr/share/icons/hicolor/256x256/apps
if [[ -f "$BUNDLE_DIR/data/flutter_assets/assets/logo-light.svg" ]]; then
  cp "$BUNDLE_DIR/data/flutter_assets/assets/logo-light.svg" \
     "$APPDIR"/usr/share/icons/hicolor/256x256/apps/enjoy_player.svg
  # Also put a copy in the AppDir root for appimagetool
  cp "$BUNDLE_DIR/data/flutter_assets/assets/logo-light.svg" "$APPDIR"/enjoy_player.svg
else
  touch "$APPDIR"/enjoy_player.png
fi

# Symlink the binary at AppDir root so appimagetool finds it
ln -sf enjoy_player "$APPDIR"/AppRun

# Download appimagetool on first run (cache it)
CACHE_DIR="${HOME}/.cache/appimagetool"
mkdir -p "$CACHE_DIR"
APPIMAGETOOL="${CACHE_DIR}/appimagetool-x86_64.AppImage"
APPIMAGETOOL_BIN="${CACHE_DIR}/squashfs-root/AppRun"

if [[ ! -x "$APPIMAGETOOL_BIN" ]]; then
  if [[ ! -f "$APPIMAGETOOL" ]]; then
    echo "==> Downloading appimagetool..."
    curl -fsSL -o "$APPIMAGETOOL" \
      "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x "$APPIMAGETOOL"
  fi
  # Extract so we can run without FUSE
  echo "==> Extracting appimagetool (no FUSE required)..."
  (cd "$CACHE_DIR" && "$APPIMAGETOOL" --appimage-extract >/dev/null 2>&1) || \
    (cd "$CACHE_DIR" && bash "$APPIMAGETOOL" --appimage-extract >/dev/null 2>&1)
fi

mkdir -p "$OUTPUT_DIR"

echo "==> Building $APP_NAME.AppImage"
ARCH=x86_64 "$APPIMAGETOOL_BIN" "$APPDIR" "$OUTPUT_DIR/$APP_NAME.AppImage"

echo "==> AppImage produced: $OUTPUT_DIR/$APP_NAME.AppImage"
sha256sum "$OUTPUT_DIR/$APP_NAME.AppImage" | awk '{ print $1 }'
