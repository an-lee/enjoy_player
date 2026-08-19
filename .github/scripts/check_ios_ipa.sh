#!/usr/bin/env bash
# Verify the exported iOS IPA contains the files App Store Connect expects.
#
# Usage: check_ios_ipa.sh <path/to/app.ipa>
set -euo pipefail

ipa="${1:-}"
if [[ -z "${ipa}" || ! -f "${ipa}" ]]; then
  echo "usage: $0 <path/to/app.ipa>" >&2
  exit 1
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/enjoy-player-ipa.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT

unzip -q "${ipa}" -d "${tmp_dir}"
app="${tmp_dir}/Payload/Runner.app"
if [[ ! -d "${app}" ]]; then
  echo "::error::missing Payload/Runner.app in ${ipa}" >&2
  exit 1
fi

frameworks="${app}/Frameworks"
if [[ ! -f "${frameworks}/libespeak-ng.dylib" ]]; then
  echo "::error::missing Payload/Runner.app/Frameworks/libespeak-ng.dylib" >&2
  exit 1
fi

swift_support="${tmp_dir}/SwiftSupport/iphoneos"
if [[ ! -d "${swift_support}" ]] ||
   ! compgen -G "${swift_support}/libswift*.dylib" >/dev/null; then
  echo "::error::missing SwiftSupport/iphoneos Swift runtime libraries" >&2
  exit 1
fi

minimum_os="$(
  plutil -extract MinimumOSVersion raw -o - "${app}/Info.plist"
)"
if [[ "${minimum_os}" != "15.0" ]]; then
  echo "::error::expected MinimumOSVersion 15.0, found ${minimum_os}" >&2
  exit 1
fi

codesign --verify --deep --strict "${app}"
echo "iOS IPA packaging ok: ${ipa} (MinimumOSVersion=${minimum_os})"
