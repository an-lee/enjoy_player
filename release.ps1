#!/usr/bin/env pwsh
# Local release entry point (Windows-friendly). Same logic as GitHub release workflows.
#
# Examples (see docs/packaging.md):
#   pwsh ./release.ps1                          # Windows build + installer
#   pwsh ./release.ps1 -Platform android        # Android AAB + sideload APKs
#   pwsh ./release.ps1 -Platform android -Play  # also upload AAB to Play (alpha/draft)
#   pwsh ./release.ps1 -Publish                 # build + upload to dl.enjoy.bot
#   pwsh ./release.ps1 -FeedsOnly               # build + local feeds (no S3)
#   pwsh ./release.ps1 -SkipChecks              # faster iteration
#   pwsh ./release.ps1 -PublishOnly -Publish    # re-upload all built artifacts (any platform)
#
param(
  [ValidateSet('windows', 'android', 'apple')]
  [string]$Platform = 'windows',

  [switch]$Publish,
  [switch]$FeedsOnly,
  [switch]$SkipChecks,
  [switch]$PublishOnly,
  [switch]$NoInstaller,
  [switch]$Play,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot

function Resolve-ReleaseBash {
  $gitBash = @(
    "${env:ProgramFiles}\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1

  if ($gitBash) { return $gitBash }

  $bash = Get-Command bash -ErrorAction SilentlyContinue
  if (-not $bash) {
    throw 'bash not found. Install Git for Windows (https://git-scm.com/download/win) or run from Git Bash.'
  }

  $path = $bash.Source
  if ($path -match '\\Windows\\System32\\bash\.exe$' -or $path -match '\\WindowsApps\\bash\.exe$') {
    throw @(
      'release.ps1 needs Git Bash, not WSL bash (PATH resolves to WSL).',
      'Install Git for Windows, or run: bash .github/scripts/release.sh --platform windows'
    ) -join "`n"
  }

  return $path
}

if ($Help) {
  Get-Content (Join-Path $RepoRoot '.github/scripts/release.sh') -TotalCount 20
  Write-Host ''
  Write-Host 'Run: bash .github/scripts/release.sh --help'
  exit 0
}

$envFile = Join-Path $RepoRoot '.github/scripts/publish_env.local.ps1'
if (Test-Path $envFile) {
  Write-Host "Loading $envFile"
  . $envFile
}

$bashExe = Resolve-ReleaseBash
$effectivePlatform = $Platform
if ($PublishOnly -and ($Publish -or $FeedsOnly)) {
  $effectivePlatform = 'all'
}
$bashArgs = @('.github/scripts/release.sh', '--platform', $effectivePlatform)

if ($SkipChecks) { $bashArgs += '--skip-checks' }
if ($PublishOnly) { $bashArgs += '--publish-only' }
if ($Publish) { $bashArgs += '--publish' }
if ($FeedsOnly) { $bashArgs += '--feeds-only' }
if ($NoInstaller -and $effectivePlatform -eq 'windows') { $bashArgs += '--no-installer' }
if ($Play -and $effectivePlatform -eq 'android') { $bashArgs += '--play' }

Write-Host ">>> release.ps1 -Platform $effectivePlatform $bashExe $($bashArgs -join ' ')"

Push-Location $RepoRoot
try {
  & $bashExe @bashArgs
  exit $LASTEXITCODE
}
finally {
  Pop-Location
}
