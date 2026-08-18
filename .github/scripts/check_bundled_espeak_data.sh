#!/usr/bin/env bash
# Assert a packaged espeak-ng-data directory has phoneme tables + focus voices.
# Keep the voice list in sync with kEspeakVoiceByLanguageTag.
#
# Usage: check_bundled_espeak_data.sh <path/to/espeak-ng-data>
set -euo pipefail

data="${1:-}"
if [ -z "${data}" ] || [ ! -d "${data}" ]; then
  echo "usage: $0 <path/to/espeak-ng-data>" >&2
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

echo "bundled eSpeak data ok: ${data}"
