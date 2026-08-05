#!/usr/bin/env bash
# Preflight checklist for local / self-hosted Apple releases.
# Covers: toolchain, Keychain identities, ASC secrets, notary, Homebrew, publish.
set -euo pipefail

lib="$(dirname "$0")/release_lib.sh"
# shellcheck source=release_lib.sh
source "${lib}"

root="$(release_repo_root)"
cd "${root}"

errors=0
warns=0

fail() { echo "FAIL: $*" >&2; errors=$((errors + 1)); }
warn() { echo "WARN: $*" >&2; warns=$((warns + 1)); }
ok() { echo "OK:   $*"; }
info() { echo "INFO: $*"; }

echo "=== Apple release preflight ==="
echo

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "macOS host required"
  exit 1
fi

echo "--- Toolchain ---"
if ! command -v flutter >/dev/null 2>&1; then
  fail "flutter not on PATH"
else
  ok "flutter $(flutter --version 2>/dev/null | awk '/Flutter/ {print $2; exit}')"
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  fail "xcodebuild not on PATH"
else
  ok "xcodebuild $(xcodebuild -version 2>/dev/null | head -1)"
fi

if ! command -v pod >/dev/null 2>&1; then
  warn "CocoaPods (pod) not on PATH"
else
  ok "pod $(pod --version 2>/dev/null | head -1)"
fi

echo
echo "--- Keychain identities (team 46X685R747) ---"
dev_id="$(
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Developer ID Application/ { print $2; exit }'
)"
if [[ -z "${dev_id}" ]]; then
  fail "Developer ID Application cert missing (macOS direct download)"
else
  ok "Developer ID: ${dev_id}"
fi

dist_id="$(
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Distribution/ { print $2; exit }'
)"
if [[ -z "${dist_id}" ]]; then
  warn "Apple Distribution cert missing — TestFlight / App Store IPA signing will fail"
else
  ok "Apple Distribution: ${dist_id}"
fi

if [[ -n "${dev_id}" ]]; then
  probe="$(mktemp -t enjoy-codesign-probe)"
  cp /bin/ls "${probe}"
  if codesign --force --sign "${dev_id}" "${probe}" >/dev/null 2>&1; then
    ok "Keychain allows codesign with Developer ID"
  else
    fail "codesign failed (keychain locked or private key inaccessible). Run: security unlock-keychain login.keychain-db"
  fi
  rm -f "${probe}"
fi

echo
echo "--- App Store Connect secrets (~/.config/enjoy-player/) ---"
asc_dir="$(release_asc_config_dir)"
asc_env="${asc_dir}/asc.env"
info "secrets root: ${asc_dir}"

# Load without printing private key material.
unset APP_STORE_CONNECT_API_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_PRIVATE_KEY
release_load_asc_env "${root}" >/dev/null

if [[ -f "${asc_env}" ]]; then
  ok "asc.env present"
else
  warn "asc.env missing — create ${asc_env} with APP_STORE_CONNECT_API_KEY_ID + ISSUER_ID"
fi

if [[ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ]]; then
  ok "API key id: ${APP_STORE_CONNECT_API_KEY_ID}"
  # Single source of truth for key location: release_resolve_asc_private_key.
  # We render its bucket/path into the existing OK/WARN messages so the preflight
  # agrees with release_load_asc_env about where the .p8 came from.
  if resolved="$(release_resolve_asc_private_key "${root}" "${asc_dir}" "${APP_STORE_CONNECT_API_KEY_ID}")"; then
    resolved_bucket="${resolved%%	*}"
    resolved_path="${resolved#*	}"
    case "${resolved_bucket}" in
      cache)
        ok "AuthKey at ${resolved_path}"
        ;;
      legacy)
        warn "AuthKey still at legacy ${resolved_path} — move to ${asc_dir}/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
        ;;
      standard)
        ok "AuthKey at standard location ${resolved_path}"
        warn "Move AuthKey to ${asc_dir}/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8 so it survives runner re-imaging"
        ;;
      explicit)
        ok "AuthKey from APP_STORE_CONNECT_API_PRIVATE_KEY_PATH (${resolved_path})"
        ;;
    esac
  else
    warn "AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8 not found under ${asc_dir}"
  fi
else
  warn "APP_STORE_CONNECT_API_KEY_ID unset after load"
fi

if [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  ok "Issuer id: ${APP_STORE_CONNECT_ISSUER_ID}"
else
  warn "APP_STORE_CONNECT_ISSUER_ID unset after load"
fi

if release_asc_env_ready; then
  ok "ASC credentials ready for --testflight / --notarize"
else
  warn "ASC credentials incomplete — --testflight will fail hard"
fi

echo
echo "--- Notary ---"
profile="${NOTARY_PROFILE:-enjoy-notary}"
if xcrun notarytool history --keychain-profile "${profile}" >/dev/null 2>&1; then
  ok "notary profile '${profile}' reachable"
else
  warn "notary profile '${profile}' not ready (store credentials before --notarize)"
fi

echo
echo "--- Homebrew (macos/Brewfile) ---"
missing_brew=0
while read -r formula; do
  [[ -n "${formula}" ]] || continue
  if ! brew list "${formula}" >/dev/null 2>&1; then
    warn "Homebrew formula missing: ${formula}"
    missing_brew=1
  fi
done < <(grep -E '^brew ' "${root}/macos/Brewfile" | awk '{print $2}' | tr -d '"')

if [[ "${missing_brew}" -eq 0 ]]; then
  ok "Homebrew FFmpeg deps installed"
else
  warn "Run: brew bundle install --file=macos/Brewfile"
fi

echo
echo "--- Artifacts (ephemeral; optional) ---"
ipa_count=0
if compgen -G "${root}/build/ios/ipa/"*.ipa >/dev/null 2>&1; then
  for f in "${root}"/build/ios/ipa/*.ipa; do
    info "IPA: ${f}"
    ipa_count=$((ipa_count + 1))
  done
  ok "${ipa_count} IPA(s) under build/ios/ipa/"
else
  info "No IPA yet (build with --ios-only or full apple release)"
fi

zip_path="$(release_macos_zip_path "${root}" 2>/dev/null || true)"
if [[ -n "${zip_path}" && -f "${zip_path}" ]]; then
  ok "macOS zip: ${zip_path}"
else
  info "No macOS zip yet (build with --macos-only or full apple release)"
fi

echo
echo "--- Publish (optional) ---"
if [[ -f "${root}/.github/scripts/publish_env.local.sh" ]]; then
  if command -v aws >/dev/null 2>&1; then
    ok "publish_env.local.sh + aws CLI $(aws --version 2>/dev/null | awk '{print $1}')"
  else
    warn "publish_env.local.sh present but aws CLI missing (brew install awscli)"
  fi
else
  info "publish_env.local.sh absent (only needed for --publish to dl.enjoy.bot)"
fi

echo
if [[ "${errors}" -gt 0 ]]; then
  echo "${errors} check(s) failed, ${warns} warning(s)." >&2
  exit 1
fi

echo "Apple release preflight passed (${warns} warning(s))."
exit 0
