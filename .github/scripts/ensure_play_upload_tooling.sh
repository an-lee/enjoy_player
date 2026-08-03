#!/usr/bin/env bash
# Ensure Python 3 + Google Play upload deps for upload_play_aab.py.
# Idempotent: installs only what's missing into a repo-local venv.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
venv_dir="${root}/.github/scripts/.play-upload-venv"
req_marker="${venv_dir}/.deps-ok"

have() { command -v "$1" >/dev/null 2>&1; }

if ! have python3; then
  echo "::error::python3 is required for Play Store AAB upload" >&2
  exit 1
fi

python3_bin="$(command -v python3)"
echo "python3: ${python3_bin} ($(${python3_bin} --version 2>&1 || true))"

if [[ ! -x "${venv_dir}/bin/python" ]]; then
  echo ">>> Creating Play upload venv at ${venv_dir}"
  python3 -m venv "${venv_dir}"
fi

# shellcheck disable=SC1091
source "${venv_dir}/bin/activate"

if [[ ! -f "${req_marker}" ]]; then
  echo ">>> Installing google-auth + google-api-python-client"
  python -m pip install --upgrade pip >/dev/null
  python -m pip install \
    'google-auth>=2.29.0,<3' \
    'google-api-python-client>=2.127.0,<3'
  touch "${req_marker}"
fi

# Quick import check so release fails early with a clear message.
python - <<'PY'
from google.oauth2 import service_account  # noqa: F401
from googleapiclient.discovery import build  # noqa: F401
print("Play upload Python deps OK")
PY

echo "PLAY_UPLOAD_PYTHON=${venv_dir}/bin/python"
export PLAY_UPLOAD_PYTHON="${venv_dir}/bin/python"
