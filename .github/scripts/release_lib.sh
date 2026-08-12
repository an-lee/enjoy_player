#!/usr/bin/env bash
# Shared helpers for local + CI release scripts.
set -euo pipefail

# macOS ships Bash 3.2: empty "${array[@]}" is fatal with set -u. Use these helpers
# instead of associative arrays (declare -A) or namerefs (local -n).
RELEASE_ARTIFACT_SPECS=()

release_spec_key() {
  echo "${1%%|*}"
}

release_spec_path() {
  echo "${1#*|}"
}

release_spec_path_for_key() {
  local want="$1"
  local spec key
  for spec in ${RELEASE_ARTIFACT_SPECS[@]+"${RELEASE_ARTIFACT_SPECS[@]}"}; do
    key="$(release_spec_key "${spec}")"
    if [[ "${key}" == "${want}" ]]; then
      release_spec_path "${spec}"
      return 0
    fi
  done
  return 1
}

release_hint_publish() {
  local root="$1"
  local zip
  zip="$(release_macos_zip_path "${root}")"
  if [[ -f "${zip}" && "${RELEASE_PUBLISH:-}" != true ]]; then
    echo ""
    echo "Publish skipped. Upload to dl.enjoy.bot with:"
    echo "  bash .github/scripts/release.sh --platform apple --publish-only --publish"
    echo "Configure credentials: .github/scripts/publish_env.example.sh → publish_env.local.sh"
  fi
}

# Resolve the canonical GitHub Release tag for the current build.
# Reads VERSION (override) → "v$(pubspec version)". Examples: 0.7.3 → v0.7.3.
release_github_tag() {
  local version="${VERSION:-$(release_version)}"
  echo "v${version}"
}

# Resolve existing on-disk artifacts for a single platform into the
# RELEASE_ARTIFACT_SPECS that softprops/action-gh-release / gh release upload
# consume. Skips missing files so a partial build still produces a partial
# release (matches the four per-platform workflows' incremental behavior).
release_collect_github_release_files_for_platform() {
  local root="$1"
  local platform="$2"
  local out_name="$3"
  local -a out=()
  local f abi

  case "${platform}" in
    windows)
      f="$(release_windows_installer_path "${root}")"
      if [[ -f "${f}" ]]; then out+=("${f}"); fi
      ;;
    macos)
      f="$(release_macos_zip_path "${root}")"
      if [[ -f "${f}" ]]; then out+=("${f}"); fi
      ;;
    linux)
      f="$(release_linux_appimage_path "${root}")"
      if [[ -f "${f}" ]]; then out+=("${f}"); fi
      ;;
    apple)
      f="$(release_macos_zip_path "${root}")"
      if [[ -f "${f}" ]]; then out+=("${f}"); fi
      compgen -G "${root}/build/ios/ipa/EnjoyPlayer-v"*.ipa >/dev/null 2>&1 || true
      for f in "${root}"/build/ios/ipa/EnjoyPlayer-v*.ipa; do
        if [[ -f "${f}" ]]; then out+=("${f}"); fi
      done
      ;;
    android)
      f="$(release_android_aab_path "${root}")"
      if [[ -f "${f}" ]]; then out+=("${f}"); fi
      for abi in arm64-v8a armeabi-v7a x86_64; do
        f="$(release_android_apk_path "${root}" "${abi}")"
        if [[ -f "${f}" ]]; then out+=("${f}"); fi
      done
      ;;
    all)
      local aab installer appimage zip
      installer="$(release_windows_installer_path "${root}")"
      [[ -f "${installer}" ]] && out+=("${installer}") || true
      aab="$(release_android_aab_path "${root}")"
      [[ -f "${aab}" ]] && out+=("${aab}") || true
      for abi in arm64-v8a armeabi-v7a x86_64; do
        f="$(release_android_apk_path "${root}" "${abi}")"
        [[ -f "${f}" ]] && out+=("${f}") || true
      done
      zip="$(release_macos_zip_path "${root}")"
      [[ -f "${zip}" ]] && out+=("${zip}") || true
      appimage="$(release_linux_appimage_path "${root}")"
      [[ -f "${appimage}" ]] && out+=("${appimage}") || true
      ;;
    *)
      echo "Unknown platform for GitHub Release: ${platform}" >&2
      return 1
      ;;
  esac

  eval "${out_name}=(\"\${out[@]}\")"
}

