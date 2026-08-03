#!/usr/bin/env bash
# Rename Flutter release outputs to versioned filenames (semver from pubspec.yaml).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${root}"

version="$(bash "${root}/.github/scripts/read_pubspec_version.sh")"
prefix="EnjoyPlayer-v${version}"

rename_if_exists() {
  local src="$1"
  local dest="$2"
  if [[ -f "${src}" ]]; then
    mv -f "${src}" "${dest}"
    echo "Renamed: $(basename "${dest}")"
    return 0
  fi
  return 1
}

rename_first_match() {
  local dest="$1"
  shift
  local candidate
  for candidate in "$@"; do
    if rename_if_exists "${candidate}" "${dest}"; then
      return 0
    fi
  done
  return 1
}

platform="${1:-all}"

rename_android() {
  local aab_dest="build/app/outputs/bundle/release/${prefix}.aab"
  mkdir -p "$(dirname "${aab_dest}")"
  # AAB-only (--no-apk) and APK-only (--no-aab) builds are valid; missing
  # artifacts are OK here — release_android.sh validates what it requested.
  rename_first_match "${aab_dest}" \
    "build/app/outputs/bundle/storeRelease/app-store-release.aab" \
    "build/app/outputs/bundle/storeRelease/app-release.aab" \
    "build/app/outputs/bundle/release/app-release.aab" || true

  local apk_dir="build/app/outputs/flutter-apk"
  local abi
  for abi in arm64-v8a armeabi-v7a x86_64; do
    rename_first_match "${apk_dir}/${prefix}-${abi}.apk" \
      "${apk_dir}/app-${abi}-direct-release.apk" \
      "${apk_dir}/app-direct-${abi}-release.apk" \
      "${apk_dir}/app-${abi}-release.apk" || true
  done
}

rename_apple() {
  local ipa_dir="build/ios/ipa"
  if compgen -G "${ipa_dir}/*.ipa" >/dev/null; then
    local ipa
    ipa="$(ls -1 "${ipa_dir}"/*.ipa | head -1)"
    rename_if_exists "${ipa}" "${ipa_dir}/${prefix}.ipa"
  fi
}

case "${platform}" in
  android) rename_android ;;
  apple) rename_apple ;;
  all)
    rename_android
    rename_apple
    ;;
  *)
    echo "Usage: $0 [android|apple|all]" >&2
    exit 1
    ;;
esac

echo "Release artifact prefix: ${prefix}"
