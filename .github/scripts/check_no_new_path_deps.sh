#!/usr/bin/env bash
# Fails CI when a new local-path package is added to pubspec.yaml.
# Existing path: packages (azure_speech, ffmpeg_kit_flutter_new,
# forced_alignment) are allowlisted in docs/decisions/0029-supply-chain-risk.md
# and tracked via this script's allowlist array.
#
# Usage: bash .github/scripts/check_no_new_path_deps.sh

set -euo pipefail

ALLOWLIST=(
  "packages/azure_speech"
  "packages/ffmpeg_kit_flutter_new"
  "packages/forced_alignment"
)

if [ ! -f pubspec.yaml ]; then
  echo "check_no_new_path_deps.sh: pubspec.yaml not found at $(pwd)" >&2
  exit 1
fi

# Extract `path:` values under dependencies: / dev_dependencies: blocks.
# Grep is intentionally narrow (matches only `  <key>:` followed by
# `    path: <value>` on the next line) to avoid false positives.
mapfile -t found < <(
  awk '
    /^(dev_)?dependencies:/ { in_block = 1; next }
    in_block && /^[^ ]/ { in_block = 0 }
    in_block && /^  [a-zA-Z0-9_]+:$/ {
      key = $1; sub(/:$/, "", key); getline next_line;
      if (match(next_line, /^    path:[ \t]+/)) {
        path = substr(next_line, RSTART + RLENGTH);
        print key "|" path;
      }
    }
  ' pubspec.yaml
)

if [ "${#found[@]}" -eq 0 ]; then
  echo "check_no_new_path_deps: no path: dependencies found."
  exit 0
fi

violations=0
for entry in "${found[@]}"; do
  pkg="${entry%%|*}"
  path="${entry#*|}"
  allowed=false
  for a in "${ALLOWLIST[@]}"; do
    if [ "$path" = "$a" ]; then allowed=true; break; fi
  done
  if [ "$allowed" = true ]; then
    echo "  allowlisted: $pkg -> $path"
  else
    echo "  ERROR: $pkg -> $path is a NEW local-path dependency." >&2
    echo "         Add it to docs/decisions/0029-supply-chain-risk.md" >&2
    echo "         and to ALLOWLIST in this script, or convert it to a" >&2
    echo "         git: / pub.dev reference." >&2
    violations=$((violations + 1))
  fi
done

if [ "$violations" -gt 0 ]; then
  echo "check_no_new_path_deps: $violations unapproved path: dep(s)." >&2
  exit 1
fi

echo "check_no_new_path_deps: all path: deps are allowlisted."
