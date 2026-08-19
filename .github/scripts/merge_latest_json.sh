#!/usr/bin/env bash
# Merge latest.json asset maps when publishing one platform at a time.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: merge_latest_json.sh <new_latest.json> <remote_latest.json> <output.json>" >&2
  exit 2
fi

new="$1"
remote="$2"
out="$3"

if ! command -v jq >/dev/null 2>&1; then
  echo "merge_latest_json.sh requires jq on PATH" >&2
  exit 1
fi

if [[ ! -f "${remote}" ]]; then
  cp -f "${new}" "${out}"
  exit 0
fi

jq -s '
  .[0] as $new | .[1] as $remote |
  if ($remote | type) != "object" or ($remote.version != $new.version) then
    $new
  else
    $new
    | .assets = (($remote.assets // {}) * (.assets // {}))
    | .minSupportedVersion = (
        if (($new.minSupportedVersion // "") | length) > 0
        then $new.minSupportedVersion
        else ($remote.minSupportedVersion // $new.minSupportedVersion)
        end
      )
    | .notes = (
        if (($new.notes // "") | length) > 0
        then $new.notes
        else ($remote.notes // "")
        end
      )
    | .build = ($new.build // $remote.build)
  end
' "${new}" "${remote}" > "${out}"
