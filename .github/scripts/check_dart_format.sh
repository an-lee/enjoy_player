#!/usr/bin/env bash
# Fails when Dart sources are not formatted the way CI expects.
# Mirrors the path set in .github/workflows/ci.yml.
#
# Usage: bash .github/scripts/check_dart_format.sh
#        bash .github/scripts/check_dart_format.sh --fix   # write formatting

set -euo pipefail

fix=0
if [[ "${1:-}" == "--fix" ]]; then
  fix=1
fi

paths=(lib test)
for pkg in packages/*/; do
  [ -d "${pkg}lib" ] && paths+=("${pkg}lib")
  [ -d "${pkg}test" ] && paths+=("${pkg}test")
done

if [[ "$fix" -eq 1 ]]; then
  dart format "${paths[@]}"
  exit 0
fi

if ! dart format --output=none --set-exit-if-changed "${paths[@]}"; then
  echo "" >&2
  echo "check_dart_format: sources need formatting." >&2
  echo "  Fix with: bash .github/scripts/check_dart_format.sh --fix" >&2
  echo "  Then stage the reformatted files." >&2
  echo "  Local formatter: $(dart --version 2>&1). CI formats with the Flutter pinned in .github/flutter-version — formatter releases can disagree, so reformat with that SDK if this passes locally but fails CI." >&2
  exit 1
fi

echo "check_dart_format: ok"
