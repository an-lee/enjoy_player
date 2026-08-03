#!/usr/bin/env bash
# Install Linux build packages only when missing (self-hosted runners).
#
# On the shared gh-sr agentic runner pool, most of these are now baked into
# the container image at build time via `container_runner_image.extra_apt_packages`
# in runners.yml, so this should normally be a fast no-op there. Kept as a
# safety net for any Linux runner (agentic image rebuild pending, or a plain
# native host) where a package isn't baked in yet.
set -euo pipefail

packages=(
  clang
  cmake
  curl
  git
  jq
  ninja-build
  pkg-config
  unzip
  xz-utils
  zip
  python3
  python3-venv
  libgtk-3-dev
  liblzma-dev
  libsqlite3-dev
  libgstreamer1.0-dev
  libgstreamer-plugins-base1.0-dev
  libsecret-1-dev
  libmpv-dev
)

missing=()
for pkg in "${packages[@]}"; do
  if ! dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q 'install ok installed'; then
    missing+=("${pkg}")
  fi
done

if [ "${#missing[@]}" -eq 0 ]; then
  echo "Linux build packages already installed."
  exit 0
fi

echo "Installing missing packages: ${missing[*]}"
sudo apt-get update -y
sudo apt-get install -y "${missing[@]}"
