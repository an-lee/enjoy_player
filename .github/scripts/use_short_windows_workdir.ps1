# Map GITHUB_WORKSPACE to a short path so MSBuild tlog files stay under MAX_PATH.
# Self-hosted runners often use long paths like
# C:\Users\me\.gh-sr\runners\<host>\_work\<org>\<repo>\ that overflow MAX_PATH
# (260 chars) once flutter_inappwebview_windows / media_kit_libs_windows_video
# plugin tlog paths are appended, producing MSB3491 ("could not find part of
# the path"). subst W: does NOT help here because MSBuild resolves subst
# targets back to the underlying real path before writing .tlog state, so
# the long path is what actually hits the filesystem. A directory junction
# at C:\e\<repo> (mklink /J) keeps the build's root, .vcxproj locations,
# and tlog output all under the short path, so MSBuild writes succeed.
$ErrorActionPreference = 'Stop'

$shortRoot = 'C:\e'
$workspace = $env:GITHUB_WORKSPACE
if (-not $workspace) {
  throw 'GITHUB_WORKSPACE is not set'
}

$workspace = (Resolve-Path -LiteralPath $workspace).Path
$baseName = Split-Path -Leaf $workspace
$shortPath = Join-Path $shortRoot $baseName

# Clean up any stale mapping from a previous run before re-linking.
if (Test-Path $shortPath) {
  cmd /c rmdir $shortPath 2>$null
}
if (-not (Test-Path $shortRoot)) {
  New-Item -Path $shortRoot -ItemType Directory -Force | Out-Null
}

cmd /c mklink /J $shortPath $workspace | Out-Null
if (-not (Test-Path $shortPath)) {
  throw "Failed to create junction $shortPath -> $workspace"
}

"GITHUB_WORKSPACE=$shortPath" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
Write-Host "Mapped $shortPath -> $workspace"
