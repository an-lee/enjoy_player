#!/usr/bin/env bash
# Ensure the publish toolchain (AWS CLI v2 + jq) is available for release
# publishing on self-hosted Linux / macOS runners.
#
# The build steps don't need these; only the --publish step does. So this is run
# once, right before publishing, instead of on every job. Idempotent: installs
# only what's missing.
#
# AWS CLI v2 is required (not the v1 that older apt repos ship) because the R2
# publish path uses --checksum-algorithm CRC32.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

ensure_jq() {
  if have jq; then
    return 0
  fi
  echo ">>> Installing jq"
  case "$(uname -s)" in
    Darwin)
      if have brew; then
        brew install jq
      else
        echo "::error::jq missing and Homebrew not available on macOS" >&2
        return 1
      fi
      ;;
    Linux)
      if have apt-get; then
        sudo apt-get update -y >/dev/null
        sudo apt-get install -y jq
      else
        echo "::error::jq missing and no supported installer (apt-get)" >&2
        return 1
      fi
      ;;
    *)
      echo "::error::Unsupported OS for jq install: $(uname -s)" >&2
      return 1
      ;;
  esac
}

ensure_aws() {
  if have aws; then
    return 0
  fi

  os="$(uname -s)"
  arch="$(uname -m)"

  echo ">>> Installing AWS CLI v2 (${os} ${arch})"
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' EXIT

  case "${os}" in
    Darwin)
      # Homebrew's awscli is v2 and stays updated on self-hosted runners.
      if have brew; then
        brew install awscli
        return 0
      fi
      pkg="${tmp}/awscli.pkg"
      url_suffix="macos"
      if [[ "${arch}" == "arm64" ]]; then
        url_suffix="macosarm64"
      fi
      curl -fsSL --retry 3 --retry-delay 5 \
        -o "${pkg}" "https://awscli.amazonaws.com/AWSCLIV2-${url_suffix}.pkg"
      sudo installer -pkg "${pkg}" -target /
      ;;
    Linux)
      url_arch="x86_64"
      if [[ "${arch}" == "aarch64" || "${arch}" == "arm64" ]]; then
        url_arch="aarch64"
      fi
      zip="${tmp}/awscliv2.zip"
      curl -fsSL --retry 3 --retry-delay 5 \
        -o "${zip}" "https://awscli.amazonaws.com/awscli-exe-linux-${url_arch}.zip"
      unzip -q "${zip}" -d "${tmp}"
      sudo "${tmp}/aws/install" --update --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin
      ;;
    *)
      echo "::error::Unsupported OS for AWS CLI install: ${os}" >&2
      return 1
      ;;
  esac

  if ! have aws; then
    # /usr/local/bin may not be on PATH for this shell yet.
    case ":${PATH}:" in
      *:/usr/local/bin:*) ;;
      *) export PATH="/usr/local/bin:${PATH}" ;;
    esac
  fi
}

ensure_aws
ensure_jq

if have aws; then
  echo "AWS CLI: $(command -v aws) ($(aws --version 2>&1 || true))"
else
  echo "::error::aws still not on PATH after install" >&2
  exit 1
fi

if have jq; then
  echo "jq: $(command -v jq) ($(jq --version 2>&1 || true))"
else
  echo "::error::jq still not on PATH after install" >&2
  exit 1
fi
