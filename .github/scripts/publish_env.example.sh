# Copy to publish_env.local.sh (gitignored) and fill in values.
# Usage (Git Bash / macOS / Linux, from repo root):
#   source .github/scripts/publish_env.local.sh
#   bash .github/scripts/release.sh --platform windows --publish
#
# SECURITY: never paste real AWS/R2 credentials into a tracked file. The
# pre-commit hook (.githooks/pre-commit) blocks credential-shaped strings and
# the local credential files. Load real values from a secure store (1Password
# CLI / GitHub Actions secrets) into this local copy only. See
# docs/packaging.md → "Publish credentials".

export AWS_ACCESS_KEY_ID="<R2 access key id>"
export AWS_SECRET_ACCESS_KEY="<R2 secret access key>"
export AWS_DEFAULT_REGION="auto"
export AWS_ENDPOINT_URL_S3="https://<account-id>.r2.cloudflarestorage.com"
export PUBLISH_BUCKET="<r2-bucket-name>"
export PUBLISH_PREFIX="player"

export CLOUDFLARE_API_TOKEN="<token with Cache Purge>"
export CLOUDFLARE_ZONE_ID="<zone id for enjoy.bot>"
# export ENJOY_PLAYER_DL_BASE="https://dl.enjoy.bot/player"

# Google Play AAB upload (for --play). Prefer a file path locally; CI uses
# GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64 (base64 -w0 of the JSON file).
# export GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH="$(git rev-parse --show-toplevel)/.google/play-service-account.json"
# export GOOGLE_PLAY_PACKAGE_NAME="ai.enjoy.player"
# export GOOGLE_PLAY_TRACK="alpha"
# export GOOGLE_PLAY_RELEASE_STATUS="draft"

# App Store Connect (local --testflight / --notarize). Prefer gitignored files so
# the private key is not pasted into this shell env file:
#   ~/.config/enjoy-player/asc.env   # KEY_ID + ISSUER_ID
#   .apple/AuthKey_<KEY_ID>.p8       # private key
# Or export explicitly:
# export APP_STORE_CONNECT_API_KEY_ID="<10-char key id>"
# export APP_STORE_CONNECT_ISSUER_ID="<uuid>"
# export APP_STORE_CONNECT_API_PRIVATE_KEY_PATH="$(git rev-parse --show-toplevel)/.apple/AuthKey_<KEY_ID>.p8"

# WinSparkle signing (required for desktop auto-update appcast).
# sign_sparkle_enclosure.sh auto-detects a `dsa_priv.pem` at the repo root,
# so leave SPARKLE_DSA_PRIV_PEM unset when the key lives there. Only set it
# explicitly when the key is elsewhere — resolve relative to the repo root
# (NEVER hardcode an absolute path):
#   export SPARKLE_DSA_PRIV_PEM="$(git rev-parse --show-toplevel)/keys/dsa_priv.pem"
# CI injects the key as base64 via SPARKLE_DSA_PRIV_PEM_BASE64 instead.
