#!/usr/bin/env bash
# Android release — same steps as release_android.yml (Play AAB + direct APKs).
#
# Usage:
#   bash .github/scripts/release_android.sh
#   bash .github/scripts/release_android.sh --play
#   bash .github/scripts/release_android.sh --publish
#   bash .github/scripts/release_android.sh --feeds-only --publish-only --publish
set -euo pipefail

lib="$(dirname "$0")/release_lib.sh"
# shellcheck source=release_lib.sh
source "${lib}"

root="$(release_repo_root)"
cd "${root}"

BUILD_APK=true
BUILD_AAB=true
UPLOAD_PLAY=false
RELEASE_PUBLISH_GITHUB=false

release_parse_common_args "$@"
for arg in ${RELEASE_EXTRA_ARGS[@]+"${RELEASE_EXTRA_ARGS[@]}"}; do
  case "${arg}" in
    --no-apk) BUILD_APK=false ;;
    --no-aab) BUILD_AAB=false ;;
    --play) UPLOAD_PLAY=true ;;
    --publish-github) RELEASE_PUBLISH_GITHUB=true ;;
    -h | --help)
      sed -n '2,9p' "$0"
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
  release_run_android_checks "${root}"
fi

if [[ "${RELEASE_SKIP_BUILD}" != true ]]; then
  if [[ -f "${root}/.github/scripts/setup_android_signing.sh" ]]; then
    if ! bash "${root}/.github/scripts/setup_android_signing.sh"; then
      if [[ -f "${root}/android/key.properties" ]]; then
        echo "setup_android_signing.sh skipped; validating existing android/key.properties."
      elif [[ -n "${GITHUB_ACTIONS:-}" || "${RELEASE_PUBLISH}" == true || "${UPLOAD_PLAY}" == true ]]; then
        echo "Android signing setup failed; CI/publish/--play requires a release keystore." >&2
        echo "Create android/key.properties from android/key.properties.example, or set" >&2
        echo "ANDROID_KEYSTORE_* env vars / ANDROID_USE_RUNNER_KEYSTORE=true." >&2
        exit 1
      else
        echo "WARNING: No release keystore; APK/AAB will be debug-signed." >&2
      fi
    fi
  fi
  if [[ "${UPLOAD_PLAY}" == true || -n "${GITHUB_ACTIONS:-}" || "${RELEASE_PUBLISH}" == true ]]; then
    release_require_android_upload_keystore "${root}" || exit 1
  elif [[ -f "${root}/android/key.properties" ]]; then
    # key.properties present but incomplete → fail early instead of Gradle's opaque error.
    release_require_android_upload_keystore "${root}" || exit 1
  fi

  echo ">>> Prune stale Android JNI merge cache (flutter/flutter#187553)"
  bash "${root}/tool/prune_android_jni_merge_cache.sh"

  # Always patch pub-cache plugins for AGP 9 (also covers --skip-checks and
  # Windows hosts where ~/.pub-cache is not the Flutter cache).
  echo ">>> Apply AGP 9 pub plugin patches"
  bash "${root}/tool/patch_agp9_pub_plugins.sh"
  # Drop stale share_plus outputs from pre-patch builds (empty UP-TO-DATE Kotlin).
  rm -rf "${root}/build/share_plus"

  # media_kit_libs_android_video downloads ~23MB of GitHub Release JARs during
  # Gradle configuration via Java URL.openStream() (no retries). Prefetch with
  # curl so flaky networks do not leave 0-byte jars / "Connection timed out".
  echo ">>> Prefetch media_kit Android native libs"
  bash "${root}/tool/prefetch_media_kit_android_libs.sh"

  # package:sqlite3 3.x downloads libsqlite3.so from github.com via the
  # dart_build hook (Dart HttpClient, no retries). Self-hosted Android
  # runners intermittently time out that connection, which fails
  # bundleStoreRelease with "Target dart_build failed". Prefetch the four
  # Android ABIs into the dart_build shared cache so the hook reuses them.
  echo ">>> Prefetch sqlite3 Android native libs"
  bash "${root}/tool/prefetch_sqlite3_libs.sh"

  release_stop_gradle_daemons "${root}"

  if [[ "${BUILD_AAB}" == true ]]; then
    echo ">>> Build App Bundle (store / Play)"
    flutter build appbundle --release --flavor store
  fi

  if [[ "${BUILD_APK}" == true ]]; then
    echo ">>> Build sideload APKs (direct / per ABI)"
    flutter build apk --release --split-per-abi --flavor direct \
      --dart-define=DISTRIBUTION_CHANNEL=direct
  fi

  bash "${root}/.github/scripts/rename_release_artifacts.sh" android

  if [[ "${BUILD_AAB}" == true ]]; then
    aab="$(release_android_aab_path "${root}")"
    if [[ ! -f "${aab}" ]]; then
      echo "Expected Play AAB not found at ${aab} after rename." >&2
      echo "Check build/app/outputs/bundle/release/ for app-release.aab." >&2
      exit 1
    fi
  fi

  if [[ "${BUILD_APK}" == true ]]; then
    arm64_apk="$(release_android_apk_path "${root}" "arm64-v8a")"
    if [[ ! -f "${arm64_apk}" ]]; then
      echo "Expected sideload APK not found at ${arm64_apk} after rename." >&2
      echo "Check build/app/outputs/flutter-apk/ for app-*-direct-release.apk outputs." >&2
      exit 1
    fi
  fi
fi

if [[ "${UPLOAD_PLAY}" == true ]]; then
  # Load publish_env.local.sh so GOOGLE_PLAY_* can live next to S3 credentials.
  release_load_publish_env "${root}"
  aab="$(release_android_aab_path "${root}")"
  if [[ ! -f "${aab}" ]]; then
    echo "Play upload requested but AAB not found at ${aab}." >&2
    echo "Build with --play (without --no-aab), or pass an existing AAB via --publish-only --play." >&2
    echo "Skipping Play upload; continuing with sideload feed publish + GitHub Release upload." >&2
  else
    echo ">>> Upload Play AAB (alpha / draft)"
    if ! bash "${root}/.github/scripts/upload_play_aab.sh" "${aab}"; then
      # Play upload failures (e.g. version code already on the track) must not
      # block the rest of the release. The sideload APKs are independent of
      # Play, and the GitHub Release draft still needs the AAB + APKs.
      echo "!!! Play upload failed (see error above); continuing with the rest of the release." >&2
    fi
  fi
fi

if [[ "${RELEASE_PUBLISH}" == true ]]; then
  release_load_publish_env "${root}"
  apk_dir="${root}/build/app/outputs/flutter-apk"
  publish_args=()
  for abi in arm64-v8a armeabi-v7a x86_64; do
    f="$(release_android_apk_path "${root}" "${abi}")"
    if [[ -f "${f}" ]]; then
      publish_args+=(--android-apk "android_${abi//-/_}" "${f}")
    fi
  done
  if [[ ${#publish_args[@]} -eq 0 ]]; then
    echo "No sideload APKs to publish in ${apk_dir}" >&2
    exit 1
  fi
  if [[ "${RELEASE_FEEDS_ONLY}" == true ]]; then
    publish_args=(--feeds-only "${publish_args[@]}")
  else
    export RELEASE_REQUIRE_S3=1
  fi
  echo ">>> Publish Android sideload APKs"
  bash "${root}/.github/scripts/publish_player_release_to_s3.sh" "${publish_args[@]}"
fi

if [[ "${RELEASE_PUBLISH_GITHUB}" == true ]]; then
  release_publish_github "${root}" android
fi

release_print_artifacts "${root}" android
echo "Done."
