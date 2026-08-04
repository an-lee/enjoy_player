#!/usr/bin/env bash
# Windows direct-download release — same steps as release_windows.yml.
#
# Usage:
#   bash .github/scripts/release_windows.sh              # build + installer
#   bash .github/scripts/release_windows.sh --publish    # build + upload feeds
#   bash .github/scripts/release_windows.sh --feeds-only # build + local feeds only
#   bash .github/scripts/release_windows.sh --publish-only --publish
set -euo pipefail

lib="$(dirname "$0")/release_lib.sh"
# shellcheck source=release_lib.sh
source "${lib}"

root="$(release_repo_root)"
cd "${root}"

BUILD_INSTALLER=true

release_parse_common_args "$@"
for arg in ${RELEASE_EXTRA_ARGS[@]+"${RELEASE_EXTRA_ARGS[@]}"}; do
  case "${arg}" in
    --no-installer) BUILD_INSTALLER=false ;;
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

if [[ "${RELEASE_SKIP_CHECKS}" != true ]]; then
  echo ">>> Pre-release checks"
  release_run_checks "${root}"
  release_pwsh "${root}/.github/scripts/ensure_nuget_feed.ps1"
fi

if [[ "${RELEASE_SKIP_BUILD}" != true ]]; then
  echo ">>> Build Windows release (direct channel)"
  release_pwsh "${root}/windows/scripts/fetch_ffmpeg.ps1"
  flutter build windows --release --dart-define=DISTRIBUTION_CHANNEL=direct

  if [[ "${BUILD_INSTALLER}" == true ]]; then
    echo ">>> Build Inno Setup installer"
    bash "${root}/.github/scripts/sync_release_version.sh"
    release_pwsh "${root}/.github/scripts/ensure_inno_setup.ps1"
    iscc "${root}/windows/installer/enjoy_player.iss"
  fi
fi

if [[ "${RELEASE_PUBLISH}" == true ]]; then
  release_load_publish_env "${root}"
  installer="$(release_windows_installer_path "${root}")"
  if [[ ! -f "${installer}" ]]; then
    echo "No installer at ${installer} (expected pubspec version $(release_version))" >&2
    exit 1
  fi
  publish_args=(--windows-installer "${installer}")
  if [[ "${RELEASE_FEEDS_ONLY}" == true ]]; then
    publish_args=(--feeds-only "${publish_args[@]}")
  else
    export RELEASE_REQUIRE_S3=1
  fi
  echo ">>> Publish (${installer})"
  bash "${root}/.github/scripts/publish_player_release_to_s3.sh" "${publish_args[@]}"
fi

RELEASE_PUBLISH_GITHUB=false
for arg in ${RELEASE_EXTRA_ARGS[@]+"${RELEASE_EXTRA_ARGS[@]}"}; do
  case "${arg}" in
    --publish-github) RELEASE_PUBLISH_GITHUB=true ;;
  esac
done

if [[ "${RELEASE_PUBLISH_GITHUB}" == true ]]; then
  release_publish_github "${root}" windows
fi

release_print_artifacts "${root}" windows
echo "Done."