# Upload artifacts to the GitHub Release for the current tag.
# Creates the release as a draft when it does not exist, and uploads /
# replaces assets on an existing release. Idempotent — safe to re-run.
#
# Requires `gh` CLI on PATH; uses GH_TOKEN / GITHUB_TOKEN when set so the
# same helper works for both maintainer laptops (`gh auth login`) and CI
# (`GITHUB_TOKEN` injected by the runner).
#
# Args:
#   $1 root
#   $2 platform  (windows|macos|linux|apple|android|all)
#   $3 tag       (default: v$(pubspec version))
release_publish_github() {
  local root="$1"
  local platform="$2"
  local tag="${3:-$(release_github_tag)}"

  if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub Release upload failed: gh CLI not found on PATH." >&2
    echo "Install: https://cli.github.com/  (or run from GitHub Actions)." >&2
    return 1
  fi

  local -a files=()
  release_collect_github_release_files_for_platform "${root}" "${platform}" files
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "GitHub Release upload skipped: no artifacts on disk for ${platform} at tag ${tag}." >&2
    echo "Build first, or pass --publish-only with an existing artifact set." >&2
    return 1
  fi

  echo ">>> GitHub Release plan: tag=${tag} platform=${platform}"
  local f
  for f in "${files[@]}"; do
    local size
    size="$(wc -c < "${f}" | tr -d ' ')"
    echo "    ${f}  (${size} bytes)"
  done

  if [[ "${RELEASE_GITHUB_ASSUME_YES:-}" != "true" && -t 0 ]]; then
    local reply
    read -r -p "Upload ${#files[@]} asset(s) to GitHub Release ${tag}? [y/N] " reply
    case "${reply}" in
      y|Y|yes|YES) ;;
      *)
        echo "Aborted by user."
        return 0
        ;;
    esac
  fi

  local -a existing_files=()
  local -a new_files=()
  if gh release view "${tag}" >/dev/null 2>&1; then
    echo ">>> GitHub Release ${tag} already exists; will upload/replace assets."
    while IFS= read -r line; do
      existing_files+=("${line}")
    done < <(gh release view "${tag}" --json assets --jq '.assets[].name' 2>/dev/null || true)
    for f in "${files[@]}"; do
      local base
      base="$(basename "${f}")"
      local found=0
      local existing
      for existing in "${existing_files[@]+"${existing_files[@]}"}"; do
        if [[ "${existing}" == "${base}" ]]; then
          found=1
          break
        fi
      done
      if [[ "${found}" -eq 1 ]]; then
        echo "  - ${base} (already attached; skipping re-upload)"
      else
        new_files+=("${f}")
      fi
    done
  else
    echo ">>> Creating draft GitHub Release ${tag}."
    new_files=("${files[@]}")
    local -a create_args=(
      "${tag}"
      --title "Enjoy Player ${tag}"
      --draft
      --target "$(git -C "${root}" rev-parse --abbrev-ref HEAD 2>/dev/null \
        || git -C "${root}" rev-parse --short HEAD 2>/dev/null \
        || echo main)"
      --notes "Draft release. Notes will be filled in by release_publish.yml."
    )
    GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" \
      gh release create "${create_args[@]}"
  fi

  if [[ ${#new_files[@]} -gt 0 ]]; then
    echo ">>> Uploading ${#new_files[@]} asset(s) to ${tag}"
    GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" \
      gh release upload "${tag}" "${new_files[@]}" --clobber
  fi

  echo ">>> GitHub Release draft: https://github.com/$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || echo '<owner>/<repo>')/releases/tag/${tag}"
  echo "Promote to ready via: gh release edit ${tag} --draft=false"
  echo "Or run .github/workflows/release_publish.yml (workflow_dispatch, finalize=true)."
}

# Validate android/key.properties points at an existing keystore file.
# storeFile is relative to android/ (see android/key.properties.example).
release_require_android_upload_keystore() {
  local root="$1"
  local props="${root}/android/key.properties"
  if [[ ! -f "${props}" ]]; then
    echo "Missing ${props}." >&2
    echo "Copy android/key.properties.example → android/key.properties and place the" >&2
    echo "Play upload .jks next to it, or run setup_android_signing.sh with ANDROID_KEYSTORE_*." >&2
    return 1
  fi

  local store_file=""
  store_file="$(sed -n 's/^storeFile=//p' "${props}" | head -1 | tr -d '\r')"
  if [[ -z "${store_file}" ]]; then
    echo "${props} has no storeFile= entry." >&2
    return 1
  fi

  local ks_path
  if [[ "${store_file}" = /* ]]; then
    ks_path="${store_file}"
  else
    ks_path="${root}/android/${store_file}"
  fi

  if [[ ! -f "${ks_path}" ]]; then
    cat >&2 <<EOF
Release keystore file not found:
  ${ks_path}
  (from storeFile=${store_file} in android/key.properties)

key.properties alone is not enough — place the Play upload .jks at that path.
Expected SHA1 must match Play Console → Setup → App signing → Upload key certificate.

Restore options:
  1. Copy your backup release-keystore.jks to ${ks_path}
  2. Or decode the same blob stored as GitHub secret ANDROID_KEYSTORE_BASE64:
       printf '%s' "\$ANDROID_KEYSTORE_BASE64" | base64 --decode > ${ks_path}
       # then ensure storePassword / keyPassword / keyAlias match that keystore
  3. Or export ANDROID_KEYSTORE_* and run:
       bash .github/scripts/setup_android_signing.sh
       # writes android/ci-release-keystore.jks + updates key.properties
EOF
    return 1
  fi

  echo "Using release keystore: ${ks_path}"
  return 0
}

# Download latest.json / appcast.xml for merge before overwrite. Prefer the public CDN URL
# (read-only R2 tokens often cannot s3 cp objects back down).
release_fetch_remote_feed_file() {
  local dest="$1"
  local public_url="$2"
  local s3_uri="${3:-}"

  if [[ -n "${public_url}" ]]; then
    if curl -fsS --connect-timeout 15 --max-time 120 "${public_url}" -o "${dest}" && [[ -s "${dest}" ]]; then
      echo "Using remote feed for merge (HTTPS): ${public_url}"
      return 0
    fi
    echo "WARN: could not fetch remote feed via HTTPS: ${public_url}" >&2
  fi

  if [[ -n "${s3_uri}" ]] && command -v aws >/dev/null 2>&1 \
      && [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    local -a s3_args=()
    if [[ -n "${AWS_ENDPOINT_URL_S3:-}" ]]; then
      s3_args=(--endpoint-url "${AWS_ENDPOINT_URL_S3}")
    fi
    if aws s3 cp ${s3_args[@]+"${s3_args[@]}"} "${s3_uri}" "${dest}" >/dev/null 2>&1 \
        && [[ -s "${dest}" ]]; then
      echo "Using remote feed for merge (S3): ${s3_uri}"
      return 0
    fi
    echo "WARN: could not fetch remote feed via S3: ${s3_uri}" >&2
  fi

  return 1
}

release_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

# True when App Store Connect API key id, issuer, and private key are all set.
release_asc_env_ready() {
  [[ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" &&
    -n "${APP_STORE_CONNECT_ISSUER_ID:-}" &&
    -n "${APP_STORE_CONNECT_API_PRIVATE_KEY:-}" ]]
}

# Canonical local ASC secrets directory (shared by local release + self-hosted CI).
release_asc_config_dir() {
  echo "${HOME}/.config/enjoy-player"
}

# Persist ASC identifiers (+ private key when available) under ~/.config/enjoy-player/.
# Safe to call from CI helpers; never writes into the git worktree.
release_cache_asc_credentials() {
  local cache_dir
  cache_dir="$(release_asc_config_dir)"
  if [[ -z "${APP_STORE_CONNECT_API_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
    echo "release_cache_asc_credentials: KEY_ID / ISSUER_ID required" >&2
    return 1
  fi
  mkdir -p "${cache_dir}"
  umask 077
  cat >"${cache_dir}/asc.env" <<EOF
APP_STORE_CONNECT_API_KEY_ID=${APP_STORE_CONNECT_API_KEY_ID}
APP_STORE_CONNECT_ISSUER_ID=${APP_STORE_CONNECT_ISSUER_ID}
EOF
  chmod 600 "${cache_dir}/asc.env"
  if [[ -n "${APP_STORE_CONNECT_API_PRIVATE_KEY:-}" ]]; then
    release_write_asc_api_private_key \
      "${cache_dir}/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
  fi
}

# Load App Store Connect API credentials for local TestFlight / notary.
# Precedence:
#   1. Already-exported env (CI secrets / shell)
#   2. ~/.config/enjoy-player/asc.env (KEY_ID + ISSUER_ID)
#   3. Optional APP_STORE_* lines in publish_env.local.sh (identifiers only)
#   4. Private key file:
#        APP_STORE_CONNECT_API_PRIVATE_KEY_PATH, else
#        ~/.config/enjoy-player/AuthKey_<KEY_ID>.p8 (preferred), else
#        ${root}/.apple/AuthKey_<KEY_ID>.p8 (legacy), else
#        ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
release_load_asc_env() {
  local root="$1"
  local cache_dir
  cache_dir="$(release_asc_config_dir)"
  local asc_cache="${cache_dir}/asc.env"
  local publish_env="${root}/.github/scripts/publish_env.local.sh"
  local key_path=""

  if [[ -z "${APP_STORE_CONNECT_API_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
    if [[ -f "${asc_cache}" ]]; then
      # shellcheck source=/dev/null
      source "${asc_cache}"
      echo "Loaded ASC identifiers from ${asc_cache}"
    fi
  fi

  # Only pull identifiers from publish_env when asc.env / shell did not set them.
  # Do not require AWS/R2 env for TestFlight.
  if [[ (-z "${APP_STORE_CONNECT_API_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}") && -f "${publish_env}" ]]; then
    # shellcheck source=/dev/null
    source "${publish_env}"
  fi

  if [[ -z "${APP_STORE_CONNECT_API_PRIVATE_KEY:-}" && -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ]]; then
    local resolved=""
    if resolved="$(release_resolve_asc_private_key "${root}" "${cache_dir}" "${APP_STORE_CONNECT_API_KEY_ID}")"; then
      # release_resolve_asc_private_key prints "<bucket>\t<path>".
      key_path="${resolved#*$'\t'}"
      if [[ -n "${key_path}" && -f "${key_path}" ]]; then
        APP_STORE_CONNECT_API_PRIVATE_KEY="$(cat "${key_path}")"
        export APP_STORE_CONNECT_API_PRIVATE_KEY
        echo "Loaded ASC API private key from ${key_path}"
      fi
    fi
  fi

  if release_asc_env_ready; then
    export APP_STORE_CONNECT_API_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_PRIVATE_KEY
  fi
}

# Resolve the App Store Connect API private key path with full precedence.
# Prints the first existing match and the source bucket (on stdout, NUL-separated
# when the caller asks for both via the second positional mode); returns 1 when
# no file is found. Buckets mirror release_load_asc_env so the preflight can
# report canonical / legacy / explicit-path / standard private_keys cases from
# the same source of truth.
#
# Usage:
#   release_resolve_asc_private_key <root> <cache_dir> <key_id>
#     -> prints "<bucket>\t<path>" on stdout when found; empty + rc=1 otherwise.
#
# Buckets:
#   explicit  — APP_STORE_CONNECT_API_PRIVATE_KEY_PATH override (if set + readable)
#   cache     — <cache_dir>/AuthKey_<KEY_ID>.p8  (preferred canonical location)
#   legacy    — <root>/.apple/AuthKey_<KEY_ID>.p8  (pre-~/.config/enjoy-player)
#   standard  — ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8  (Apple CLI default)
release_resolve_asc_private_key() {
  local root="$1"
  local cache_dir="$2"
  local key_id="$3"
  local candidate=""

  if [[ -z "${key_id}" ]]; then
    return 1
  fi

  if [[ -n "${APP_STORE_CONNECT_API_PRIVATE_KEY_PATH:-}" && -f "${APP_STORE_CONNECT_API_PRIVATE_KEY_PATH}" ]]; then
    printf 'explicit\t%s\n' "${APP_STORE_CONNECT_API_PRIVATE_KEY_PATH}"
    return 0
  fi

  candidate="${cache_dir}/AuthKey_${key_id}.p8"
  if [[ -f "${candidate}" ]]; then
    printf 'cache\t%s\n' "${candidate}"
    return 0
  fi

  candidate="${root}/.apple/AuthKey_${key_id}.p8"
  if [[ -f "${candidate}" ]]; then
    printf 'legacy\t%s\n' "${candidate}"
    return 0
  fi

  candidate="${HOME}/.appstoreconnect/private_keys/AuthKey_${key_id}.p8"
  if [[ -f "${candidate}" ]]; then
    printf 'standard\t%s\n' "${candidate}"
    return 0
  fi

  return 1
}

# Write App Store Connect API .p8 from APP_STORE_CONNECT_API_PRIVATE_KEY.
# GitHub secrets / JSON pastes often store literal "\n" instead of real newlines,
# which makes notarytool fail with invalidPEMDocument.
release_write_asc_api_private_key() {
  local dest="$1"
  local key="${APP_STORE_CONNECT_API_PRIVATE_KEY:-}"
  if [[ -z "${key}" ]]; then
    echo "APP_STORE_CONNECT_API_PRIVATE_KEY is empty" >&2
    return 1
  fi
  # Literal escaped newlines first, then normalize CR/LF.
  key="${key//\\r\\n/$'\n'}"
  key="${key//\\n/$'\n'}"
  key="${key//$'\r\n'/$'\n'}"
  key="${key//$'\r'/$'\n'}"
  if [[ "${key}" == \"*\" && "${key}" == *\" ]]; then
    key="${key:1:$((${#key} - 2))}"
  fi
  # Trim one leading/trailing newline run, then ensure a trailing newline.
  while [[ "${key}" == $'\n'* ]]; do key="${key#$'\n'}"; done
  while [[ "${key}" == *$'\n' ]]; do key="${key%$'\n'}"; done
  printf '%s\n' "${key}" >"${dest}"
  chmod 600 "${dest}"
  if ! grep -q 'BEGIN PRIVATE KEY' "${dest}"; then
    echo "ASC API private key is not a PEM (missing BEGIN PRIVATE KEY)." >&2
    return 1
  fi
}

# Upload an iOS IPA to TestFlight via altool using the already-loaded ASC env.
# Stages the .p8 under ${RUNNER_TEMP:-/tmp}, exports API_PRIVATE_KEYS_DIR for
# altool's discovery, runs `xcrun altool --upload-app`, and guarantees the
# temporary key is removed (trap-based) so a failed upload does not leak the
# credential on disk.
#
# Required env (call release_load_asc_env first):
#   APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_ISSUER_ID,
#   APP_STORE_CONNECT_API_PRIVATE_KEY.
#
# Args:
#   $1 IPA path (must exist; caller validates before invoking).
release_upload_testflight_ipa() {
  local ipa="$1"
  local key_path="${RUNNER_TEMP:-/tmp}/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"

  if [[ ! -f "${ipa}" ]]; then
    echo "release_upload_testflight_ipa: missing IPA: ${ipa}" >&2
    return 1
  fi
  if ! release_asc_env_ready; then
    echo "release_upload_testflight_ipa: ASC credentials not loaded." >&2
    return 1
  fi

  release_write_asc_api_private_key "${key_path}"
  # altool discovers AuthKey_<id>.p8 on its private-keys search path.
  export API_PRIVATE_KEYS_DIR="$(dirname "${key_path}")"

  # Ensure the temporary key is removed even if altool fails mid-upload.
  trap 'rm -f "${key_path}"' RETURN

  echo ">>> Upload IPA to TestFlight: ${ipa}"
  xcrun altool --upload-app --type ios --file "${ipa}" \
    --apiKey "${APP_STORE_CONNECT_API_KEY_ID}" \
    --apiIssuer "${APP_STORE_CONNECT_ISSUER_ID}"
}

# Stop stale Gradle daemons so the next bundle build picks up gradle.properties
# jvmargs (avoids OOM in packageStoreReleaseBundle after heavy flutter test runs).
release_stop_gradle_daemons() {
  local root="$1"
  local android_dir="${root}/android"
  if [[ -z "${JAVA_HOME:-}" ]] && ! command -v java >/dev/null 2>&1; then
    echo "WARNING: Skipping explicit Gradle daemon stop because JAVA_HOME and java are unavailable."
    return 0
  fi
  if [[ -x "${android_dir}/gradlew" ]]; then
    echo ">>> Stop Gradle daemons (fresh JVM for Android release build)"
    (cd "${android_dir}" && ./gradlew --stop) || true
  elif [[ -f "${android_dir}/gradlew.bat" ]]; then
    echo ">>> Stop Gradle daemons (fresh JVM for Android release build)"
    (cd "${android_dir}" && cmd.exe //c gradlew.bat --stop) || true
  fi
}

release_version() {
  bash "$(dirname "${BASH_SOURCE[0]}")/read_pubspec_version.sh"
}

release_windows_installer_path() {
  local root="$1"
  local version
  version="$(release_version)"
  echo "${root}/build/windows/installer/EnjoyPlayerSetup-v${version}.exe"
}

release_android_aab_path() {
  local root="$1"
  local version
  version="$(release_version)"
  echo "${root}/build/app/outputs/bundle/release/EnjoyPlayer-v${version}.aab"
}

release_android_apk_path() {
  local root="$1"
  local abi="$2"
  local version
  version="$(release_version)"
  echo "${root}/build/app/outputs/flutter-apk/EnjoyPlayer-v${version}-${abi}.apk"
}

release_macos_zip_path() {
  local root="$1"
  local version
  version="$(release_version)"
  echo "${root}/EnjoyPlayer-macOS-v${version}.zip"
}

release_linux_appimage_path() {
  local root="$1"
  local version
  version="$(release_version)"
  echo "${root}/build/linux/x64/release/enjoy-player-${version}-x86_64.AppImage"
}

# Populate publish argv with every versioned artifact that exists on disk.
release_collect_publish_artifact_args() {
  local root="$1"
  local out_name="$2"
  local -a out=()
  local f abi

  f="$(release_windows_installer_path "${root}")"
  if [[ -f "${f}" ]]; then
    out+=(--windows-installer "${f}")
  fi

  for abi in arm64-v8a armeabi-v7a x86_64; do
    f="$(release_android_apk_path "${root}" "${abi}")"
    if [[ -f "${f}" ]]; then
      out+=(--android-apk "android_${abi//-/_}" "${f}")
    fi
  done

  f="$(release_macos_zip_path "${root}")"
  if [[ -f "${f}" ]]; then
    out+=(--macos-zip "${f}")
  fi

  f="$(release_linux_appimage_path "${root}")"
  if [[ -f "${f}" ]]; then
    out+=(--linux-appimage "${f}")
  fi

  eval "${out_name}=(\"\${out[@]}\")"
}

release_build_number() {
  bash "$(dirname "${BASH_SOURCE[0]}")/read_pubspec_version.sh" --build
}

release_log_publish_only() {
  if [[ "${RELEASE_SKIP_BUILD}" == true && "${RELEASE_PUBLISH}" == true ]]; then
    echo ">>> Publish only (skipping build and checks; using existing artifacts)"
  fi
}

release_apply_sparkle_sign_output() {
  local output="$1"
  local sig=""
  if echo "${output}" | grep -q 'edSignature'; then
    sig="$(echo "${output}" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
    export SPARKLE_ED_SIGNATURE_MACOS="${sig}"
  elif echo "${output}" | grep -q 'dsaSignature'; then
    sig="$(echo "${output}" | sed -n 's/.*sparkle:dsaSignature="\([^"]*\)".*/\1/p')"
    export SPARKLE_ED_SIGNATURE_WINDOWS="${sig}"
  fi
}

release_load_publish_env() {
  local root="$1"
  local env_file="${root}/.github/scripts/publish_env.local.sh"
  if [[ -f "${env_file}" ]]; then
    # shellcheck source=/dev/null
    source "${env_file}"
    echo "Loaded publish env from ${env_file}"
  fi
}

# Parse shared release flags. Platform-specific flags remain in RELEASE_EXTRA_ARGS.
release_parse_common_args() {
  RELEASE_SKIP_CHECKS=false
  RELEASE_SKIP_BUILD=false
  RELEASE_PUBLISH=false
  RELEASE_FEEDS_ONLY=false
  RELEASE_EXTRA_ARGS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-checks)
        RELEASE_SKIP_CHECKS=true
        shift
        ;;
      --skip-build)
        RELEASE_SKIP_BUILD=true
        shift
        ;;
      --publish-only)
        RELEASE_SKIP_BUILD=true
        RELEASE_SKIP_CHECKS=true
        shift
        ;;
      --publish)
        RELEASE_PUBLISH=true
        shift
        ;;
      --feeds-only)
        RELEASE_FEEDS_ONLY=true
        RELEASE_PUBLISH=true
        shift
        ;;
      *)
        RELEASE_EXTRA_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

