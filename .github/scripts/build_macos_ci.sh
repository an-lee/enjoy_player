#!/usr/bin/env bash
# Compile-only macOS smoke build for CI without Apple Development signing.
#
# flutter build macos does not forward xcodebuild settings after "--"; those
# positional args are treated as Dart entrypoints. Use config-only + xcodebuild
# with CODE_SIGNING_ALLOWED=NO instead (see ADR/docs in packaging.md for why
# local dev keeps Apple Development signing on the Runner target).
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

# Xcode 16 SwiftPM can crash (NSMutableArray insertObjects:atIndexes: count
# mismatch) when stale package resolution state lingers. Clear caches so each
# CI run starts from a clean slate.
apple_clear_spm_caches "${root}"

build_with_retry() {
  apple_retry_spm_command "${root}" \
    flutter build macos --"${config_flag}" --config-only

  apple_retry_spm_command "${root}" \
    xcodebuild \
    -workspace macos/Runner.xcworkspace \
    -scheme Runner \
    -configuration "${configuration}" \
    -derivedDataPath build/macos \
    CODE_SIGNING_ALLOWED=NO \
    build
}

apple_with_spm_host_lock build_with_retry
