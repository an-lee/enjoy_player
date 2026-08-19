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
if [[ ! -f "${frameworks}/eSpeakNG.framework/eSpeakNG" ]]; then
  echo "::error::missing Payload/Runner.app/Frameworks/eSpeakNG.framework/eSpeakNG" >&2
  exit 1
fi

# Naked .dylibs in Frameworks/ are not supported on iOS (TN2435). App Store
# Connect reports that as ITMS-90426 ("SwiftSupport folder is missing") or
# ITMS-90429 because it treats every .dylib as a Swift stdlib.
naked_dylibs=()
while IFS= read -r dylib; do
  naked_dylibs+=("${dylib}")
done < <(find "${frameworks}" -maxdepth 1 -name '*.dylib' -type f | sort)

if [[ ${#naked_dylibs[@]} -gt 0 ]]; then
  echo "::error::standalone .dylib files in Frameworks/ are not allowed on iOS (TN2435 / ITMS-90426):" >&2
  printf '  %s\n' "${naked_dylibs[@]#"${tmp_dir}/"}" >&2
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