# Parse --windows-installer / --macos-zip / --android-apk into RELEASE_ARTIFACT_SPECS.
release_parse_artifact_args() {
  RELEASE_ARTIFACT_SPECS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --windows-installer)
        RELEASE_ARTIFACT_SPECS+=("windows|$2")
        shift 2
        ;;
      --macos-zip)
        RELEASE_ARTIFACT_SPECS+=("macos|$2")
        shift 2
        ;;
      --linux-appimage)
        RELEASE_ARTIFACT_SPECS+=("linux|$2")
        shift 2
        ;;
      --android-apk)
        RELEASE_ARTIFACT_SPECS+=("$2|$3")
        shift 3
        ;;
      *)
        echo "Unknown arg: $1" >&2
        return 1
        ;;
    esac
  done
}

# Reconstruct artifact argv (for forwarding to generate_update_feeds.sh).
release_artifact_argv() {
  local out_name="$1"
  local -a out=()
  local spec key path
  for spec in ${RELEASE_ARTIFACT_SPECS[@]+"${RELEASE_ARTIFACT_SPECS[@]}"}; do
    key="$(release_spec_key "${spec}")"
    path="$(release_spec_path "${spec}")"
    case "${key}" in
      windows)
        out+=(--windows-installer "${path}")
        ;;
      macos)
        out+=(--macos-zip "${path}")
        ;;
      linux)
        out+=(--linux-appimage "${path}")
        ;;
      *)
        out+=(--android-apk "${key}" "${path}")
        ;;
    esac
  done
  eval "${out_name}=(\"\${out[@]}\")"
}

