#!/usr/bin/env bash
# Patches pub-cache Android Gradle files for AGP 9 built-in Kotlin compatibility.
# Run after `flutter pub get` when Android builds warn or fail on older plugins.
set -euo pipefail

# Flutter on Windows uses %LOCALAPPDATA%/Pub/Cache; Unix uses ~/.pub-cache.
if [[ -n "${PUB_CACHE:-}" ]]; then
  _pub_cache_root="${PUB_CACHE}"
elif [[ -d "${HOME}/.pub-cache" ]]; then
  _pub_cache_root="${HOME}/.pub-cache"
elif [[ -n "${LOCALAPPDATA:-}" && -d "${LOCALAPPDATA}/Pub/Cache" ]]; then
  _pub_cache_root="${LOCALAPPDATA}/Pub/Cache"
else
  _pub_cache_root="${HOME}/.pub-cache"
fi
PUB_CACHE="${_pub_cache_root}/hosted/pub.dev"
unset _pub_cache_root
if [[ ! -d "${PUB_CACHE}" ]]; then
  echo "Pub cache not found at ${PUB_CACHE}" >&2
  exit 1
fi

patch_builtin_kotlin_groovy() {
  local file="$1"
  [[ -f "${file}" ]] || return 0
  if ! grep -qE 'kotlin-android|org\.jetbrains\.kotlin\.android' "${file}"; then
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  sed -E \
    -e '/^[[:space:]]*apply plugin:[[:space:]]*['\''"]kotlin-android['\''"][[:space:]]*$/d' \
    -e '/^[[:space:]]*classpath[[:space:]]+['\''"]org\.jetbrains\.kotlin:kotlin-gradle-plugin/d' \
    -e '/^[[:space:]]*implementation[[:space:]]+['\''"]org\.jetbrains\.kotlin:kotlin-stdlib/d' \
    -e '/^[[:space:]]*ext\.kotlin_version[[:space:]]*=/d' \
    "${file}" >"${tmp}"

  awk '
    /kotlinOptions[[:space:]]*\{/ { skip=1; next }
    skip && /\}/ { skip=0; next }
    !skip { print }
  ' "${tmp}" >"${file}"
  rm -f "${tmp}"

  echo "Patched built-in Kotlin: ${file}"
}

patch_builtin_kotlin_kts() {
  local file="$1"
  [[ -f "${file}" ]] || return 0
  if ! grep -qE 'kotlin-android|org\.jetbrains\.kotlin\.android' "${file}"; then
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  sed -E \
    -e '/^[[:space:]]*id\("kotlin-android"\)[[:space:]]*$/d' \
    -e '/^[[:space:]]*classpath\("org\.jetbrains\.kotlin:kotlin-gradle-plugin/d' \
    "${file}" >"${tmp}"
  if ! cmp -s "${file}" "${tmp}"; then
    mv "${tmp}" "${file}"
    echo "Patched built-in Kotlin: ${file}"
  else
    rm -f "${tmp}"
  fi
}

INAPP="${PUB_CACHE}/flutter_inappwebview_android-1.1.3/android/build.gradle"
if [[ -f "${INAPP}" ]]; then
  if grep -q "proguard-android.txt" "${INAPP}"; then
    sed -i 's/proguard-android\.txt/proguard-android-optimize.txt/g' "${INAPP}"
    echo "Patched ${INAPP} (proguard-android-optimize.txt)"
  fi
fi

for dir in "${PUB_CACHE}"/package_info_plus-*; do
  [[ -d "${dir}" ]] || continue
  patch_builtin_kotlin_groovy "${dir}/android/build.gradle"
done

for dir in "${PUB_CACHE}"/wakelock_plus-*; do
  [[ -d "${dir}" ]] || continue
  patch_builtin_kotlin_groovy "${dir}/android/build.gradle"
done

for dir in "${PUB_CACHE}"/url_launcher_android-*; do
  [[ -d "${dir}" ]] || continue
  patch_builtin_kotlin_kts "${dir}/android/build.gradle.kts"
done

# share_plus 13.2+ skips applying KGP when AGP >= 9, assuming built-in Kotlin.
# This app keeps android.builtInKotlin=false, so Kotlin sources never compile and
# GeneratedPluginRegistrant fails with "cannot find symbol SharePlusPlugin".
for dir in "${PUB_CACHE}"/share_plus-*; do
  [[ -d "${dir}" ]] || continue
  file="${dir}/android/build.gradle.kts"
  [[ -f "${file}" ]] || continue
  if ! grep -qE 'agpMajor[[:space:]]*<[[:space:]]*9' "${file}"; then
    continue
  fi
  tmp="$(mktemp)"
  perl -0pe 's/if\s*\(\s*agpMajor\s*<\s*9\s*\)\s*\{\s*apply\(plugin\s*=\s*"org\.jetbrains\.kotlin\.android"\)\s*\}/apply(plugin = "org.jetbrains.kotlin.android")/s' \
    "${file}" >"${tmp}"
  if ! cmp -s "${file}" "${tmp}"; then
    mv "${tmp}" "${file}"
    echo "Patched share_plus AGP9/KGP: ${file}"
    share_plus_patched=1
  else
    rm -f "${tmp}"
  fi
done

# Invalidate stale share_plus outputs from builds that ran before the KGP patch
# (Gradle can mark compileReleaseKotlin UP-TO-DATE with empty class output).
if [[ "${share_plus_patched:-0}" == "1" ]]; then
  root="$(cd "$(dirname "$0")/.." && pwd)"
  if [[ -d "${root}/build/share_plus" ]]; then
    rm -rf "${root}/build/share_plus"
    echo "Cleared stale ${root}/build/share_plus"
  fi
fi

# jni 1.0.1 added an unconditional `kotlin { compilerOptions { jvmTarget = ... } }`
# block to android/build.gradle. On AGP 9 the Kotlin Gradle plugin is built in,
# but this app keeps android.builtInKotlin=false so KGP is not auto-applied,
# and the `kotlin {}` DSL throws "Could not find method kotlin()". jni has no
# Kotlin sources on Android, so the block is dead config — strip it. jni 1.0.1
# was also retracted on pub shortly after release, so this becomes a no-op when
# a fixed version ships.
for dir in "${PUB_CACHE}"/jni-*; do
  [[ -d "${dir}" ]] || continue
  file="${dir}/android/build.gradle"
  [[ -f "${file}" ]] || continue
  if ! grep -qE '^kotlin[[:space:]]*\{' "${file}"; then
    continue
  fi
  tmp="$(mktemp)"
  awk '
    BEGIN { skip = 0 }
    /^kotlin[[:space:]]*\{/ { skip = 1; next }
    skip && /^\}/ { skip = 0; next }
    !skip { print }
  ' "${file}" >"${tmp}"
  if ! cmp -s "${file}" "${tmp}"; then
    mv "${tmp}" "${file}"
    echo "Patched jni AGP9 kotlin block: ${file}"
  else
    rm -f "${tmp}"
  fi
done

# file_picker 12's Kotlin source layout changed during the AGP 9 migration.
# Gradle's incremental cache can retain a source snapshot that compiles
# FilePickerDelegate.kt without FileUtils.kt after an upgrade.
root="${root:-$(cd "$(dirname "$0")/.." && pwd)}"
if [[ -d "${root}/build/file_picker" ]]; then
  rm -rf "${root}/build/file_picker"
  echo "Cleared stale ${root}/build/file_picker"
fi

echo "AGP 9 pub plugin patches applied."
