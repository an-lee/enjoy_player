#!/usr/bin/env bash
# Publish all versioned release artifacts present on disk (any platform).
#
# Usage:
#   bash .github/scripts/release_publish.sh --publish-only --publish
#   bash .github/scripts/release.sh --platform all --publish-only --publish
set -euo pipefail

lib="$(dirname "$0")/release_lib.sh"
# shellcheck source=release_lib.sh
source "${lib}"

root="$(release_repo_root)"
cd "${root}"

release_parse_common_args "$@"

release_log_publish_only

RELEASE_PUBLISH_GITHUB=false
for arg in ${RELEASE_EXTRA_ARGS[@]+"${RELEASE_EXTRA_ARGS[@]}"}; do
  case "${arg}" in
    --publish-github) RELEASE_PUBLISH_GITHUB=true ;;
  esac
done

if [[ "${RELEASE_PUBLISH}" != true && "${RELEASE_PUBLISH_GITHUB}" != true ]]; then
  echo "Missing --publish (or --feeds-only), or --publish-github." >&2
  exit 1
fi

release_load_publish_env "${root}"

publish_args=()
release_collect_publish_artifact_args "${root}" publish_args

if [[ ${#publish_args[@]} -eq 0 && "${RELEASE_PUBLISH_GITHUB}" != true ]]; then
  echo "No release artifacts found for version $(release_version)." >&2
  echo "Expected paths such as:" >&2
  echo "  $(release_windows_installer_path "${root}")" >&2
  echo "  $(release_android_apk_path "${root}" "arm64-v8a")" >&2
  echo "  $(release_macos_zip_path "${root}")" >&2
  exit 1
fi

if [[ "${RELEASE_FEEDS_ONLY}" == true ]]; then
  publish_args=(--feeds-only ${publish_args[@]+"${publish_args[@]}"})
else
  export RELEASE_REQUIRE_S3=1
fi

echo ">>> Publish all available artifacts"
if [[ "${RELEASE_PUBLISH}" == true ]]; then
  bash "${root}/.github/scripts/publish_player_release_to_s3.sh" ${publish_args[@]+"${publish_args[@]}"}
fi

if [[ "${RELEASE_PUBLISH_GITHUB}" == true ]]; then
  release_publish_github "${root}" all
fi

release_print_artifacts "${root}" all
echo "Done."