# Stale pubspec.yaml under build/release/ (e.g. from local feed staging) breaks
# flutter analyze: path deps and assets resolve relative to that nested copy.
release_prune_stale_build_pubspecs() {
  local root="$1"
  if [[ -d "${root}/build/release" ]]; then
    find "${root}/build/release" -name pubspec.yaml -type f -delete 2>/dev/null || true
  fi
}

release_disk_free_mb() {
  local path="$1"
  local avail_kb
  avail_kb="$(df -k "${path}" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [[ -z "${avail_kb}" || ! "${avail_kb}" =~ ^[0-9]+$ ]]; then
    echo 0
    return
  fi
  echo $((avail_kb / 1024))
}

# Fail fast when the disk is too full for flutter test / xcodebuild temp files.
release_check_disk_space() {
  local root="$1"
  local min_mb="${2:-3072}"
  local free_mb
  free_mb="$(release_disk_free_mb "${root}")"
  if [[ "${free_mb}" -lt "${min_mb}" ]]; then
    echo "ERROR: Low disk space on $(df -h "${root}" | awk 'NR==2 {print $1}'): ${free_mb}MB free, need at least ${min_mb}MB." >&2
    echo "Pre-release checks and macOS builds need several GB of temp space." >&2
    echo "Safe cleanup in this repo (macOS-only release, when disk is below 4GB free):" >&2
    echo "  rm -rf build/ios build/test_cache   # or let the release script prune automatically" >&2
    echo "  flutter clean   # also removes build/macos; rebuilds on next release run" >&2
    echo "Then retry, or use --skip-checks only after freeing enough space for the build." >&2
    exit 1
  fi
}

