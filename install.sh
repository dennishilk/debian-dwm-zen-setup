#!/bin/bash
set -e

# ────────────────────────────────
# Debian 13 DWM Ultimate v6.2 Setup
# By Dennis Hilk
# ────────────────────────────────

ONLY_CONFIG=false
EXPORT_PACKAGES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --only-config) ONLY_CONFIG=true; shift ;;
        --export-packages) EXPORT_PACKAGES=true; shift ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "  --only-config      Only copy or auto-download configs (skip kernel)"
            echo "  --export-packages  Export package list and exit"
            echo "  --help             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/dwm"
TEMP_DIR="/tmp/dwm_$$"
LOG_FILE="$HOME/dwm-install.log"

exec > >(tee -a "$LOG_FILE") 2>&1
trap "rm -rf $TEMP_DIR" EXIT

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
msg() { echo -e "${CYAN}$*${NC}"; }

clear
echo -e "${CYAN}"
echo "──────────────────────────────"
echo " Debian 13 DWM Ultimate v6.2  "
echo "──────────────────────────────"
echo -e "${NC}\n"

read -p "Proceed with full installation (Zen Kernel + ZRAM + GPU + Chrome + auto-DWM)? (y/n) " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 1

# ─── System Update ───────────────────────────────────────────────────────
if [ "$ONLY_CONFIG" = false ]; then
    msg "Updating system..."
    sudo apt-get update && sudo apt-get upgrade -y
fi

# ─── Packages ────────────────────────────────────────────────────────────
PACKAGES_CORE=(
    xorg xorg-dev xbacklight xbindkeys xvkbd xinput
    build-essential sxhkd xdotool dbus-x11
    libnotify-bin libnotify-dev libusb-0.1-4
)

PACKAGES_UI=( rofi dunst feh lxappearance network-manager-gnome )
PACKAGES_FILE_MANAGER=( thunar thunar-archive-plugin thunar-volman gvfs-backends dialog mtools smbclient cifs-utils unzip )
PACKAGES_AUDIO=( pavucontrol pulsemixer pamixer pipewire-audio )
PACKAGES_UTILITIES=( avahi-daemon acpi acpid xfce4-power-manager flameshot qimgv xdg-user-dirs-gtk fd-find zram-tools )
PACKAGES_TERMINAL=( suckless-tools alacritty )
PACKAGES_FONTS=( fonts-recommended fonts-font-awesome fonts-terminus )
PACKAGES_BUILD=( cmake meson ninja-build curl pkg-config git wget ca-certificates gnupg )

# ─── Base Installation ───────────────────────────────────────────────────
if [ "$ONLY_CONFIG" = false ]; then
    msg "Installing base packages..."
    sudo apt-get install -y "${PACKAGES_CORE[@]}" "${PACKAGES_UI[@]}" \
        "${PACKAGES_FILE_MANAGER[@]}" "${PACKAGES_AUDIO[@]}" \
        "${PACKAGES_UTILITIES[@]}" "${PACKAGES_TERMINAL[@]}" \
        "${PACKAGES_FONTS[@]}" "${PACKAGES_BUILD[@]}"
fi

# ─── Zen Kernel ─────────────────────────────────────────────────────────
if [ "$ONLY_CONFIG" = false ]; then
    msg "Installing Zen Kernel..."
    if sudo apt-get install -y linux-image-zen linux-headers-zen 2>/dev/null; then
        msg "Zen Kernel installed successfully."
    else
        msg "Zen Kernel not found, installing fallback kernel..."
        sudo apt-get install -y linux-image-amd64 linux-headers-amd64
    fi
    sudo update-grub
fi

