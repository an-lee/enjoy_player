#!/usr/bin/env bash
# Local + CI release entry point. Delegates to platform scripts (same logic as GitHub workflows).
#
# Usage (see docs/packaging.md):
#   bash .github/scripts/release.sh --platform windows
#   bash .github/scripts/release.sh --platform android          # Linux or Git Bash
#   bash .github/scripts/release.sh --platform apple --notarize # macOS only
#   bash .github/scripts/release.sh --platform windows --publish
#   bash .github/scripts/release.sh --platform all --publish-only --publish
#   bash .github/scripts/release.sh --platform windows --feeds-only
#
# From repo root on Windows (loads publish_env.local.ps1 when present):
#   pwsh ./release.ps1
#   pwsh ./release.ps1 -Platform android -Publish
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
scripts="${root}/.github/scripts"

PLATFORM=""
ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    -h | --help)
      cat <<'EOF'
Enjoy Player release (shared local + CI logic)
See docs/packaging.md for the full runbook.

  bash .github/scripts/release.sh --platform <windows|android|apple|linux|all> [options]

Host matrix:
  Windows host  → --platform windows   (or: pwsh ./release.ps1)
  Windows/Linux → --platform android   (or: pwsh ./release.ps1 -Platform android)
  macOS host    → --platform apple     (requires macOS)
  Linux host    → --platform linux     (requires Linux with flutter build deps)
  Any host      → --platform all --publish-only --publish  (upload every built artifact)

Common options (forwarded to the platform script):
  --skip-checks       Skip flutter analyze / test
  --skip-build        Skip compile; use existing .app (with --notarize to retry notarization)
  --publish-only      Skip build and checks; publish existing artifacts
  --publish           Upload to dl.enjoy.bot (needs S3 env / publish_env.local.*)
  --publish-github    Also upload to the GitHub Release for v$(pubspec) (needs `gh` CLI)
  --feeds-only        Build feeds locally (build/update-feeds/) without S3 upload

Windows:
  --no-installer      Skip Inno Setup .exe

Android:
  --no-apk            Skip sideload APKs
  --no-aab            Skip Play App Bundle
  --play              Upload store AAB to Google Play (alpha track, draft)

Apple (macOS host):
  --notarize          Notarize macOS .app for direct download
  --testflight        Upload IPA to TestFlight (needs ASC API key)
  --macos-only        Skip iOS IPA build (macOS zip only)
  --ios-only          Skip macOS build (IPA / TestFlight only)

Env: copy .github/scripts/publish_env.example.ps1 → publish_env.local.ps1
     or publish_env.example.sh → publish_env.local.sh
Local Apple secrets (TestFlight / notary) live in one place:
  ~/.config/enjoy-player/asc.env           # KEY_ID + ISSUER_ID
  ~/.config/enjoy-player/AuthKey_<ID>.p8   # private key
Preflight: bash .github/scripts/verify_macos_release_env.sh
EOF
      exit 0
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ -z "${PLATFORM}" ]]; then
  echo "Missing --platform (windows|android|apple|linux|all). Try --help." >&2
  exit 1
fi

case "${PLATFORM}" in
  all)
    exec bash "${scripts}/release_publish.sh" "${ARGS[@]}"
    ;;
  windows)
    exec bash "${scripts}/release_windows.sh" "${ARGS[@]}"
    ;;
  android)
    exec bash "${scripts}/release_android.sh" "${ARGS[@]}"
    ;;
  apple)
    exec bash "${scripts}/release_apple.sh" "${ARGS[@]}"
    ;;
  linux)
    exec bash "${scripts}/release_linux.sh" "${ARGS[@]}"
    ;;
  *)
    echo "Unknown platform: ${PLATFORM}" >&2
    exit 1
    ;;
  esac