# Reclaim space from artifacts not needed for a macOS-only release (only when disk is low).
release_prune_macos_only_build_artifacts() {
  local root="$1"
  local prune_below_mb="${2:-4096}"
  local free_mb
  free_mb="$(release_disk_free_mb "${root}")"
  if [[ "${free_mb}" -ge "${prune_below_mb}" ]]; then
    return 0
  fi

  local removed=0
  for dir in "${root}/build/ios" "${root}/build/test_cache"; do
    if [[ -d "${dir}" ]]; then
      rm -rf "${dir}"
      removed=1
    fi
  done
  if [[ "${removed}" -eq 1 ]]; then
    echo "Pruned iOS/test build artifacts (${free_mb}MB free, below ${prune_below_mb}MB threshold)."
  fi
}

release_app_has_developer_id_signature() {
  local app_path="$1"
  codesign -dvv "${app_path}" 2>&1 | grep -q 'Authority=Developer ID Application'
}

release_macos_app_is_notarized() {
  local app_path="$1"
  stapler validate "${app_path}" >/dev/null 2>&1
}

release_assert_macos_app_notarized() {
  local app_path="$1"
  if [[ ! -d "${app_path}" ]]; then
    echo "Missing macOS app bundle: ${app_path}" >&2
    exit 1
  fi
  if ! release_macos_app_is_notarized "${app_path}"; then
    echo "macOS app is not notarized and stapled: ${app_path}" >&2
    echo "Direct download requires --notarize before --publish." >&2
    exit 1
  fi
}

