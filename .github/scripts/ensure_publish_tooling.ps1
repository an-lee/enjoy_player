# Ensure the publish toolchain (AWS CLI v2 + jq) is available for release
# publishing on self-hosted Windows runners.
#
# Only the --publish step needs these. Idempotent: installs only what's missing.
$ErrorActionPreference = 'Stop'

function Test-Command {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Add-DirToGithubPath {
  param([string]$Dir)
  if ($env:GITHUB_PATH -and (Test-Path $Dir)) {
    "$Dir" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
    if (-not ($env:Path -split ';' -contains $Dir)) {
      $env:Path = "$Dir;$env:Path"
    }
  }
}

function Ensure-Jq {
  if (Test-Command 'jq') { return }
  Write-Host '>>> Installing jq'
  $choco = Get-Command choco -ErrorAction SilentlyContinue
  if ($choco) {
    choco install jq -y --no-progress
    Add-DirToGithubPath 'C:\ProgramData\chocolatey\bin'
    if (Test-Command 'jq') { return }
  }
  # Manual fallback: download standalone jq.exe into a stable dir.
  $installDir = Join-Path $env:ProgramData 'jq'
  New-Item -ItemType Directory -Path $installDir -Force | Out-Null
  $jqExe = Join-Path $installDir 'jq.exe'
  Invoke-WebRequest -Uri 'https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe' -OutFile $jqExe
  Add-DirToGithubPath $installDir
  if (-not (Test-Command 'jq')) { throw 'jq still not on PATH after install' }
}

function Ensure-AwsCli {
  if (Test-Command 'aws') { return }
  Write-Host '>>> Installing AWS CLI v2'

  # Prefer the official MSI (works on self-hosted Windows runners).
  $msi = Join-Path $env:TEMP 'AWSCLI.msi'
  Invoke-WebRequest -Uri 'https://awscli.amazonaws.com/AWSCLIV2.msi' -OutFile $msi
  $log = Join-Path $env:TEMP 'awscli-install.log'
  $proc = Start-Process -FilePath 'msiexec.exe' `
    -ArgumentList "/i `"$msi`" /quiet /qn /norestart /l*v `"$log`"" `
    -Wait -PassThru
  if ($proc.ExitCode -ne 0) {
    throw "AWS CLI MSI install failed (exit $($proc.ExitCode)); see $log"
  }
  Remove-Item $msi -Force -ErrorAction SilentlyContinue

  # The MSI installs into %ProgramFiles%\Amazon\AWSCLIV2 — put it on PATH.
  $awsDir = Join-Path $env:ProgramFiles 'Amazon\AWSCLIV2'
  if (-not (Test-Path $awsDir)) {
    $awsDir = Join-Path ${env:ProgramFiles(x86)} 'Amazon\AWSCLIV2'
  }
  Add-DirToGithubPath $awsDir

  if (-not (Test-Command 'aws')) { throw 'aws still not on PATH after install' }
}

Ensure-AwsCli
Ensure-Jq

Write-Host "AWS CLI: $((Get-Command aws).Source) $(aws --version 2>&1)"
Write-Host "jq: $((Get-Command jq).Source) $(jq --version 2>&1)"
