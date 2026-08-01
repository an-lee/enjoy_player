#!/usr/bin/env bash
# Import a downloaded Apple Distribution .cer with the matching local private key.
#
# Usage:
#   bash .github/scripts/import_ios_distribution_cer.sh ~/Downloads/distribution.cer
#
# Expects the private key at .apple/ios_distribution.key (created by
# ensure_ios_distribution_identity.sh or by generating a CSR for portal upload).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cer="${1:-}"
key="${root}/.apple/ios_distribution.key"

if [[ -z "${cer}" || ! -f "${cer}" ]]; then
  echo "Usage: $0 /path/to/apple_distribution.cer" >&2
  exit 1
fi
if [[ ! -f "${key}" ]]; then
  echo "Missing private key: ${key}" >&2
  echo "Generate a CSR first, upload it when creating the certificate, then retry." >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT
pem="${workdir}/ios_distribution.pem"
p12="${workdir}/ios_distribution.p12"
pass="$(openssl rand -base64 24)"

if ! openssl x509 -inform DER -in "${cer}" -out "${pem}" 2>/dev/null; then
  openssl x509 -in "${cer}" -out "${pem}"
fi

subj="$(openssl x509 -in "${pem}" -noout -subject)"
if [[ "${subj}" != *"Apple Distribution"* && "${subj}" != *"iPhone Distribution"* ]]; then
  echo "Warning: certificate subject does not look like Apple Distribution:" >&2
  echo "  ${subj}" >&2
fi

openssl pkcs12 -export \
  -inkey "${key}" \
  -in "${pem}" \
  -out "${p12}" \
  -passout "pass:${pass}" \
  -name "Apple Distribution"

keychain="${HOME}/Library/Keychains/login.keychain-db"
[[ -f "${keychain}" ]] || keychain="login.keychain"

security import "${p12}" -k "${keychain}" -P "${pass}" \
  -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/xcrun
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "${keychain}" >/dev/null 2>&1 || true

if ! security find-identity -v -p codesigning 2>/dev/null | grep -q 'Apple Distribution'; then
  echo "Import finished but Apple Distribution identity is still missing." >&2
  echo "Usually this means the .cer was not issued for ${key}." >&2
  security find-identity -v -p codesigning >&2 || true
  exit 1
fi

echo "Imported Apple Distribution identity:"
security find-identity -v -p codesigning | awk '/Apple Distribution/ { print }'
