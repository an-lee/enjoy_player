#!/usr/bin/env bash
# Upload a signed Play AAB to Google Play (alpha track / draft by default).
#
# Auth (either):
#   GOOGLE_PLAY_SERVICE_ACCOUNT_JSON       — raw JSON string (CI secret)
#   GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH  — path to JSON file (local)
#
# Optional:
#   GOOGLE_PLAY_PACKAGE_NAME      (default: ai.enjoy.player)
#   GOOGLE_PLAY_TRACK             (default: alpha)
#   GOOGLE_PLAY_RELEASE_STATUS    (default: draft)
#
# Usage:
#   bash .github/scripts/upload_play_aab.sh path/to/EnjoyPlayer-vX.Y.Z.aab
set -euo pipefail

scripts="$(cd "$(dirname "$0")" && pwd)"

AAB="${1:-}"
if [[ -z "${AAB}" ]]; then
  echo "Usage: $0 <path-to.aab>" >&2
  exit 1
fi
if [[ ! -f "${AAB}" ]]; then
  echo "AAB not found: ${AAB}" >&2
  exit 1
fi

has_json="${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:-}"
has_path="${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH:-}"
if [[ -z "${has_json}" && -z "${has_path}" ]]; then
  echo "Skipping Play upload: GOOGLE_PLAY_SERVICE_ACCOUNT_JSON(_PATH) not set."
  exit 0
fi

echo ">>> Ensure Play upload tooling"
# shellcheck source=ensure_play_upload_tooling.sh
source "${scripts}/ensure_play_upload_tooling.sh"

py="${PLAY_UPLOAD_PYTHON:-${scripts}/.play-upload-venv/bin/python}"
if [[ ! -x "${py}" ]]; then
  echo "Play upload Python not found at ${py}" >&2
  exit 1
fi

package="${GOOGLE_PLAY_PACKAGE_NAME:-ai.enjoy.player}"
track="${GOOGLE_PLAY_TRACK:-alpha}"
status="${GOOGLE_PLAY_RELEASE_STATUS:-draft}"

echo ">>> Verify AAB signing for Play"
bash "${scripts}/verify_android_aab_for_play.sh" "${AAB}"

echo ">>> Upload AAB to Google Play (package=${package} track=${track} status=${status})"
echo "    $(basename "${AAB}")"

"${py}" "${scripts}/upload_play_aab.py" "${AAB}" \
  --package-name "${package}" \
  --track "${track}" \
  --status "${status}"

echo "Play upload complete."
