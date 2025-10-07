#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
#  Debian 13 DWM Install Script by Dennis Hilk
# ─────────────────────────────────────────────

abort() { echo "❌ Fehler: $1" >&2; exit 1; }

# ── Check: Debian 13 only
if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  abort "/etc/os-release nicht gefunden."
fi
if [ "$ID" != "debian" ] || [[ "$VERSION_ID" != "13" && "$VERSION_CODENAME" != "trixie" ]]; then
  abort "Dieses Skript ist nur für Debian 13 (Trixie)."
fi
echo "✅ Debian 13 erkannt – Installation startet ..."

sudo apt update && sudo apt install -y dialog git curl wget build-essential feh unzip

# ── Zen-Kernel
if dialog --yesno "Zen-Kernel installieren?" 8 40; then
  sudo apt install -y linux-image-zen linux-headers-zen || echo "⚠️ Zen-Kernel evtl. nicht im Repo verfügbar."
fi

# ── GPU Driver
if dialog --yesno "Aktuelle GPU-Treiber installieren?" 8 45; then
  if lspci | grep -qi nvidia; then
    echo "🟩 NVIDIA erkannt → Treiber installieren ..."
    sudo apt install -y nvidia-driver nvidia-kernel-dkms
  elif lspci | grep -qi amd; then
    echo "🟥 AMD erkannt → Treiber installieren ..."
    sudo apt install -y firmware-amd-graphics
  elif lspci | grep -qi intel; then
    echo "🟦 Intel erkannt → Treiber installieren ..."
    sudo apt install -y i965-driver intel-media-va-driver-non-free
  else
    echo "❔ Keine unterstützte GPU erkannt."
  fi
fi

# ── Browser Auswahl
BROWSERS=$(dialog --checklist "Wähle Browser zur Installation:" 15 60 5 \
1 "Firefox ESR" on \
2 "Brave" off \
3 "Chromium" off \
4 "Zen Browser" off \
5 "Google Chrome" off 3>&1 1>&2 2>&3)

clear
echo "Installiere ausgewählte Browser ..."

for choice in $BROWSERS; do
  case $choice in
    1) sudo apt install -y firefox-esr ;;
    2) sudo apt install -y apt-transport-https curl; \
       curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg; \
       echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list; \
       sudo apt update && sudo apt install -y brave-browser ;;
    3) sudo apt install -y chromium ;;
    4) echo "Zen-Browser installieren ..."; \
       wget -O zen.deb https://github.com/zen-browser/desktop/releases/latest/download/zen-browser-linux-amd64.deb && sudo apt install -y ./zen.deb ;;
    5) echo "Google Chrome installieren ..."; \
       wget -O chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && sudo apt install -y ./chrome.deb ;;
  esac
done

# ── Base Packages
sudo apt install -y xorg xinit dwm dmenu picom alacritty fonts-nerd-fonts \
  fish htop tmux neofetch git build-essential feh \
  pipewire wireplumber pipewire-audio pipewire-pulse \
  timeshift grub-btrfs timeshift-autosnap

# ── Wallpaper & Config
mkdir -p ~/.config/dwm
if [ -f "./wallpaper.png" ]; then
  cp ./wallpaper.png ~/.config/dwm/
fi

# ── .xinitrc → Autostart DWM
cat > ~/.xinitrc <<'EOF'
#!/bin/bash
xrandr --output "$(xrandr | awk '/ connected/{print $1;exit}')" --auto
feh --bg-fill ~/.config/dwm/wallpaper.png &
picom --config ~/.config/dwm/picom.conf &
exec dwm
EOF
chmod +x ~/.xinitrc

# ── Picom config (transparency)
mkdir -p ~/.config/dwm
cat > ~/.config/dwm/picom.conf <<'EOF'
backend = "glx";
vsync = true;
corner-radius = 12;
opacity-rule = [
  "90:class_g = 'Alacritty'"
];
shadow = true;
fading = true;
EOF

# ── Alacritty config
mkdir -p ~/.config/alacritty
cat > ~/.config/alacritty/alacritty.yml <<'EOF'
window:
  opacity: 0.9
  decorations: full
  padding: {x: 10, y: 10}
font:
  normal:
    family: "JetBrainsMono Nerd Font"
  size: 12
colors:
  primary:
    background: "0x0f111a"
    foreground: "0xc5c8c6"
  cursor:
    text: "0x000000"
    cursor: "0xffffff"
EOF

# ── Fish Shell default
chsh -s /usr/bin/fish

# ── DWM Config
sudo rm -rf /usr/local/src/dwm
sudo git clone https://git.suckless.org/dwm /usr/local/src/dwm
cd /usr/local/src/dwm
sudo make clean install

# ── slstatus (optional)
sudo git clone https://git.suckless.org/slstatus /usr/local/src/slstatus
cd /usr/local/src/slstatus
sudo make clean install

# ── Start-Hinweis
echo
echo "✅ Installation abgeschlossen!"
echo "Starte DWM mit:  startx"
echo "🧠 Tipp: Super + Return öffnet Alacritty (transparent)."
echo "🧩 Fish-Shell ist aktiv. Wallpaper wird automatisch gesetzt."
