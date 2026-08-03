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
