#!/bin/sh
# Copy vendored libespeak-ng + espeak-ng-data into a built macOS/iOS app.
#
# Usage: bundle_into_app.sh <path/to/App.app>
# Xcode env: PLATFORM_NAME, EXPANDED_CODE_SIGN_IDENTITY, CODE_SIGN_IDENTITY,
#            CODE_SIGNING_ALLOWED, ENABLE_HARDENED_RUNTIME, CONFIGURATION
set -eu

APP_BUNDLE="${1:-}"
if [ -z "${APP_BUNDLE}" ] || [ ! -d "${APP_BUNDLE}" ]; then
  echo "usage: $0 <path/to/App.app>" >&2
  exit 1
fi

NATIVE_DIR="$(CDPATH= cd "$(dirname "$0")" && pwd)"
PLATFORM_NAME="${PLATFORM_NAME:-}"

if [ -z "${PLATFORM_NAME}" ]; then
  if [ -d "${APP_BUNDLE}/Contents" ]; then
    PLATFORM_NAME="macosx"
  else
    PLATFORM_NAME="iphoneos"
  fi
fi

case "${PLATFORM_NAME}" in
  macosx)
    LIB_SRC="${NATIVE_DIR}/macos/libespeak-ng.dylib"
    FRAMEWORKS_DIR="${APP_BUNDLE}/Contents/Frameworks"
    DATA_DEST="${APP_BUNDLE}/Contents/Resources/espeak-ng-data"
    ;;
  iphonesimulator)
    LIB_SRC="${NATIVE_DIR}/ios/libespeak-ng.simulator.dylib"
    FRAMEWORKS_DIR="${APP_BUNDLE}/Frameworks"
    DATA_DEST="${APP_BUNDLE}/espeak-ng-data"
    ;;
  iphoneos|*)
    LIB_SRC="${NATIVE_DIR}/ios/libespeak-ng.dylib"
    FRAMEWORKS_DIR="${APP_BUNDLE}/Frameworks"
    DATA_DEST="${APP_BUNDLE}/espeak-ng-data"
    ;;
esac

if [ ! -f "${LIB_SRC}" ]; then
  echo "bundle_espeak_ng: missing ${LIB_SRC}" >&2
  exit 1
fi

DATA_SRC="${NATIVE_DIR}/espeak-ng-data"
if [ ! -d "${DATA_SRC}" ]; then
  echo "bundle_espeak_ng: missing ${DATA_SRC}" >&2
  exit 1
fi

mkdir -p "${FRAMEWORKS_DIR}"
LIB_DEST="${FRAMEWORKS_DIR}/libespeak-ng.dylib"
cp -f "${LIB_SRC}" "${LIB_DEST}"
chmod +x "${LIB_DEST}"
if command -v install_name_tool >/dev/null 2>&1; then
  install_name_tool -id "@rpath/libespeak-ng.dylib" "${LIB_DEST}" 2>/dev/null || true
fi

rm -rf "${DATA_DEST}"
mkdir -p "${DATA_DEST}"
# -C: exclude .gitkeep so the runtime "usable data dir" check stays honest.
rsync -a --exclude '.gitkeep' "${DATA_SRC}/" "${DATA_DEST}/"

sign_identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [ -z "${sign_identity}" ] || [ "${sign_identity}" = "-" ]; then
  sign_identity="${CODE_SIGN_IDENTITY:-}"
fi

if [ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ] &&
   [ -n "${sign_identity}" ] && [ "${sign_identity}" != "-" ]; then
  extra=""
  if [ "${PLATFORM_NAME}" = "macosx" ] &&
     { [ "${CONFIGURATION:-Debug}" = "Release" ] ||
       [ "${ENABLE_HARDENED_RUNTIME:-}" = "YES" ]; }; then
    extra="--options runtime --timestamp"
  fi
  # shellcheck disable=SC2086
  codesign --force --sign "${sign_identity}" ${extra} "${LIB_DEST}"
fi

echo "bundle_espeak_ng: ${LIB_DEST} + ${DATA_DEST} (${PLATFORM_NAME})"
