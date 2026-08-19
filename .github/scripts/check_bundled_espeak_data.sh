#!/usr/bin/env bash
# Assert a packaged espeak-ng-data directory has phoneme tables + focus voices.
# Keep the voice list in sync with kEspeakVoiceByLanguageTag.
#
# Usage: check_bundled_espeak_data.sh <path/to/espeak-ng-data> [<path/to/libespeak-ng.dylib>]
#
# Pass the dylib path on iOS/macOS app bundles so we also assert the dynamic
# library (DynamicLibrary.open at runtime) is present next to the data. The
# dylib is embedded by the Xcode "Embed Frameworks" build phase, so a missing
# dylib means the dylib was stripped by xcodebuild -exportArchive (the same
# failure mode that drops the Swift stdlib dylibs in ITMS-90429).
set -euo pipefail

data="${1:-}"
lib="${2:-}"
if [ -z "${data}" ] || [ ! -d "${data}" ]; then
  echo "usage: $0 <path/to/espeak-ng-data> [<path/to/libespeak-ng.dylib>]" >&2
  echo "missing directory: ${data:-<(empty)>}" >&2
  exit 1
fi

voices=(en-us en-gb ja ko es es-419 fr-fr fr-ca)

if [ ! -f "${data}/phontab" ]; then
  echo "::error::missing ${data}/phontab" >&2
  exit 1
fi

for voice in "${voices[@]}"; do
  if [ ! -f "${data}/lang/${voice}" ]; then
    echo "::error::missing ${data}/lang/${voice} (espeak_SetVoiceByName will fail)" >&2
    exit 1
  fi
done

if [ -n "${lib}" ]; then
  if [ ! -f "${lib}" ]; then
    echo "::error::missing ${lib} (DynamicLibrary.open will throw spokenReferenceUnavailable at runtime)" >&2
    exit 1
  fi
fi

echo "bundled eSpeak data ok: ${data}${lib:+ (lib=${lib})}"
