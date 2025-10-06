#!/bin/bash
# =============================================================
# 🧠 Debian 13 (Trixie) Universal Setup
# DWM + Zen Kernel + Wallpaper + GPU (NVIDIA/AMD/None)
# Author: Dennis Hilk
# License: MIT
# =============================================================

set -e

# --- Repos ----------------------------------------------------
echo "=== 🧩 1. Debian-Repositories aktivieren ==="
CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
sudo bash -c "cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian ${CODENAME} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${CODENAME}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${CODENAME}-backports main contrib non-free non-free-firmware
EOF"

sudo apt update && sudo apt full-upgrade -y

# --- Basis ----------------------------------------------------
echo "=== ⚙️ 2. Basiswerkzeuge installieren ==="
sudo apt install -y build-essential git curl wget nano unzip software-properties-common

# --- DWM + Tools ----------------------------------------------
echo "=== 💻 3. Xorg + DWM + Tools installieren ==="
sudo apt install -y xorg dwm suckless-tools stterm feh picom slstatus mesa-utils vulkan-tools

# --- Zen Kernel -----------------------------------------------
echo "=== ⚙️ 4. Zen-Kernel (Liquorix) installieren ==="
if ! apt-cache search linux-image-liquorix-amd64 | grep -q liquorix; then
  echo "→ Liquorix-Repository hinzufügen ..."
  sudo add-apt-repository -y ppa:damentz/liquorix || true
  sudo apt update
fi
sudo apt install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64 || {
  echo "⚠️  Liquorix-Kernel nicht verfügbar – Standardkernel bleibt aktiv."
}

# --- Wallpaper ------------------------------------------------
echo "=== 🖼️ 5. Wallpaper einrichten ==="
if [ -f "./coding-2.png" ]; then
  sudo mkdir -p /usr/share/backgrounds
  sudo cp ./coding-2.png /usr/share/backgrounds/wallpaper.png
  echo "✅ Wallpaper installiert unter /usr/share/backgrounds/wallpaper.png"
else
  echo "⚠️  Kein coding-2.png im Skriptordner gefunden – bitte manuell kopieren."
fi

# --- Autostart + Xinitrc -------------------------------------
echo "=== ⚙️ 6. DWM Autostart und Xinitrc konfigurieren ==="
mkdir -p ~/.dwm
cat > ~/.dwm/autostart.sh <<'EOF'
#!/bin/bash
feh --bg-scale /usr/share/backgrounds/wallpaper.png &
picom --experimental-backends &
slstatus &
EOF
chmod +x ~/.dwm/autostart.sh

cat > ~/.xinitrc <<'EOF'
#!/bin/bash
~/.dwm/autostart.sh &
exec dwm
EOF
chmod +x ~/.xinitrc

# --- Auto-Login ----------------------------------------------
echo "=== 🔧 7. Auto-Login in DWM (tty1) ==="
PROFILE=/home/$USER/.bash_profile
grep -q startx "$PROFILE" || echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$PROFILE"

# --- GPU Auswahl ---------------------------------------------
echo
echo "🎮 GPU-Setup-Assistent"
echo "-------------------------"
echo "Welche GPU-Treiber möchtest du installieren?"
echo "  [1] NVIDIA (z. B. RTX 3060 Ti)"
echo "  [2] AMD (z. B. RX 6600 / 6700 / 7900)"
echo "  [3] Keine – überspringen"
read -p "Deine Auswahl (1/2/3): " gpu_choice

case "$gpu_choice" in
  1)
    echo "=== 🧩 NVIDIA-Treiber werden installiert ==="
    sudo apt install -y linux-headers-$(uname -r) \
      nvidia-driver nvidia-smi nvidia-settings nvidia-cuda-toolkit libnvidia-encode1
    echo "=== 🎬 NVENC-Unterstützung ==="
    sudo apt install -y ffmpeg nv-codec-headers || true
    echo "🔍 Test mit: nvidia-smi"
    ;;

  2)
    echo "=== 🧩 AMD-Treiber werden installiert ==="
    sudo apt install -y firmware-amd-graphics mesa-vulkan-drivers vulkan-tools \
      libdrm-amdgpu1 mesa-utils libgl1-mesa-dri
    echo "=== 🎬 VAAPI-Unterstützung ==="
    sudo apt install -y ffmpeg mesa-va-drivers vainfo || true
    echo "🔍 Test mit: vainfo | grep Driver"
    ;;

  3)
    echo "❎ GPU-Installation übersprungen."
    ;;
  *)
    echo "⚠️ Ungültige Auswahl – übersprungen."
    ;;
esac

# --- Abschluss ------------------------------------------------
echo
echo "✅ Installation abgeschlossen!"
echo "System läuft mit DWM, Zen-Kernel und konfiguriertem Wallpaper."
echo "Starte dein System neu mit:  sudo reboot"
