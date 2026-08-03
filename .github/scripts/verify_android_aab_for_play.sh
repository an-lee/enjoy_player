#!/usr/bin/env bash
# Reject AABs that cannot be uploaded to Google Play (debug-signed, etc.).
#
# Usage:
#   bash .github/scripts/verify_android_aab_for_play.sh path/to.aab
set -euo pipefail

AAB="${1:-}"
if [[ -z "${AAB}" || ! -f "${AAB}" ]]; then
  echo "Usage: $0 <path-to.aab>" >&2
  exit 1
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "WARNING: keytool not on PATH; skipping AAB signing preflight." >&2
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

if ! unzip -o -q "${AAB}" 'META-INF/*' -d "${tmp}" 2>/dev/null; then
  echo "WARNING: could not read META-INF from ${AAB}; skipping signing preflight." >&2
  exit 0
fi

cert=""
for candidate in "${tmp}/META-INF"/*.RSA "${tmp}/META-INF"/*.DSA "${tmp}/META-INF"/*.EC; do
  if [[ -f "${candidate}" ]]; then
    cert="${candidate}"
    break
  fi
done

if [[ -z "${cert}" ]]; then
  echo "WARNING: no signing cert in ${AAB}; skipping signing preflight." >&2
  exit 0
fi

info="$(keytool -printcert -file "${cert}" 2>/dev/null || true)"
owner="$(printf '%s\n' "${info}" | sed -n 's/^Owner: //p' | head -1)"
sha1="$(printf '%s\n' "${info}" | sed -n 's/^[[:space:]]*SHA1: //p' | head -1)"

echo "AAB signing cert: ${owner:-unknown}"
echo "AAB SHA1: ${sha1:-unknown}"

if printf '%s\n' "${owner}" | grep -qiE 'CN=Android Debug|O=Android'; then
  cat >&2 <<EOF
Play upload aborted: AAB is signed with the Android debug keystore.
  file: ${AAB}
  cert: ${owner}
  SHA1: ${sha1}

Fix:
  1. Install the Play upload keystore (SHA1 must match Play Console →
     Setup → App signing → Upload key certificate).
  2. Copy android/key.properties.example → android/key.properties and point
     storeFile at that keystore.
  3. Rebuild the store AAB (do not reuse a debug-signed --publish-only artifact):
       bash .github/scripts/release.sh --platform android --play

GitHub Actions already has ANDROID_KEYSTORE_* secrets; locally you need the
same .jks + passwords in android/key.properties (see docs/android-release-ci.md).
EOF
  exit 1
fi
