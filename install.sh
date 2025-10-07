#!/usr/bin/env bash
# ────────────────────────────────────────────────
# Debian 13 DWM Ultimate v8 (by Dennis Hilk)
# Zen Kernel • GPU Auto Detect • ZRAM • Fish Shell • System Info
# ────────────────────────────────────────────────

set -euo pipefail

GREEN="\033[1;32m"; YELLOW="\033[1;33m"; RESET="\033[0m"
CONFIG_DIR="$HOME/.config/dwm"
SRC_DIR="$HOME/.local/src"
SESSION_NAME="dwm"
WALLPAPER="$CONFIG_DIR/wallpaper.png"
AUTOSTART_SCRIPT="$CONFIG_DIR/autostart.sh"

echo -e "${GREEN}=== Debian 13 DWM Ultimate v8 Setup (by Dennis Hilk) ===${RESET}"

if [ "$EUID" -eq 0 ]; then
  echo "Bitte nicht als root ausführen."; exit 1
fi

# ────────────────────────────────────────────────
# 1. Basis-Pakete
# ────────────────────────────────────────────────
echo -e "\n${YELLOW}→ Installiere Systembasis...${RESET}"
sudo apt update
sudo apt install -y build-essential git curl wget feh xorg xinit linux-headers-$(uname -r) \
  libx11-dev libxft-dev libxinerama-dev libxrandr-dev libxrender-dev libxext-dev \
  pipewire pipewire-pulse wireplumber fish fastfetch zram-tools

# ────────────────────────────────────────────────
# 2. Zen-Kernel
# ────────────────────────────────────────────────
echo -e "\n${YELLOW}→ Installiere Zen Kernel...${RESET}"
sudo apt install -y linux-image-zen linux-headers-zen || {
  echo "Zen Kernel nicht in Repo – füge Backports hinzu..."
  echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware" | \
    sudo tee /etc/apt/sources.list.d/backports.list
  sudo apt update
  sudo apt install -t trixie-backports -y linux-image-zen linux-headers-zen
}

# ────────────────────────────────────────────────
# 3. GPU Auto Detect
# ────────────────────────────────────────────────
echo -e "\n${YELLOW}→ Erkenne Grafiktreiber...${RESET}"
GPU=$(lspci | grep -E "VGA|3D" || true)
if echo "$GPU" | grep -qi "NVIDIA"; then
  echo -e "${GREEN}NVIDIA GPU erkannt.${RESET}"
  sudo apt install -y nvidia-driver firmware-misc-nonfree
elif echo "$GPU" | grep -qi "AMD"; then
  echo -e "${GREEN}AMD GPU erkannt.${RESET}"
  sudo apt install -y firmware-amd-graphics mesa-vulkan-drivers vulkan-tools
elif echo "$GPU" | grep -qi "Intel"; then
  echo -e "${GREEN}Intel GPU erkannt.${RESET}"
  sudo apt install -y intel-media-va-driver-non-free mesa-vulkan-drivers vulkan-tools
else
  echo -e "${YELLOW}Keine GPU erkannt – überspringe.${RESET}"
fi

# ────────────────────────────────────────────────
# 4. ZRAM
# ────────────────────────────────────────────────
echo -e "\n${YELLOW}→ Aktiviere ZRAM...${RESET}"
sudo tee /etc/default/zram-config >/dev/null <<'EOF'
ALGO=zstd
PERCENT=75
PRIORITY=100
EOF
sudo systemctl enable --now zramswap.service

# ────────────────────────────────────────────────
# 5. DWM / DMENU / ST
# ────────────────────────────────────────────────
mkdir -p "$SRC_DIR" "$CONFIG_DIR"

install_from_suckless() {
  local name=$1; local url=$2
  local path="$SRC_DIR/$name"
  echo -e "\n${YELLOW}→ Installiere $name...${RESET}"
  [ -d "$path" ] || git clone "$url" "$path"
  cd "$path"
  sudo make clean install
}

