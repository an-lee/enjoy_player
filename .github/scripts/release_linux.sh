#!/usr/bin/env bash
# Linux AppImage release — same steps as release_linux.yml.
#
# Usage:
#   bash .github/scripts/release_linux.sh                       # build AppImage
#   bash .github/scripts/release_linux.sh --publish             # build + upload feeds
#   bash .github/scripts/release_linux.sh --feeds-only          # build + local feeds only
#   bash .github/scripts/release_linux.sh --publish-only --publish
set -euo pipefail

lib="$(dirname "$0")/release_lib.sh"
# shellcheck source=release_lib.sh
source "${lib}"

root="$(release_repo_root)"
cd "${root}"

RELEASE_PUBLISH_GITHUB=false

release_parse_common_args "$@"
for arg in ${RELEASE_EXTRA_ARGS[@]+"${RELEASE_EXTRA_ARGS[@]}"}; do
  case "${arg}" in
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

if [[ "${RELEASE_SKIP_CHECKS}" != true ]]; then
  echo ">>> Pre-release checks"
  release_run_checks "${root}"
fi

if [[ "${RELEASE_SKIP_BUILD}" != true ]]; then
  echo ">>> Build Linux release (direct channel)"
  flutter build linux --release --dart-define=DISTRIBUTION_CHANNEL=direct

  version="$(release_version)"
  echo ">>> Package version: ${version}"

  echo ">>> Build AppImage"
  bash "${root}/linux/packaging/make_appimage.sh" \
    --version "${version}" \
    --bundle "${root}/build/linux/x64/release/bundle" \
    --output "${root}/build/linux/x64/release"
fi

if [[ "${RELEASE_PUBLISH}" == true ]]; then
  release_load_publish_env "${root}"
  appimage="$(release_linux_appimage_path "${root}")"
  if [[ ! -f "${appimage}" ]]; then
    echo "No AppImage at ${appimage} (expected pubspec version $(release_version))" >&2
    exit 1
  fi
  publish_args=(--linux-appimage "${appimage}")
  if [[ "${RELEASE_FEEDS_ONLY}" == true ]]; then
    publish_args=(--feeds-only "${publish_args[@]}")
  else
    export RELEASE_REQUIRE_S3=1
  fi
  echo ">>> Publish (${appimage})"
  bash "${root}/.github/scripts/publish_player_release_to_s3.sh" "${publish_args[@]}"
fi

if [[ "${RELEASE_PUBLISH_GITHUB}" == true ]]; then
  release_publish_github "${root}" linux
fi

release_print_artifacts "${root}" linux
echo "Done."
