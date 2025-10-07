#!/usr/bin/env bash
# ────────────────────────────────────────────────
# Debian 13 DWM Ultimate v.1337.DeineMUM.  (by Dennis Hilk)
# Zen Kernel • GPU Auto Detect • ZRAM • Fish Shell • Full OS Lifetime
# ────────────────────────────────────────────────

set -euo pipefail
GREEN="\033[1;32m"; YELLOW="\033[1;33m"; RESET="\033[0m"

CONFIG_DIR="$HOME/.config/dwm"
SRC_DIR="$HOME/.local/src"
AUTOSTART_SCRIPT="$CONFIG_DIR/autostart.sh"
WALLPAPER="$CONFIG_DIR/wallpaper.png"

echo -e "${GREEN}=== Debian 13 DWM Ultimate v9 Setup (by Dennis Hilk) ===${RESET}"

if [ "$EUID" -eq 0 ]; then
  echo "Bitte nicht als root ausführen."; exit 1
fi

# ────────────────────────────────────────────────
# 1. Basis-System vorbereiten
# ────────────────────────────────────────────────
echo -e "\n${YELLOW}→ Installiere Basis-Pakete...${RESET}"
sudo apt update
sudo apt install -y build-essential git curl wget feh xorg xinit \
  libx11-dev libxft-dev libxinerama-dev libxrandr-dev libxrender-dev libxext-dev \
  pipewire pipewire-pulse wireplumber fish neofetch zram-tools

# ────────────────────────────────────────────────
# 2. Zen-Kernel installieren (Backports kompatibel)
# ────────────────────────────────────────────────
echo -e "\n${YELLOW}→ Installiere Zen-Kernel (Backports)...${RESET}"
if ! grep -q "trixie-backports" /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null; then
  echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware" | \
    sudo tee /etc/apt/sources.list.d/backports.list
  sudo apt update
fi

sudo apt install -t trixie-backports -y linux-image-amd64 linux-image-rt-amd64 || {
  echo -e "${YELLOW}Zen Kernel nicht verfügbar, installiere aktuellen Low-Latency Kernel...${RESET}"
  sudo apt install -y linux-image-rt-amd64
}

# ────────────────────────────────────────────────
# 3. GPU Auto Detect
# ────────────────────────────────────────────────
echo -e "\n${YELLOW}→ Erkenne und installiere GPU-Treiber...${RESET}"
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
  echo -e "${YELLOW}Keine GPU erkannt – überspringe Installation.${RESET}"
fi

# ────────────────────────────────────────────────
# 4. ZRAM aktivieren
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
# 6. Xinit + Autostart
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
# 7. Fish-Shell mit vollständiger OS-Zeit
# ────────────────────────────────────────────────
sudo chsh -s /usr/bin/fish "$USER"
FISH_CONFIG="$HOME/.config/fish/config.fish"
mkdir -p "$(dirname "$FISH_CONFIG")"

cat <<'EOF' > "$FISH_CONFIG"
# ────────────────────────────────────────────────
# Fish Config – Debian 13 DWM Ultimate v9 (by Dennis Hilk)
# ────────────────────────────────────────────────
set fish_greeting
clear
set_color cyan
echo "──────────────────────────────"
echo "  Debian 13 DWM Ultimate v9"
echo "──────────────────────────────"
set_color yellow
set osname (lsb_release -ds)
set kernel (uname -r)
set uptime (uptime -p)

# OS Install Date
set install_date "unbekannt"
if test -e /var/log/installer/syslog
    set install_date (stat -c %y /var/log/installer/syslog | cut -d'.' -f1)
else if test -e /etc/debian_version
    set install_date (tune2fs -l (mount | grep ' / ' | awk '{print $1}') | grep 'Filesystem created:' | sed 's/.*created: //')
end

set_color green
echo "OS: $osname"
echo "Kernel: $kernel"
echo "Installiert am: $install_date"
echo "Uptime: $uptime"
echo "Memory: "(free -h | awk '/Mem:/ {print $3 " / " $2}')
echo "──────────────────────────────"
set_color cyan
neofetch --color_blocks off --disable uptime kernel shell resolution gpu cpu gpu_temp disk
set_color normal
echo "──────────────────────────────"
EOF

# ────────────────────────────────────────────────
# 8. Autostart Script
# ────────────────────────────────────────────────
cat <<'EOF' > "$AUTOSTART_SCRIPT"
#!/bin/sh
# Autostart – DWM Ultimate v9 (Dennis Hilk)

# Wallpaper: Priorität auf lokales ./wallpaper.png
if [ -f "$(dirname "$0")/../../wallpaper.png" ]; then
  feh --bg-fill "$(dirname "$0")/../../wallpaper.png" &
else
  feh --bg-fill ~/.config/dwm/wallpaper.png &
fi

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

echo "[DWM] gestartet am $(date)" >> ~/.config/dwm/dwm.log
EOF
chmod +x "$AUTOSTART_SCRIPT"

# ────────────────────────────────────────────────
# 9. Wallpaper kopieren, falls im selben Ordner
# ────────────────────────────────────────────────
SCRIPT_DIR=$(dirname "$(realpath "$0")")
if [ -f "$SCRIPT_DIR/wallpaper.png" ]; then
  cp "$SCRIPT_DIR/wallpaper.png" "$WALLPAPER"
else
  wget -q -O "$WALLPAPER" https://upload.wikimedia.org/wikipedia/commons/3/3a/Tux.svg || true
fi

# ────────────────────────────────────────────────
# 10. Desktop Session Datei
# ────────────────────────────────────────────────
sudo mkdir -p /usr/share/xsessions
sudo tee /usr/share/xsessions/dwm.desktop >/dev/null <<EOF
[Desktop Entry]
Encoding=UTF-8
Name=DWM Ultimate v9
Comment=Dynamic Window Manager (by Dennis Hilk)
Exec=/usr/bin/startx
Type=XSession
EOF

# ────────────────────────────────────────────────
# 11. Fertig
# ────────────────────────────────────────────────
echo -e "\n${GREEN}✅ DWM Ultimate v9 erfolgreich installiert!${RESET}"
echo -e "Fish Shell zeigt nun komplette OS-Zeit, Kernel, RAM & GPU."
echo -e "Wallpaper wird automatisch aus demselben Ordner verwendet."
echo -e "Starte das System neu, um den Kernel und DWM zu aktivieren."