install_from_suckless "dwm" "https://git.suckless.org/dwm"
install_from_suckless "dmenu" "https://git.suckless.org/dmenu"

read -rp "Möchtest du st (suckless terminal) installieren? [y/N]: " stinstall
[[ "$stinstall" =~ ^[Yy]$ ]] && install_from_suckless "st" "https://git.suckless.org/st"

# ────────────────────────────────────────────────
# 6. Xinit / Autostart
# ────────────────────────────────────────────────
cat <<EOF > "$HOME/.xinitrc"
#!/bin/sh
xsetroot -cursor_name left_ptr
bash "$AUTOSTART_SCRIPT" &
exec dwm
EOF
chmod +x "$HOME/.xinitrc"

grep -q "startx" "$HOME/.bash_profile" 2>/dev/null || cat <<'EOF' >> "$HOME/.bash_profile"
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  startx
fi
EOF

# ────────────────────────────────────────────────
# 7. Fish Shell + Systeminfos
# ────────────────────────────────────────────────
echo -e "\n${YELLOW}→ Setze Fish als Standard-Shell...${RESET}"
sudo chsh -s /usr/bin/fish "$USER"

FISH_CONFIG="$HOME/.config/fish/config.fish"
mkdir -p "$(dirname "$FISH_CONFIG")"

cat <<'EOF' > "$FISH_CONFIG"
# ────────────────────────────────────────────────
# Fish Config – Debian 13 DWM Ultimate v8 (by Dennis Hilk)
# ────────────────────────────────────────────────
set fish_greeting

# System Info beim Start
clear
set_color cyan
echo "──────────────────────────────"
echo "  Debian 13 DWM Ultimate v8"
echo "──────────────────────────────"
set_color yellow
echo "OS: "(lsb_release -ds)
echo "Kernel: "(uname -r)
echo "Uptime: "(uptime -p)
echo "Memory: "(free -h | awk '/Mem:/ {print $3 " / " $2}')
set_color green
echo "Date: "(date)
set_color normal
echo "──────────────────────────────"
neofetch --color_blocks off --cpu_temp C
echo "──────────────────────────────"
EOF

# ────────────────────────────────────────────────
# 8. Autostart Script
# ────────────────────────────────────────────────
cat <<'EOF' > "$AUTOSTART_SCRIPT"
#!/bin/sh
# DWM Autostart – Ultimate v8 (Dennis Hilk)

# Hintergrundbild
feh --bg-fill ~/.config/dwm/wallpaper.png &

# Audio
pipewire & disown
pipewire-pulse & disown
wireplumber & disown

# Terminal Variable
if command -v alacritty >/dev/null 2>&1; then
  export TERMINAL="alacritty"
else
  export TERMINAL="x-terminal-emulator"
fi

# Systeminfos im Log
echo "[DWM] gestartet am $(date)" >> ~/.config/dwm/dwm.log
EOF
chmod +x "$AUTOSTART_SCRIPT"

# ────────────────────────────────────────────────
# 9. XSession Datei
# ────────────────────────────────────────────────
sudo mkdir -p /usr/share/xsessions
sudo tee /usr/share/xsessions/dwm.desktop >/dev/null <<EOF
[Desktop Entry]
Encoding=UTF-8
Name=DWM Ultimate v8
Comment=Dynamic Window Manager (by Dennis Hilk)
Exec=/usr/bin/startx
Type=XSession
EOF

# ────────────────────────────────────────────────
# 10. Wallpaper Fallback
# ────────────────────────────────────────────────
if [ ! -f "$WALLPAPER" ]; then
  wget -q -O "$WALLPAPER" https://upload.wikimedia.org/wikipedia/commons/3/3a/Tux.svg || true
fi

# ────────────────────────────────────────────────
# 11. Abschluss
# ────────────────────────────────────────────────
echo -e "\n${GREEN}✅ Installation abgeschlossen!${RESET}"
echo -e "Fish Shell aktiv, Zen-Kernel installiert, GPU & ZRAM konfiguriert."
echo -e "Starte dein System neu und genieße DWM Ultimate v8."
