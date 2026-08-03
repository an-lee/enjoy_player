# Copy to publish_env.local.ps1 (gitignored) and fill in values.
# Used by release.ps1 and CI publish steps.
#
# SECURITY: this template is the ONLY place credential placeholders belong.
# Never paste real AWS/R2 access keys or secret keys into a tracked file —
# the pre-commit hook (.githooks/pre-commit) blocks credential-shaped
# strings and the local credential files themselves. Load real values from a
# secure store (Windows Credential Manager / 1Password CLI / GitHub Actions
# secrets) into this local copy only. See docs/packaging.md →
# "Publish credentials" for the recommended flow.
#
# Usage (PowerShell, from repo root):
#   . .\.github\scripts\publish_env.local.ps1
#   pwsh ./release.ps1 -Publish

$env:AWS_ACCESS_KEY_ID = "<R2 access key id>"
$env:AWS_SECRET_ACCESS_KEY = "<R2 secret access key>"
$env:AWS_DEFAULT_REGION = "auto"
$env:AWS_ENDPOINT_URL_S3 = "https://<account-id>.r2.cloudflarestorage.com"
$env:PUBLISH_BUCKET = "<r2-bucket-name>"
$env:PUBLISH_PREFIX = "player"

$env:CLOUDFLARE_API_TOKEN = "<token with Cache Purge>"
$env:CLOUDFLARE_ZONE_ID = "<zone id for enjoy.bot>"
# $env:ENJOY_PLAYER_DL_BASE = "https://dl.enjoy.bot/player"

# Google Play AAB upload (for -Play). Prefer a file path locally; CI uses
# GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64 (base64 of the JSON file).
# $repoRoot = & git rev-parse --show-toplevel
# $env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH = Join-Path $repoRoot ".google/play-service-account.json"
# $env:GOOGLE_PLAY_PACKAGE_NAME = "ai.enjoy.player"
# $env:GOOGLE_PLAY_TRACK = "alpha"
# $env:GOOGLE_PLAY_RELEASE_STATUS = "draft"

# WinSparkle signing (required for desktop auto-update appcast).
# sign_sparkle_enclosure.sh auto-detects a `dsa_priv.pem` at the repo root,
# so leave SPARKLE_DSA_PRIV_PEM unset when the key lives there. Only set it
# explicitly when the key is stored elsewhere — resolve the path relative to
# the repo root (NEVER hardcode an absolute path like C:\Users\...):
#   $repoRoot = & git rev-parse --show-toplevel
#   $env:SPARKLE_DSA_PRIV_PEM = Join-Path $repoRoot "keys/dsa_priv.pem"
# CI injects the key as base64 via SPARKLE_DSA_PRIV_PEM_BASE64 instead.
