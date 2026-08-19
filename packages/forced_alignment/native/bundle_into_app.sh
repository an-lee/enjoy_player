#!/bin/sh
# Copy vendored espeak-ng-data into a built macOS/iOS app.
#
# Usage: bundle_into_app.sh <path/to/App.app>
# Xcode env: PLATFORM_NAME, EXPANDED_CODE_SIGN_IDENTITY, CODE_SIGN_IDENTITY,
#            CODE_SIGNING_ALLOWED, ENABLE_HARDENED_RUNTIME, CONFIGURATION
#
# The libespeak-ng.dylib itself is embedded by the Xcode "Embed Frameworks"
# phase (PBXCopyFilesBuildPhase with dstSubfolderSpec=10), so this script
# only handles the data tree copy. Xcode owns the embedded dylib's
# install-name and code signature so archive export sees a consistent
# nested bundle.
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
    LIB_DEST="${APP_BUNDLE}/Contents/Frameworks/libespeak-ng.dylib"
    DATA_DEST="${APP_BUNDLE}/Contents/Resources/espeak-ng-data"
    ;;
  iphonesimulator | iphoneos | *)
    LIB_DEST="${APP_BUNDLE}/Frameworks/libespeak-ng.dylib"
    DATA_DEST="${APP_BUNDLE}/espeak-ng-data"
    ;;
esac

DATA_SRC="${NATIVE_DIR}/espeak-ng-data"
if [ ! -d "${DATA_SRC}" ]; then
  echo "bundle_espeak_ng: missing ${DATA_SRC}" >&2
  exit 1
fi

# Xcode's "Embed Frameworks" phase (dstSubfolderSpec=10) is the source of
# truth for libespeak-ng.dylib. Fail closed if it didn't land — without the
# dylib the production align path returns spokenReferenceUnavailable at
# runtime, which the user sees as "failed to generate, tap to retry".
if [ ! -f "${LIB_DEST}" ]; then
  echo "bundle_espeak_ng: missing ${LIB_DEST} (Xcode Embed Frameworks did not copy libespeak-ng.dylib)" >&2
  exit 1
fi
rm -rf "${DATA_DEST}"
mkdir -p "${DATA_DEST}"
# Copy the trimmed voice tree (including nested lang/). Do not use a
# Flutter asset bundle here — Xcode copies real files. Exclude .gitkeep
# so the runtime "usable data dir" check stays honest. `cp -R` is present
# on macOS (Xcode) and Linux (package tests); rsync is not assumed.
cp -R "${DATA_SRC}/." "${DATA_DEST}/"
find "${DATA_DEST}" -name '.gitkeep' -delete

sign_identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [ -z "${sign_identity}" ] || [ "${sign_identity}" = "-" ]; then
  sign_identity="${CODE_SIGN_IDENTITY:-}"
fi

case "${PLATFORM_NAME}" in
  iphoneos | iphonesimulator)
    # Xcode's Embed Frameworks phase has CodeSignOnCopy and the final
    # target signing phase owns the app seal. Do not mutate or re-sign
    # either one here: exportArchive otherwise sees stale CodeResources
    # and can remove libswift_Concurrency.dylib from the IPA.
    ;;
  *)
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
    ;;
esac

echo "bundle_espeak_ng: data=${DATA_DEST} (${PLATFORM_NAME})"
