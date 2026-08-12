#!/usr/bin/env bash
# Shared SwiftPM hygiene for Apple CI / release on self-hosted macOS.
#
# Flutter 3.44+ resolves google_sign_in (and friends) via SwiftPM. On a
# self-hosted Mac that also runs Cursor/VS Code Copilot, inherited
# GIT_CONFIG_*=safe.bareRepository=explicit breaks bare SPM caches and
# surfaces as opaque "xcodebuild encountered an error (74)". Concurrent
# Apple jobs on the same host can also race the shared SPM cache.
#
# Source this file; do not execute it directly.
# shellcheck shell=bash

apple_sanitize_git_env_for_spm() {
  # Env-injected git config outranks global; zero the count so SwiftPM can
  # use its bare repository caches (see flutter/flutter#187828).
  export GIT_CONFIG_COUNT=0
  local i=0
  while [[ $i -lt 32 ]]; do
    unset "GIT_CONFIG_KEY_${i}" "GIT_CONFIG_VALUE_${i}" 2>/dev/null || true
    i=$((i + 1))
  done
}

apple_clear_spm_caches() {
  local root="${1:-.}"
  rm -rf "${HOME}/Library/Caches/org.swift.swiftpm"
  rm -rf \
    "${root}/ios/Flutter/ephemeral/Packages/.build" \
    "${root}/macos/Flutter/ephemeral/Packages/.build" \
    "${root}/ios/SourcePackages" \
    "${root}/macos/SourcePackages" \
    "${root}/build/ios/SourcePackages" \
    "${root}/build/macos/SourcePackages"
}

apple_spm_failure_match() {
  # Reads log text on stdin; exit 0 if retryable SPM / error-74 failure.
  grep -qE \
    'Could not resolve package dependencies|Couldn.t fetch updates from remote repositories|INTERNAL ERROR: Uncaught exception|xcodebuild encountered an error \(74\)|safe\.bareRepository is .explicit.|skipping cache due to an error'
}

apple_spm_lock_dir() {
  echo "${TMPDIR:-/tmp}/enjoy-player-apple-spm.lockdir"
}

apple_spm_lock_acquire() {
  local lockdir
  lockdir="$(apple_spm_lock_dir)"
  local waited=0
  local max_wait_s="${APPLE_SPM_LOCK_TIMEOUT_S:-3600}"
  local stale_s="${APPLE_SPM_LOCK_STALE_S:-7200}"

  while ! mkdir "${lockdir}" 2>/dev/null; do
    if [[ -d "${lockdir}" ]]; then
      local age=0
      if stat_mtime="$(stat -f %m "${lockdir}" 2>/dev/null)"; then
        age=$(( $(date +%s) - stat_mtime ))
      fi
      if [[ "${age}" -ge "${stale_s}" ]]; then
        echo "Removing stale Apple SPM host lock (${lockdir}, age ${age}s)" >&2
        rmdir "${lockdir}" 2>/dev/null || rm -rf "${lockdir}"
        continue
      fi
    fi
    if [[ "${waited}" -ge "${max_wait_s}" ]]; then
      echo "Timed out after ${max_wait_s}s waiting for Apple SPM host lock (${lockdir})" >&2
      return 1
    fi
    if [[ $((waited % 60)) -eq 0 ]]; then
      echo "Waiting for Apple SPM host lock (${lockdir}); waited ${waited}s…" >&2
    fi
    sleep 5
    waited=$((waited + 5))
  done
}

apple_spm_lock_release() {
  rmdir "$(apple_spm_lock_dir)" 2>/dev/null || true
}

# Run command under the host SPM lock with sanitized git env.
apple_with_spm_host_lock() {
  apple_spm_lock_acquire || return 1
  apple_sanitize_git_env_for_spm
  local cmd_status=0
  "$@" || cmd_status=$?
  apple_spm_lock_release
  return "${cmd_status}"
}

# Retry a command up to 3 times on SPM-shaped failures.
# Usage: apple_retry_spm_command <repo_root> <command> [args...]
apple_retry_spm_command() {
  local root="${1:?apple_retry_spm_command: repo root required}"
  shift
  if [[ "$#" -lt 1 ]]; then
    echo "apple_retry_spm_command: missing command" >&2
    return 2
  fi

  apple_sanitize_git_env_for_spm

  local attempt logfile cmd_status
  for attempt in 1 2 3; do
    logfile="$(mktemp -t enjoy-apple-spm.XXXXXX)"
    set +e
    "$@" 2>&1 | tee "${logfile}"
    cmd_status=${PIPESTATUS[0]}
    set -e
    if [[ "${cmd_status}" -eq 0 ]]; then
      rm -f "${logfile}"
      return 0
    fi
    if [[ "${attempt}" -lt 3 ]] && apple_spm_failure_match <"${logfile}"; then
      echo "Apple SPM-related failure (attempt ${attempt}/3); clearing caches and retrying in 15s…" >&2
      rm -f "${logfile}"
      apple_clear_spm_caches "${root}"
      sleep 15
      continue
    fi
    rm -f "${logfile}"
    return "${cmd_status}"
  done
}
