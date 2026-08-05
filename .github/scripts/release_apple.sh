#!/usr/bin/env bash
# Apple (iOS + macOS) release — same steps as release_apple.yml.
# macOS only.
#
# Usage:
#   bash .github/scripts/release_apple.sh --macos-only --notarize
#   bash .github/scripts/release_apple.sh --notarize --testflight --publish
set -euo pipefail

lib="$(dirname "$0")/release_lib.sh"
# shellcheck source=release_lib.sh
source "${lib}"

root="$(release_repo_root)"
cd "${root}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "release_apple.sh requires macOS." >&2
  exit 1
fi

NOTARIZE=false
UPLOAD_TESTFLIGHT=false
MACOS_ONLY=false
RELEASE_PUBLISH_GITHUB=false
MACOS_APP_PATH="${MACOS_APP_PATH:-build/macos/Build/Products/Release/Enjoy Player.app}"

release_parse_common_args "$@"
for arg in ${RELEASE_EXTRA_ARGS[@]+"${RELEASE_EXTRA_ARGS[@]}"}; do
  case "${arg}" in
    --notarize) NOTARIZE=true ;;
    --testflight) UPLOAD_TESTFLIGHT=true ;;
    --macos-only) MACOS_ONLY=true ;;
    --publish-github) RELEASE_PUBLISH_GITHUB=true ;;
    -h | --help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: ${arg}" >&2
      exit 1
      ;;
  esac
done

release_log_publish_only

if [[ "${RELEASE_PUBLISH}" == true && "${NOTARIZE}" != true ]]; then
  echo ">>> macOS direct download requires notarization; enabling --notarize (--publish)"
  NOTARIZE=true
fi

if [[ "${RELEASE_SKIP_BUILD}" == true ]]; then
  release_check_disk_space "${root}" 512
elif [[ "${MACOS_ONLY}" == true ]]; then
  release_prune_macos_only_build_artifacts "${root}" 4096
  release_check_disk_space "${root}" 2048
else
  release_check_disk_space "${root}" 4096
fi

if [[ "${RELEASE_SKIP_CHECKS}" != true ]]; then
  echo ">>> Pre-release checks"
  release_run_checks "${root}"
fi

