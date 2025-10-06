#!/bin/bash
# =============================================================
# 🧠 Debian 13 (Trixie) Universal Setup
# DWM + Zen Kernel + Wallpaper + GPU (NVIDIA/AMD/None)
# Compatible with minimal Proxmox installations
# Author: Dennis Hilk
# License: MIT
# =============================================================

set -e

# --- 1️⃣ Debian Repositories aktivieren ----------------------------------------
echo "=== 🧩 1. Configure Debian repositories ==="
CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
sudo bash -c "cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian ${CODENAME} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${CODENAME}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${CODENAME}-backports main contrib non-free non-free-firmware
EOF"

sudo apt update && sudo apt full-upgrade -y

# --- 2️⃣ Basiswerkzeuge --------------------------------------------------------
echo "=== ⚙️ 2. Installing base tools ==="
sudo apt install -y build-essential git curl wget nano unzip ca-certificates gnupg lsb-release apt-transport-https

# --- 3️⃣ DWM + Desktop Tools ---------------------------------------------------
echo "=== 💻 3. Installing DWM and desktop utilities ==="
sudo apt install -y xorg dwm suckless-tools stterm feh picom slstatus mesa-utils vulkan-tools

# --- 4️⃣ Zen Kernel (Liquorix) ------------------------------------------------
echo "=== ⚙️ 4. Installing Zen Kernel (Liquorix) ==="

# Prüfen, ob add-apt-repository existiert
if command -v add-apt-repository >/dev/null 2>&1; then
  echo "→ add-apt-repository detected, using PPA method"
  sudo add-apt-repository -y ppa:damentz/liquorix || true
else
  echo "→ add-apt-repository not found, adding Liquorix repository manually"
  echo "deb http://liquorix.net/debian sid main" | sudo tee /etc/apt/sources.list.d/liquorix.list
  curl -fsSL https://liquorix.net/liquorix-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/liquorix.gpg
fi

sudo apt update
sudo apt install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64 || {
  echo "⚠️  Liquorix kernel not available – keeping default kernel."
}

# --- 5️⃣ Wallpaper ------------------------------------------------------------
echo "=== 🖼️ 5. Setting up wallpaper ==="
if [ -f "./coding-2.png" ]; then
  sudo mkdir -p /usr/share/backgrounds
  sudo cp ./coding-2.png /usr/share/backgrounds/wallpaper.png
  echo "✅ Wallpaper installed: /usr/share/backgrounds/wallpaper.png"
else
  echo "⚠️  coding-2.png not found – please copy it manually later."
fi

# --- 6️⃣ Autostart + Xinitrc --------------------------------------------------
echo "=== ⚙️ 6. Configuring DWM autostart and Xinitrc ==="
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

# --- 7️⃣ Auto-Login -----------------------------------------------------------
echo "=== 🔧 7. Enabling auto-login to DWM on tty1 ==="
PROFILE=/home/$USER/.bash_profile
grep -q startx "$PROFILE" || echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$PROFILE"

# --- 8️⃣ GPU Auswahl ----------------------------------------------------------
echo
echo "🎮 GPU Setup Assistant"
echo "------------------------"
echo "Choose your GPU driver:"
echo "  [1] NVIDIA (RTX / GTX)"
echo "  [2] AMD (Radeon / RX / Vega)"
echo "  [3] None – skip GPU setup"
read -p "Select (1/2/3): " gpu_choice

case "$gpu_choice" in
  1)
    echo "=== 🧩 Installing NVIDIA drivers ==="
    sudo apt install -y linux-headers-$(uname -r) \
      nvidia-driver nvidia-smi nvidia-settings nvidia-cuda-toolkit libnvidia-encode1
    echo "=== 🎬 Installing NVENC support ==="
    sudo apt install -y ffmpeg nv-codec-headers || true
    echo "🔍 Test with: nvidia-smi"
    ;;
  2)
    echo "=== 🧩 Installing AMD drivers ==="
    sudo apt install -y firmware-amd-graphics mesa-vulkan-drivers vulkan-tools \
      libdrm-amdgpu1 mesa-utils libgl1-mesa-dri
    echo "=== 🎬 Installing VAAPI support ==="
    sudo apt install -y ffmpeg mesa-va-drivers vainfo || true
    echo "🔍 Test with: vainfo | grep Driver"
    ;;
  3)
    echo "❎ GPU setup skipped."
    ;;
  *)
    echo "⚠️ Invalid choice – skipping GPU setup."
    ;;
esac

# --- 9️⃣ Abschluss ------------------------------------------------------------
echo
echo "✅ Installation complete!"
echo "Your Debian system is now running with DWM, Zen Kernel, and optional GPU support."
echo "Reboot now to apply changes:"
echo "  sudo reboot"
