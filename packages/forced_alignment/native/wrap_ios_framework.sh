#!/bin/sh
# Wrap vendored iOS libespeak-ng dylibs as eSpeakNG.xcframework.
#
# iOS App Store Connect treats a naked .dylib in Frameworks/ as a Swift
# stdlib (TN2435) and rejects the IPA with ITMS-90426 / ITMS-90429.
# Packaging as a real framework is the supported layout.
#
# Usage: wrap_ios_framework.sh
# Reads:  ios/libespeak-ng.dylib, ios/libespeak-ng.simulator.dylib
# Writes: ios/eSpeakNG.xcframework
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")" && pwd)"
IOS_DIR="${ROOT}/ios"
DEVICE_DYLIB="${IOS_DIR}/libespeak-ng.dylib"
SIM_DYLIB="${IOS_DIR}/libespeak-ng.simulator.dylib"
OUT="${IOS_DIR}/eSpeakNG.xcframework"
MIN_IOS="${MIN_IOS:-15.0}"

if [ ! -f "${DEVICE_DYLIB}" ] || [ ! -f "${SIM_DYLIB}" ]; then
  echo "wrap_ios_framework: missing ${DEVICE_DYLIB} or ${SIM_DYLIB}" >&2
  echo "Run native/build_ios.sh first." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "wrap_ios_framework: xcodebuild is required (macOS / Xcode)." >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/espeak-xcframework.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

write_info_plist() {
  dest="$1"
  platform="$2"
  cat >"${dest}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>eSpeakNG</string>
	<key>CFBundleIdentifier</key>
	<string>ai.enjoy.player.espeakng</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>eSpeakNG</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.52.0</string>
	<key>CFBundleVersion</key>
	<string>1.52.0</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>${platform}</string>
	</array>
	<key>MinimumOSVersion</key>
	<string>${MIN_IOS}</string>
</dict>
</plist>
EOF
}

make_framework() {
  src_dylib="$1"
  platform="$2"
  dest_dir="$3"
  mkdir -p "${dest_dir}"
  cp "${src_dylib}" "${dest_dir}/eSpeakNG"
  chmod +x "${dest_dir}/eSpeakNG"
  install_name_tool -id @rpath/eSpeakNG.framework/eSpeakNG "${dest_dir}/eSpeakNG"
  write_info_plist "${dest_dir}/Info.plist" "${platform}"
}

DEVICE_FW="${WORK}/iphoneos/eSpeakNG.framework"
SIM_FW="${WORK}/iphonesimulator/eSpeakNG.framework"
make_framework "${DEVICE_DYLIB}" iPhoneOS "${DEVICE_FW}"
make_framework "${SIM_DYLIB}" iPhoneSimulator "${SIM_FW}"

rm -rf "${OUT}"
xcodebuild -create-xcframework \
  -framework "${DEVICE_FW}" \
  -framework "${SIM_FW}" \
  -output "${OUT}" >/dev/null

echo "wrap_ios_framework: ${OUT}"
file "${OUT}/ios-arm64/eSpeakNG.framework/eSpeakNG"
file "${OUT}/ios-arm64_x86_64-simulator/eSpeakNG.framework/eSpeakNG"
