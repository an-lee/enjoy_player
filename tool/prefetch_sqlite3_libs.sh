#!/usr/bin/env bash
# Pre-fetch package:sqlite3 Android native libraries into the dart_build hook
# shared cache, so the build hook reuses them instead of downloading from
# github.com at every build.
#
# Why:
#   package:sqlite3 3.x uses a Dart hooks build hook that downloads its
#   precompiled libsqlite3.so for each Android ABI from
#   github.com/simolus3/sqlite3.dart/releases at every `flutter build`. The
#   download uses Dart HttpClient with no retries and a single SYN — any
#   transient network blip (or GitHub rate-limiting after a busy step) makes
#   the connection time out and the entire `bundleStoreRelease` task fails
#   with "Target dart_build failed: Error: Building native assets failed."
#
#   Self-hosted runners in particular see this intermittently. The Linux
#   `flutter build linux` step is unaffected because it doesn't build native
#   assets, but the Android `flutter build appbundle` step does (it bundles
#   the SQLite library into the AAB).
#
# What:
#   The hook writes/downloads to
#     .dart_tool/hooks_runner/shared/sqlite3/build/download-<hash8>/libsqlite3.so
#   where <hash8> is the first 8 hex chars of the lib's expected SHA256 (one
#   cache dir per ABI). On the next invocation the hook reuses a file there
#   when its SHA256 matches the pinned value, and skips the GitHub fetch.
#
#   This script pre-populates all four Android ABIs (arm, arm64, ia32, x64)
#   under that path before the build runs. SHA256 is verified against the
#   values embedded in package:sqlite3/lib/src/hook/asset_hashes.dart so a
#   tampered or partial download fails the build fast instead of poisoning
#   the cache.
#
# Usage:
#   bash tool/prefetch_sqlite3_libs.sh
#   SQLITE3_BASE_URL=https://mirror.example/sqlite3-3.5.0 \
#     bash tool/prefetch_sqlite3_libs.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cache_dir="${root}/.dart_tool/hooks_runner/shared/sqlite3/build"
mkdir -p "${cache_dir}"

base_url="${SQLITE3_BASE_URL:-https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.0}"

# name|libhash8|full_sha256 — sourced from package:sqlite3 3.5.0
# lib/src/hook/asset_hashes.dart. Keep these pinned; a bump to sqlite3 must
# bump this list and bump pubspec.yaml's sqlite3 constraint in lockstep.
files=(
  "libsqlite3.arm.android.so|6c1b8dff|6c1b8dffc1ddefaf02e771711491410bc3ab1db858d3d23d2925e0b2cd691b93"
  "libsqlite3.arm64.android.so|e99515af|e99515af1d7119fb61843ae5e597344e7f258563de3a7e5a3869f627aab2887b"
  "libsqlite3.ia32.android.so|6d73649a|6d73649ad5896eb276aca304456b8664c0f9a82d6c7785c5975d43e0462d3777"
  "libsqlite3.x64.android.so|e5a2d46a|e5a2d46ac5e11f471e1aaedfd364f54c7961a6900432d289ea3f5781bcaaf4cd"
)

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "Need sha256sum or shasum on PATH." >&2
    exit 1
  fi
}

needed=0
for entry in "${files[@]}"; do
  IFS='|' read -r name libhash8 full_sha <<< "${entry}"
  dest_dir="${cache_dir}/download-${libhash8}"
  dest="${dest_dir}/libsqlite3.so"
  mkdir -p "${dest_dir}"

  if [[ -f "${dest}" ]] && [[ "$(sha256_of "${dest}")" == "${full_sha}" ]]; then
    echo "OK  ${name} (cached, sha256 verified)"
    continue
  fi

  # Drop empty / partial leftovers from a previously timed-out hook run so
  # the curl below doesn't trip "curl: (23) Failed writing body".
  rm -f "${dest}" "${dest}.partial"

  url="${base_url}/${name}"
  echo "Downloading ${url}"
  tmp="${dest}.partial"
  curl -fL \
    --retry 5 \
    --retry-delay 2 \
    --retry-all-errors \
    --connect-timeout 30 \
    --max-time 600 \
    -o "${tmp}" \
    "${url}"
  actual="$(sha256_of "${tmp}")"
  if [[ "${actual}" != "${full_sha}" ]]; then
    rm -f "${tmp}"
    echo "SHA256 verification failed for ${name}" >&2
    echo "  expected: ${full_sha}" >&2
    echo "  actual:   ${actual}" >&2
    exit 1
  fi
  mv "${tmp}" "${dest}"
  echo "OK  ${name}"
  needed=$((needed + 1))
done

if [[ "${needed}" -eq 0 ]]; then
  echo "sqlite3 Android libs already cached under ${cache_dir}"
else
  echo "Prefetched ${needed} sqlite3 Android lib(s) into ${cache_dir}"
fi