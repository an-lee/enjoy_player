#!/bin/sh
# Build vendored iOS libespeak-ng (eSpeak-NG 1.52.0) on a macOS host.
#
# Produces:
#   ios/libespeak-ng.dylib            # iphoneos arm64 (wrap source)
#   ios/libespeak-ng.simulator.dylib  # iphonesimulator arm64 + x86_64
#   ios/eSpeakNG.xcframework          # App Store embed (TN2435)
#
# Matches the other OS vendors: same upstream sources (libespeak-ng/*.c
# except sPlayer.c, plus ucd-tools), -fvisibility=hidden
# -DLIBESPEAK_NG_EXPORT, no pcaudiolib / speech-player.
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")" && pwd)"
VERSION="1.52.0"
SRC_DIR="${ROOT}/.build/espeak-ng-${VERSION}"
TARBALL="${ROOT}/.build/espeak-ng-${VERSION}.tar.gz"
URL="https://github.com/espeak-ng/espeak-ng/archive/refs/tags/${VERSION}.tar.gz"
MIN_IOS="15.0"

mkdir -p "${ROOT}/.build"

if [ ! -d "${SRC_DIR}/src/libespeak-ng" ]; then
  if [ ! -f "${TARBALL}" ]; then
    curl -fsSL "${URL}" -o "${TARBALL}"
  fi
  tar -xzf "${TARBALL}" -C "${ROOT}/.build"
fi

CONFIG_DIR="${ROOT}/.build/ios-config"
mkdir -p "${CONFIG_DIR}"
cat >"${CONFIG_DIR}/config.h" <<'EOF'
#define HAVE_MKSTEMP 1
#define USE_ASYNC 0
#define USE_KLATT 1
#define USE_LIBPCAUDIO 0
#define USE_LIBSONIC 0
#define USE_MBROLA 0
#define USE_SPEECHPLAYER 0
#define PACKAGE_VERSION "1.52.0"
#define PATH_ESPEAK_DATA "/usr/share/espeak-ng-data"
EOF
# Recent Apple SDKs ship <endian.h> without le16toh. compat/endian.h then
# include_next's that header and skips its __APPLE__ fallback. Force the
# OSByteOrder aliases so spect.c compiles on iPhoneOS / iPhoneSimulator.
cat >"${CONFIG_DIR}/apple_endian.h" <<'EOF'
#pragma once
#include <libkern/OSByteOrder.h>
#ifndef le16toh
#define le16toh(x) OSSwapLittleToHostInt16(x)
#endif
#ifndef le32toh
#define le32toh(x) OSSwapLittleToHostInt32(x)
#endif
#ifndef le64toh
#define le64toh(x) OSSwapLittleToHostInt64(x)
#endif
#ifndef be16toh
#define be16toh(x) OSSwapBigToHostInt16(x)
#endif
#ifndef be32toh
#define be32toh(x) OSSwapBigToHostInt32(x)
#endif
#ifndef be64toh
#define be64toh(x) OSSwapBigToHostInt64(x)
#endif
EOF

# All libespeak-ng C sources except sPlayer.c (speech-player), plus UCD.
# Async / mbrola / pcaudio stay compiled out via config.h.
SOURCES=""
for f in "${SRC_DIR}"/src/libespeak-ng/*.c; do
  case "$(basename "${f}")" in
    sPlayer.c) continue ;;
  esac
  SOURCES="${SOURCES} ${f}"
done
for f in case categories ctype proplist scripts tostring; do
  SOURCES="${SOURCES} ${SRC_DIR}/src/ucd-tools/src/${f}.c"
done

INCLUDES="-I${CONFIG_DIR} -include ${CONFIG_DIR}/apple_endian.h"
INCLUDES="${INCLUDES} -I${SRC_DIR}/src/include"
INCLUDES="${INCLUDES} -I${SRC_DIR}/src/include/compat"
INCLUDES="${INCLUDES} -I${SRC_DIR}/src/include/espeak-ng"
INCLUDES="${INCLUDES} -I${SRC_DIR}/src/ucd-tools/src/include"
INCLUDES="${INCLUDES} -I${SRC_DIR}/src/libespeak-ng"

CFLAGS="-std=c11 -O2 -fPIC -fvisibility=hidden -fno-exceptions -fwrapv"
CFLAGS="${CFLAGS} -DLIBESPEAK_NG_EXPORT=1"
CFLAGS="${CFLAGS} -Wno-unused-parameter -Wno-unused-function"
CFLAGS="${CFLAGS} -Wno-missing-prototypes -Wno-int-conversion"

compile_one() {
  sdk="$1"
  target="$2"
  out="$3"
  sysroot="$(xcrun --sdk "${sdk}" --show-sdk-path)"
  cc="$(xcrun --sdk "${sdk}" --find clang)"
  # shellcheck disable=SC2086
  "${cc}" -dynamiclib \
    -isysroot "${sysroot}" \
    -target "${target}" \
    -install_name @rpath/eSpeakNG.framework/eSpeakNG \
    -current_version 1.0.0 \
    -compatibility_version 1.0.0 \
    ${CFLAGS} ${INCLUDES} \
    ${SOURCES} \
    -o "${out}"
}

OBJ="${ROOT}/.build/ios-obj"
mkdir -p "${OBJ}"

echo "building iphoneos arm64..."
compile_one iphoneos "arm64-apple-ios${MIN_IOS}" "${OBJ}/libespeak-ng.ios-arm64.dylib"

echo "building iphonesimulator arm64..."
compile_one iphonesimulator "arm64-apple-ios${MIN_IOS}-simulator" \
  "${OBJ}/libespeak-ng.sim-arm64.dylib"

echo "building iphonesimulator x86_64..."
compile_one iphonesimulator "x86_64-apple-ios${MIN_IOS}-simulator" \
  "${OBJ}/libespeak-ng.sim-x86_64.dylib"

lipo -create \
  "${OBJ}/libespeak-ng.sim-arm64.dylib" \
  "${OBJ}/libespeak-ng.sim-x86_64.dylib" \
  -output "${OBJ}/libespeak-ng.simulator.dylib"

cp "${OBJ}/libespeak-ng.ios-arm64.dylib" "${ROOT}/ios/libespeak-ng.dylib"
cp "${OBJ}/libespeak-ng.simulator.dylib" "${ROOT}/ios/libespeak-ng.simulator.dylib"
chmod +x "${ROOT}/ios/libespeak-ng.dylib" "${ROOT}/ios/libespeak-ng.simulator.dylib"

echo "vendored:"
file "${ROOT}/ios/libespeak-ng.dylib"
file "${ROOT}/ios/libespeak-ng.simulator.dylib"
otool -L "${ROOT}/ios/libespeak-ng.dylib"
nm -gU "${ROOT}/ios/libespeak-ng.dylib" | grep -c 'T _espeak_'

# App Store Connect rejects a naked .dylib in Frameworks/ (ITMS-90426).
sh "${ROOT}/wrap_ios_framework.sh"
