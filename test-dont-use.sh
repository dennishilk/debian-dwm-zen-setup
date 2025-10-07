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

sudo apt update && sudo apt install -y dialog git curl wget build-essential feh unzip lsb-release pciutils lm-sensors bc make gcc

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
sudo apt install -y xorg xinit picom alacritty fish htop tmux fastfetch git feh \
  pipewire wireplumber pipewire-audio pipewire-pulse timeshift zram-tools

# ── JetBrainsMono Nerd Font
mkdir -p ~/.local/share/fonts
wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip -O /tmp/JetBrainsMono.zip
unzip -o /tmp/JetBrainsMono.zip -d ~/.local/share/fonts >/dev/null
fc-cache -fv >/dev/null
echo "🧩 Nerd Font installiert (JetBrainsMono)"

# ── ZRAM aktivieren
sudo sed -i 's/^#\?ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#\?PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo systemctl enable --now zramswap.service

# ── Wallpaper
mkdir -p ~/.config/dwm
if [ -f "./wallpaper.png" ]; then
  cp ./wallpaper.png ~/.config/dwm/
fi

# ── .xinitrc → Autostart DWM (lokal)
cat > ~/.xinitrc <<'EOF'
#!/bin/bash
export PATH="$HOME/.config/dwm/bin:$PATH"
xrandr --output "$(xrandr | awk '/ connected/{print $1;exit}')" --auto
feh --bg-fill ~/.config/dwm/wallpaper.png &
picom --config ~/.config/dwm/picom.conf &
exec dwm
EOF
chmod +x ~/.xinitrc

# ── Picom config (transparency)
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
shell:
  program: /usr/bin/fish
EOF

# ── Fish Shell default
chsh -s /usr/bin/fish

# ── Total System Uptime Tracker
sudo mkdir -p /var/lib
if [ ! -f /var/lib/system-uptime.db ]; then
  echo "0" | sudo tee /var/lib/system-uptime.db >/dev/null
fi

# ── Fish Config (Dashboard)
mkdir -p ~/.config/fish
cat > ~/.config/fish/config.fish <<'EOF'
function fish_greeting
    set_color cyan
    echo "🐧  "(lsb_release -ds)" "(uname -m)
    echo "──────────────────────────────────────────────"
    set_color green
    echo "🧠  Host:" (hostname)
    echo "⚙️  Kernel:" (uname -r)
    echo "⏱️  Current uptime:" (uptime -p | sed 's/up //')

    set uptime_seconds (awk '{print int($1)}' /proc/uptime)
    set saved_total (cat /var/lib/system-uptime.db ^/dev/null 2>/dev/null; or echo 0)
    set new_total (math "$uptime_seconds + $saved_total")
    echo $new_total | sudo tee /var/lib/system-uptime.db >/dev/null
    set total_days (math "scale=2; $new_total / 86400")
    echo "🕓  Total system uptime:" $total_days "days"

    echo "📦  Packages:" (dpkg -l | grep '^ii' | wc -l)" (apt)"
    echo "💻  Shell:" (fish --version | awk '{print $3}')
    echo "🧩  WM: dwm"
    echo "🖥️  CPU:" (lscpu | awk -F: '/Model name/ {print $2}' | sed 's/^ *//')
    echo "🎮  GPU:" (lspci | grep -E "VGA|3D" | awk -F ': ' '{print $3}' | head -n1)
    echo "💽  Disk:" (df -h / | awk 'NR==2 {print $5 " of " $2}')
    echo "💾  RAM:" (free -h | awk '/Mem/ {print $3 " / " $2}')
    echo "🧮  ZRAM:" (systemctl is-active zramswap.service)
    echo "🔊  Audio: PipeWire active"
    if test -d /timeshift
        echo "💾  Timeshift: enabled"
    else
        echo "💾  Timeshift: not found"
    end
    echo "──────────────────────────────────────────────"
    echo "✨  Tip: F2 → fastfetch | F3 → htop | exit → logout"
    set_color normal
end
EOF

# ── Build DWM + Tools lokal unter ~/.config/dwm
mkdir -p ~/.config/dwm/src ~/.config/dwm/bin
cd ~/.config/dwm/src

# DWM
git clone https://git.suckless.org/dwm
cd dwm && make && cp dwm ~/.config/dwm/bin && cd ..

# dmenu
git clone https://git.suckless.org/dmenu
cd dmenu && make && cp dmenu ~/.config/dwm/bin && cd ..

# slstatus
git clone https://git.suckless.org/slstatus
cd slstatus && make && cp slstatus ~/.config/dwm/bin && cd ..

# PATH für lokale Binaries
echo 'export PATH="$HOME/.config/dwm/bin:$PATH"' >> ~/.bashrc
echo 'set -Ux PATH $HOME/.config/dwm/bin $PATH' | fish

# ── Done
echo
echo "✅ Installation abgeschlossen!"
echo "Starte DWM mit:  startx"
echo "🧠 Super + Return = Alacritty (mit System-Dashboard)"
echo "🎨 DWM & Tools lokal unter ~/.config/dwm/bin gespeichert."
echo "💾 ZRAM, PipeWire, Fish, Fastfetch aktiv."
