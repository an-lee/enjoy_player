#!/usr/bin/env bash
# Compile-only iOS smoke build for CI without code signing.
#
# Builds for iphoneos (generic iOS device), not the simulator:
# - ffmpeg_kit_flutter_new lacks arm64 for Apple Silicon iOS 26+ simulators.
# - Simulator destinations require a current CoreSimulator framework from
#   xcodebuild -runFirstLaunch (see ensure_ios_ci_toolchain.sh).
#
# Requires the iOS platform matching the active Xcode SDK (install via
# ensure_ios_ci_toolchain.sh or Xcode > Settings > Components).
set -euo pipefail

configuration="${1:?Usage: $0 Debug|Release}"

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${root}"

# shellcheck source=apple_spm_hygiene.sh
source "${root}/.github/scripts/apple_spm_hygiene.sh"
apple_sanitize_git_env_for_spm

case "${configuration}" in
  Debug | Release) ;;
  *)
    echo "Unsupported configuration: ${configuration}" >&2
    exit 1
    ;;
esac

config_flag="$(echo "${configuration}" | tr '[:upper:]' '[:lower:]')"

build_with_retry() {
  apple_retry_spm_command "${root}" \
    flutter build ios --"${config_flag}" --config-only --no-codesign

  apple_retry_spm_command "${root}" \
    xcodebuild \
    -workspace ios/Runner.xcworkspace \
    -scheme Runner \
    -configuration "${configuration}" \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath build/ios/DerivedData \
    CODE_SIGNING_ALLOWED=NO \
    build
}

apple_with_spm_host_lock build_with_retry
