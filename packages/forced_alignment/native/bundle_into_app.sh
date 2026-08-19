#!/bin/sh
# Copy vendored espeak-ng-data into a built macOS/iOS app.
#
# Usage: bundle_into_app.sh <path/to/App.app>
# Xcode env: PLATFORM_NAME, EXPANDED_CODE_SIGN_IDENTITY, CODE_SIGN_IDENTITY,
#            CODE_SIGNING_ALLOWED, ENABLE_HARDENED_RUNTIME, CONFIGURATION
#
# The libespeak-ng.dylib itself is embedded by the Xcode "Embed Frameworks"
# phase (PBXCopyFilesBuildPhase with dstSubfolderSpec=10), so this script
# only handles the data tree copy and the bundle re-sign that keeps the
# Swift stdlib dylibs in the TestFlight IPA (see commit bf820c03).
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
if command -v install_name_tool >/dev/null 2>&1; then
  install_name_tool -id "@rpath/libespeak-ng.dylib" "${LIB_DEST}" 2>/dev/null || true
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

# For iOS, do NOT hand-sign the dylib here. The Runner target's
# "Embed Frameworks" phase carries libespeak-ng.dylib and the Swift
# stdlib dylibs (libswift_Concurrency.dylib, etc.) are only embedded
# by Xcode's automatic Swift stdlib copy — files that are not
# declared in the Embed Frameworks phase. A manual `codesign --force
# --sign "$LIB_DEST"` rewrites the dylib hash after Xcode's outer
# CodeResources seal has been computed, which causes
# xcodebuild -exportArchive to drop the unmatched Swift stdlib dylibs
# from the IPA and App Store Connect rejects the upload with
# ITMS-90429 ("Invalid Swift Support — libswift_Concurrency.dylib
# isn't at the expected location /Payload/Runner.app/Frameworks").
# Let Xcode's implicit outer sign handle libespeak-ng.dylib via the
# bundle-level re-sign below so the dylib hash and the outer seal
# stay consistent.
#
# Skip the whole-bundle re-sign on Debug iOS builds: Flutter's
# ENABLE_DEBUG_DYLIB=YES drops an unsigned __preview.dylib at the
# bundle root, which fails `codesign --force --sign "$APP_BUNDLE"`
# with "unsealed contents present in the bundle root". The Debug
# build never hits xcodebuild -exportArchive so the ITMS-90429 fix
# is unnecessary there.
#
# Likewise, prune the empty `Contents/Resources/` (a stray macOS-style
# Resources folder that Xcode's asset/strip pipeline leaves behind in
# iOS bundles and codesign refuses to seal) before signing.
if [ "${PLATFORM_NAME}" = "iphoneos" ] || [ "${PLATFORM_NAME}" = "iphonesimulator" ]; then
  for d in "${APP_BUNDLE}/Contents/Resources" "${APP_BUNDLE}/Contents"; do
    if [ -d "$d" ] && [ -z "$(ls -A "$d" 2>/dev/null)" ]; then
      rmdir "$d" 2>/dev/null || true
    fi
  done
fi

case "${PLATFORM_NAME}" in
  iphoneos | iphonesimulator)
    if [ "${CONFIGURATION:-Debug}" != "Debug" ] &&
       [ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ] &&
       [ -n "${sign_identity}" ] && [ "${sign_identity}" != "-" ]; then
      # shellcheck disable=SC2086
      codesign --force --sign "${sign_identity}" "${APP_BUNDLE}"
    fi
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
