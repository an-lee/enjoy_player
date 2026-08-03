# Stage the repo at a short path so flutter build windows (MSBuild) does not
# overflow MAX_PATH (260 chars). Self-hosted runners often check out under
# C:\Users\me\.gh-sr\runners\<host>\_work\<org>\<repo>\, which is 76 chars
# alone — once MSBuild appends plugin .tlog paths (e.g.
# build\windows\x64\plugins\flutter_inappwebview_windows\x64\Release\
# flutter_inappwebview_windows_DEPENDENCIES_DOWNLOAD\...\.tlog\) the
# final path is ~270 chars, producing MSB3491 ("could not find part of the
# path"). NTFS junctions and subst both fail: MSBuild resolves them to the
# underlying long path before writing tlog state.
#
# Mirror the project to C:\e\<repo> with robocopy /MIR (skips .git,
# .dart_tool, build/, etc.), then point GITHUB_WORKSPACE at the short
# copy. flutter/cmake/MSBuild all see the project at the short path, so
# the entire build tree — including tlog output — fits under MAX_PATH.
# After the build, only the artifacts (build/windows/.../Release, the
# .exe, the Inno Setup installer) are needed; the rest of the short-path
# copy is cleaned up.
$ErrorActionPreference = 'Stop'

$shortRoot = 'C:\e'
$workspace = $env:GITHUB_WORKSPACE
if (-not $workspace) {
  throw 'GITHUB_WORKSPACE is not set'
}
$workspace = (Resolve-Path -LiteralPath $workspace).Path
$baseName = Split-Path -Leaf $workspace
$shortPath = Join-Path $shortRoot $baseName

if (-not (Test-Path $shortRoot)) {
  New-Item -Path $shortRoot -ItemType Directory -Force | Out-Null
}
if (Test-Path $shortPath) {
  Remove-Item -Path $shortPath -Recurse -Force -ErrorAction SilentlyContinue
}

# /MIR mirrors the tree; /XD skips heavy/regenerable dirs.
# robocopy exit codes 0-7 are success (8+ are real failures).
# In PowerShell, $LASTEXITCODE (not the assignment expression) holds the
# native exit code, so capture explicitly.
robocopy $workspace $shortPath /MIR `
  /XD '.git' '.dart_tool' 'build' '.idea' '.vs' 'windows\ffmpeg' `
  /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
if ($LASTEXITCODE -ge 8) {
  throw "robocopy $workspace -> $shortPath failed with exit code $LASTEXITCODE"
}

"GITHUB_WORKSPACE=$shortPath" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
Write-Host "Staged $workspace -> $shortPath"
