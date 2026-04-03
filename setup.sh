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
trap 'sudo rm -rf "${TEMP_DIR}"' EXIT

# Disable sudo timeout
echo 'Defaults timestamp_timeout = -1' | sudo tee /etc/sudoers.d/timeout >/dev/null

# Remove unwanted packages
UNWANTED_PACKAGES=(
  baobab
  firefox*
  gnome-abrt
  gnome-calendar
  gnome-characters
  gnome-clocks
  gnome-color-manager
  gnome-connections
  gnome-contacts
  gnome-font-viewer
  gnome-logs
  gnome-maps
  gnome-system-monitor
  gnome-tour
  gnome-weather
  ibus-anthy*
  ibus-hangul
  ibus-libpinyin
  ibus-m17n
  ibus-typing-booster
  libreoffice*
  simple-scan
  snapshot
  yelp*
)

sudo dnf remove -y "${UNWANTED_PACKAGES[@]}"

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

# Install Fish
sudo dnf install -y fish

# Set Fish as default shell
sudo usermod --shell "$(which fish)" "${USER}"

# Remove Fish greeting message
fish -c 'set -U fish_greeting ""'

# Install Fisher
fish -c 'curl -fsSL https://git.io/fisher | source && fisher install jorgebucaran/fisher'

# Install some Fish plugins
fish -c '
fisher install \
  jethrokuan/z \
  jorgebucaran/autopair.fish \
  nickeb96/puffer-fish
'

# Add Fish key bindings to delete words
fish -c '
function fish_user_key_bindings
  bind ctrl-h backward-kill-word
  bind ctrl-delete kill-word
end

funcsave fish_user_key_bindings
'

# Add Fish functions to create and enter directories
fish -c '
function mkcd
  mkdir -p $argv[1] && cd $argv[1]
end

funcsave mkcd

function mkcdtmp
  cd (mktemp -d)
end

funcsave mkcdtmp
'

# Install Flatpak packages
FLATPAK_PACKAGES=(
  com.belmoussaoui.Decoder
  com.mattjakeman.ExtensionManager
  com.rafaelmardojai.Blanket
  net.trowell.typesetter
  org.chromium.Chromium
  org.mozilla.firefox
)

sudo flatpak install flathub -y "${FLATPAK_PACKAGES[@]}"

# Install fonts from Font Squirrel
FONTS_DIR='/usr/share/fonts'
FONTS=(
  fira-code
  fira-sans
)

for font in "${FONTS[@]}"; do
  curl -f "https://www.fontsquirrel.com/fonts/download/${font}" -o "${TEMP_DIR}/${font}.zip" && \
  sudo unzip -o "${TEMP_DIR}/${font}.zip" -d "${FONTS_DIR}/${font}"

  sleep 1
done

sudo fc-cache -f

# Set interface fonts
dconf write /org/gnome/desktop/interface/font-name "'Fira Sans 9'"
dconf write /org/gnome/desktop/interface/document-font-name "'Fira Sans 9'"
dconf write /org/gnome/desktop/interface/monospace-font-name "'Fira Code 10'"

# Install GTK3 port of Libadwaita
sudo dnf install -y adw-gtk3-theme

# Set GTK theme
dconf write /org/gnome/desktop/interface/gtk-theme "'adw-gtk3-dark'"

# Speed ​​up animations
echo 'GNOME_SHELL_SLOWDOWN_FACTOR = 0.5' | sudo tee /etc/environment >/dev/null
