#!/usr/bin/env bash
# Prefetch media_kit_libs_android_video native JARs with curl (retries + MD5).
#
# The upstream plugin downloads these from GitHub Releases during Gradle
# *configuration* via Java URL.openStream() (no retries). On flaky networks
# that leaves a 0-byte jar and fails the next build with "Connection timed out".
#
# Dest matches Flutter's plugin buildDir:
#   build/media_kit_libs_android_video/v1.1.7/
#
# Pin matches media_kit_libs_android_video 1.3.8 (pubspec.lock). Bump URLs/MD5s
# when upgrading that package.
#
# Usage:
#   bash tool/prefetch_media_kit_android_libs.sh
#   MEDIA_KIT_ANDROID_LIBS_BASE_URL=https://mirror.example/… bash tool/…
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="v1.1.7"
base_url="${MEDIA_KIT_ANDROID_LIBS_BASE_URL:-https://github.com/media-kit/libmpv-android-video-build/releases/download/${version}}"
dest_dir="${root}/build/media_kit_libs_android_video/${version}"

# name|md5
files=(
  "default-arm64-v8a.jar|83df25b61193af8fa815e373143ac9af"
  "default-armeabi-v7a.jar|22e21526fefc0a2b8f17adbec9f57590"
  "default-x86_64.jar|6fa26bf0459b11f1c0b0dbc29e5b940d"
  "default-x86.jar|0d742b756dc9d1fcd84ea271d8b68f32"
)

file_md5() {
  local path="$1"
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "${path}" | awk '{print $1}'
  elif command -v md5 >/dev/null 2>&1; then
    md5 -q "${path}"
  else
    echo "Need md5sum or md5 on PATH." >&2
    exit 1
  fi
}

mkdir -p "${dest_dir}"

needed=0
for entry in "${files[@]}"; do
  name="${entry%%|*}"
  expected="${entry##*|}"
  path="${dest_dir}/${name}"
  if [[ -f "${path}" && -s "${path}" ]]; then
    actual="$(file_md5 "${path}")"
    if [[ "${actual}" == "${expected}" ]]; then
      echo "OK  ${name}"
      continue
    fi
    echo "MD5 mismatch for ${name} (got ${actual}); re-downloading."
    rm -f "${path}"
  else
    # Drop empty / partial leftovers from timed-out Java downloads.
    rm -f "${path}"
  fi

  url="${base_url}/${name}"
  echo "Downloading ${url}"
  tmp="${path}.partial"
  rm -f "${tmp}"
  curl -fL \
    --retry 5 \
    --retry-delay 2 \
    --retry-all-errors \
    --connect-timeout 30 \
    --max-time 600 \
    -o "${tmp}" \
    "${url}"
  actual="$(file_md5 "${tmp}")"
  if [[ "${actual}" != "${expected}" ]]; then
    rm -f "${tmp}"
    echo "MD5 verification failed for ${name}" >&2
    echo "  expected: ${expected}" >&2
    echo "  actual:   ${actual}" >&2
    exit 1
  fi
  mv "${tmp}" "${path}"
  echo "OK  ${name}"
  needed=$((needed + 1))
done

if [[ "${needed}" -eq 0 ]]; then
  echo "media_kit Android libs already cached under ${dest_dir}"
else
  echo "Prefetched ${needed} media_kit Android lib jar(s) into ${dest_dir}"
fi
