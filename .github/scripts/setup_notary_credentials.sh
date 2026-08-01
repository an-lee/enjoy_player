#!/usr/bin/env bash
# Register notarytool credentials for this job from App Store Connect API key secrets.
set -euo pipefail

lib="$(dirname "$0")/release_lib.sh"
# shellcheck source=release_lib.sh
source "${lib}"

PROFILE="${NOTARY_PROFILE:-enjoy-notary}"

for var in APP_STORE_CONNECT_API_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_PRIVATE_KEY; do
  if [ -z "${!var:-}" ]; then
    echo "App Store Connect API env not set; using existing notary profile (${PROFILE})." >&2
    exit 0
  fi
done

KEY_PATH="${RUNNER_TEMP:-/tmp}/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
release_write_asc_api_private_key "${KEY_PATH}"

xcrun notarytool store-credentials "${PROFILE}" \
  --key "${KEY_PATH}" \
  --key-id "${APP_STORE_CONNECT_API_KEY_ID}" \
  --issuer "${APP_STORE_CONNECT_ISSUER_ID}"

# Cache non-secret ASC identifiers on self-hosted runners for local recovery tooling.
ASC_CACHE_DIR="${HOME}/.config/enjoy-player"
mkdir -p "${ASC_CACHE_DIR}"
umask 077
cat >"${ASC_CACHE_DIR}/asc.env" <<EOF
APP_STORE_CONNECT_API_KEY_ID=${APP_STORE_CONNECT_API_KEY_ID}
APP_STORE_CONNECT_ISSUER_ID=${APP_STORE_CONNECT_ISSUER_ID}
EOF
chmod 600 "${ASC_CACHE_DIR}/asc.env"

echo "Registered notary profile: ${PROFILE}"
rm -f "${KEY_PATH}"