if [[ "${RELEASE_SKIP_BUILD}" != true ]]; then
  bash "${root}/.github/scripts/setup_apple_signing.sh" || true

  # Bootstrap Apple Distribution before notary login so a bad notary profile
  # does not block iOS signing recovery on self-hosted runners.
  if [[ "${MACOS_ONLY}" != true ]]; then
    dist_id="$(
      security find-identity -v -p codesigning 2>/dev/null \
        | awk -F'"' '/Apple Distribution/ { print $2; exit }'
    )"
    if [[ -z "${dist_id}" ]]; then
      echo "Apple Distribution certificate missing — attempting App Store Connect API create/import"
      if ! bash "${root}/.github/scripts/ensure_ios_distribution_identity.sh"; then
        echo "Apple Distribution certificate missing in keychain — iOS IPA / TestFlight will fail." >&2
        echo "Install via Xcode (Signing & Capabilities), import a .p12, or ensure ASC API secrets can create one." >&2
        exit 1
      fi
    fi
  fi

  if [[ "${NOTARIZE}" == true ]]; then
    # Fail loudly when ASC secrets are present but unusable (e.g. invalidPEMDocument).
    bash "${root}/.github/scripts/setup_notary_credentials.sh"
  fi

  echo ">>> Homebrew + CocoaPods"
  brew bundle install --file="${root}/macos/Brewfile"
  (cd "${root}/macos" && pod install)

  if [[ "${MACOS_ONLY}" != true ]]; then
    (cd "${root}/ios" && pod install)

    echo ">>> Build iOS IPA"
    flutter build ipa --release --export-options-plist=ios/ExportOptions.export.plist

    if [[ "${UPLOAD_TESTFLIGHT}" == true ]]; then
      if [[ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" && -n "${APP_STORE_CONNECT_API_PRIVATE_KEY:-}" ]]; then
        KEY_PATH="${RUNNER_TEMP:-/tmp}/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
        release_write_asc_api_private_key "${KEY_PATH}"
        # altool discovers AuthKey_<id>.p8 on its private-keys search path.
        export API_PRIVATE_KEYS_DIR="$(dirname "${KEY_PATH}")"
        IPA="$(ls -1 "${root}/build/ios/ipa/"*.ipa | head -1)"
        xcrun altool --upload-app --type ios --file "${IPA}" \
          --apiKey "${APP_STORE_CONNECT_API_KEY_ID}" \
          --apiIssuer "${APP_STORE_CONNECT_ISSUER_ID}"
        rm -f "${KEY_PATH}"
      else
        echo "Skipping TestFlight: App Store Connect API env not set."
      fi
    fi
  elif [[ "${UPLOAD_TESTFLIGHT}" == true ]]; then
    echo "Skipping TestFlight: --macos-only was set." >&2
  fi

  echo ">>> Build macOS release (direct channel)"
  bash "${root}/.github/scripts/build_macos_release.sh"

  chmod +x "${root}/macos/scripts/notarize_release.sh"
  if [[ "${NOTARIZE}" == true ]]; then
    echo ">>> Notarize macOS app"
    "${root}/macos/scripts/notarize_release.sh" "${MACOS_APP_PATH}"
  else
    echo ">>> Sign macOS app (Developer ID; skip notarization)"
    "${root}/macos/scripts/notarize_release.sh" "${MACOS_APP_PATH}" --sign-only
  fi

  release_pack_macos_zip "${root}" "${MACOS_APP_PATH}"
elif [[ "${NOTARIZE}" == true || "${RELEASE_PUBLISH}" == true ]]; then
  if [[ ! -d "${MACOS_APP_PATH}" ]]; then
    echo "Missing macOS app bundle: ${MACOS_APP_PATH}" >&2
    echo "Run a full build first, or set MACOS_APP_PATH." >&2
    exit 1
  fi

  if [[ "${NOTARIZE}" == true ]]; then
    bash "${root}/.github/scripts/setup_notary_credentials.sh"
    if release_macos_app_is_notarized "${MACOS_APP_PATH}"; then
      echo ">>> macOS app already notarized and stapled"
    else
      echo ">>> Notarize macOS app (existing build)"
      chmod +x "${root}/macos/scripts/notarize_release.sh"
      notarize_args=()
      if release_app_has_developer_id_signature "${MACOS_APP_PATH}"; then
        notarize_args+=(--skip-sign)
      fi
      "${root}/macos/scripts/notarize_release.sh" "${MACOS_APP_PATH}" ${notarize_args[@]+"${notarize_args[@]}"}
    fi
  fi

  if [[ "${RELEASE_PUBLISH}" == true ]]; then
    release_assert_macos_app_notarized "${MACOS_APP_PATH}"
    echo ">>> Repack macOS zip from notarized app"
    release_pack_macos_zip "${root}" "${MACOS_APP_PATH}"
  elif [[ "${NOTARIZE}" == true ]]; then
    release_pack_macos_zip "${root}" "${MACOS_APP_PATH}"
  fi
fi

if [[ "${RELEASE_PUBLISH}" == true ]]; then
  release_load_publish_env "${root}"
  zip="$(release_macos_zip_path "${root}")"
  if [[ ! -f "${zip}" ]]; then
    echo "Missing macOS zip: ${zip}" >&2
    exit 1
  fi
  release_assert_macos_app_notarized "${MACOS_APP_PATH}"
  publish_args=(--macos-zip "${zip}")
  if [[ "${RELEASE_FEEDS_ONLY}" == true ]]; then
    publish_args=(--feeds-only "${publish_args[@]}")
  else
    export RELEASE_REQUIRE_S3=1
  fi
  echo ">>> Publish macOS zip"
  bash "${root}/.github/scripts/publish_player_release_to_s3.sh" "${publish_args[@]}"
fi

if [[ "${RELEASE_PUBLISH_GITHUB}" == true ]]; then
  release_publish_github "${root}" apple
fi

release_print_artifacts "${root}" apple
release_hint_publish "${root}"
echo "Done."