# ─── GPU Detection ──────────────────────────────────────────────────────
if [ "$ONLY_CONFIG" = false ]; then
    msg "Detecting graphics card..."
    GPU=$(lspci | grep -E "VGA|3D" | tr '[:upper:]' '[:lower:]')

    if echo "$GPU" | grep -q "nvidia"; then
        msg "Detected NVIDIA GPU → installing drivers..."
        sudo apt-get install -y nvidia-driver nvidia-settings
        sudo systemctl enable nvidia-persistenced || true

    elif echo "$GPU" | grep -q "amd"; then
        msg "Detected AMD GPU → installing Mesa/AMDGPU drivers..."
        sudo apt-get install -y firmware-amd-graphics mesa-vulkan-drivers xserver-xorg-video-amdgpu

    elif echo "$GPU" | grep -q "intel"; then
        msg "Detected Intel GPU → installing Intel drivers..."
        sudo apt-get install -y firmware-misc-nonfree intel-media-va-driver-non-free i965-va-driver mesa-vulkan-drivers

    else
        msg "No supported GPU detected. Skipping GPU driver setup."
    fi
fi

# ─── Google Chrome ──────────────────────────────────────────────────────
if [ "$ONLY_CONFIG" = false ]; then
    msg "Installing Google Chrome Stable..."
    wget -q -O- https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" | \
        sudo tee /etc/apt/sources.list.d/google-chrome.list
    sudo apt-get update
    sudo apt-get install -y google-chrome-stable || msg "Chrome installation failed!"
fi

# ─── ZRAM Setup ─────────────────────────────────────────────────────────
if [ "$ONLY_CONFIG" = false ]; then
    msg "Configuring ZRAM..."
    sudo tee /etc/default/zramswap >/dev/null <<EOF
ENABLED=true
PERCENT=50
PRIORITY=100
ALGO=lz4
EOF
    sudo systemctl enable zramswap
    sudo systemctl start zramswap
fi

# ─── DWM/ST Auto-Fetch & Build ──────────────────────────────────────────
msg "Preparing DWM configuration..."
mkdir -p "$CONFIG_DIR"

# Prefer local configs, otherwise auto-clone
if [ -d "$SCRIPT_DIR/suckless" ]; then
    msg "Found 'suckless/' directory → copying configs..."
    cp -r "$SCRIPT_DIR/suckless/"* "$CONFIG_DIR"/
else
    found_local=false
    for dir in dwm st slstatus; do
        if [ -d "$SCRIPT_DIR/$dir" ]; then
            msg "Found local $dir folder → copying..."
            cp -r "$SCRIPT_DIR/$dir" "$CONFIG_DIR/"
            found_local=true
        fi
    done

    if [ "$found_local" = false ]; then
        msg "No local configs found → cloning official suckless sources..."
        git clone https://git.suckless.org/dwm "$CONFIG_DIR/dwm"
        git clone https://git.suckless.org/st "$CONFIG_DIR/st"
    fi
fi

# Build all available suckless components
msg "Building DWM & ST..."
for tool in dwm st; do
    if [ -d "$CONFIG_DIR/$tool" ]; then
        cd "$CONFIG_DIR/$tool"
        make && sudo make clean install || die "Failed to build $tool"
    else
        msg "Skipping missing $tool folder..."
    fi
done

# ─── Desktop Entries ─────────────────────────────────────────────────────
sudo mkdir -p /usr/share/xsessions
cat <<EOF | sudo tee /usr/share/xsessions/dwm.desktop >/dev/null
[Desktop Entry]
Name=dwm
Comment=Dynamic Window Manager
Exec=dwm
Type=XSession
EOF

mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/alacritty.desktop << EOF
[Desktop Entry]
Name=Alacritty
Comment=GPU accelerated terminal
Exec=alacritty
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
EOF

# ─── Wallpaper Setup ────────────────────────────────────────────────────
if [ -f "$SCRIPT_DIR/wallpaper.png" ]; then
    msg "Applying wallpaper..."
    mkdir -p "$HOME/.config/dwm"
    cp "$SCRIPT_DIR/wallpaper.png" "$HOME/.config/dwm/"
    feh --bg-fill "$HOME/.config/dwm/wallpaper.png" || true
else
    msg "No wallpaper.png found, skipping."
fi

# ─── Done ───────────────────────────────────────────────────────────────
echo -e "\n${GREEN}✅ Installation complete!${NC}"
echo "Zen Kernel, ZRAM, GPU drivers, Chrome, and DWM/ST are ready."
echo "Reboot now to start DWM on Debian 13."