release_pack_macos_zip() {
  local root="$1"
  local app_path="$2"
  local version zip
  version="$(release_version)"
  zip="${root}/EnjoyPlayer-macOS-v${version}.zip"
  rm -f "${zip}"
  # Omit AppleDouble (._*) entries; they break embedded framework seals after unzip/Archive Utility.
  ditto -c -k --norsrc --keepParent "${app_path}" "${zip}"
  if unzip -l "${zip}" | grep -q '/\._'; then
    echo "macOS zip contains AppleDouble entries; codesign will break after extraction." >&2
    exit 1
  fi
  bash "${root}/.github/scripts/rename_release_artifacts.sh" apple
}

release_run_checks() {
  local root="$1"
  cd "${root}"
  release_prune_stale_build_pubspecs "${root}"
  flutter pub get
  flutter analyze
  flutter test
}

release_run_android_checks() {
  local root="$1"
  cd "${root}"
  release_prune_stale_build_pubspecs "${root}"
  flutter pub get
  bash tool/patch_agp9_pub_plugins.sh
  flutter analyze
  flutter test
}

release_pwsh() {
  if command -v pwsh >/dev/null 2>&1; then
    pwsh "$@"
  else
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$@"
  fi
}

release_print_artifacts() {
  local root="$1"
  local platform="$2"
  echo ""
  echo "=== Release artifacts (${platform}) ==="
  case "${platform}" in
    windows)
      compgen -G "${root}/build/windows/installer/EnjoyPlayerSetup-v"*.exe >/dev/null 2>&1 &&
        ls -1 "${root}/build/windows/installer/"EnjoyPlayerSetup-v*.exe || true
      ;;
    android)
      local aab apk abi
      aab="$(release_android_aab_path "${root}")"
      [[ -f "${aab}" ]] && echo "${aab}" || true
      for abi in arm64-v8a armeabi-v7a x86_64; do
        apk="$(release_android_apk_path "${root}" "${abi}")"
        [[ -f "${apk}" ]] && echo "${apk}" || true
      done
      ;;
    apple)
      compgen -G "${root}/build/ios/ipa/EnjoyPlayer-v"*.ipa >/dev/null 2>&1 &&
        ls -1 "${root}/build/ios/ipa/"EnjoyPlayer-v*.ipa || true
      compgen -G "${root}/EnjoyPlayer-macOS-v"*.zip >/dev/null 2>&1 &&
        ls -1 "${root}/"EnjoyPlayer-macOS-v*.zip || true
      ;;
    linux)
      local appimage
      appimage="$(release_linux_appimage_path "${root}")"
      [[ -f "${appimage}" ]] && echo "${appimage}" || true
      ;;
    all)
      local installer aab apk abi zip appimage
      installer="$(release_windows_installer_path "${root}")"
      [[ -f "${installer}" ]] && echo "${installer}" || true
      aab="$(release_android_aab_path "${root}")"
      [[ -f "${aab}" ]] && echo "${aab}" || true
      for abi in arm64-v8a armeabi-v7a x86_64; do
        apk="$(release_android_apk_path "${root}" "${abi}")"
        [[ -f "${apk}" ]] && echo "${apk}" || true
      done
      zip="$(release_macos_zip_path "${root}")"
      [[ -f "${zip}" ]] && echo "${zip}" || true
      appimage="$(release_linux_appimage_path "${root}")"
      [[ -f "${appimage}" ]] && echo "${appimage}" || true
      ;;
  esac
  local feed_dir="${root}/build/update-feeds"
  if [[ -f "${feed_dir}/latest.json" ]]; then
    echo "Local feeds: ${feed_dir}/latest.json"
    echo "             ${feed_dir}/appcast.xml"
  fi
}
