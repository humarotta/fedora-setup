#!/bin/bash

set -eo pipefail

# Load OS release information
source /etc/os-release

# Check OS compatibility
MINIMUM_VERSION='43'

if [[ "${ID}" != 'fedora' || \
      "${VARIANT_ID}" != 'workstation' || \
      "${VERSION_ID}" -lt "${MINIMUM_VERSION}" ]]; then
  echo "This script is intended for Fedora Workstation ${MINIMUM_VERSION} or later."
  exit 1
fi

# Create temporary directory
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

# Disable sudo timeout
echo 'Defaults timestamp_timeout = -1' | sudo tee /etc/sudoers.d/timeout >/dev/null

# Install RPM Fusion repositories
sudo dnf install -y \
  "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${VERSION_ID}.noarch.rpm" \
  "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${VERSION_ID}.noarch.rpm"

# Install Flathub repository
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Update the system
sudo dnf update -y --refresh

# Install Visual Studio Code
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

sudo tee /etc/yum.repos.d/vscode.repo <<'EOF' >/dev/null
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

sudo dnf install -y code

# Install Cursor
sudo dnf install -y https://api2.cursor.sh/updates/download/golden/linux-x64-rpm/cursor/latest

# Install GitHub CLI
sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
sudo dnf install -y gh

# Install Docker
sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Enable Docker to start at OS boot
sudo systemctl enable --now docker

# Enable Docker usage without sudo
sudo gpasswd --add "${USER}" docker

# Configure Git
git config --global user.name 'Hugo Marotta'
git config --global user.email 'humarotta@proton.me'

git config --global user.signingkey 'humarotta@proton.me'
git config --global commit.gpgsign true

git config --global core.editor 'code --wait'
git config --global init.defaultBranch 'main'
