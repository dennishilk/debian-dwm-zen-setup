#!/bin/bash
# =============================================================
# 🧠 Debian 13 (Trixie) Universal Setup
# DWM + Zen Kernel + GPU (NVIDIA/AMD/None) + ZRAM + Alacritty Terminal
# Auto-Start support for Proxmox / NoVNC
# Author: Dennis Hilk
# License: MIT
# =============================================================

set -e

# --- 1️⃣ Repositories ---------------------------------------------------------
echo "=== 🧩 1. Configure Debian repositories ==="
CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
sudo bash -c "cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian ${CODENAME} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${CODENAME}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${CODENAME}-backports main contrib non-free non-free-firmware
EOF"

sudo apt update && sudo apt full-upgrade -y

# --- 2️⃣ Base tools + ZRAM ----------------------------------------------------
echo "=== ⚙️ 2. Installing base tools and ZRAM ==="
sudo apt install -y build-essential git curl wget nano unzip ca-certificates gnupg \
  lsb-release apt-transport-https zram-tools

echo "=== 🧠 Enabling and configuring ZRAM ==="
sudo systemctl enable --now zramswap.service
if [ -f /etc/default/zramswap ]; then
  sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
  sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
  sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
  echo "✅ ZRAM configured (zstd, 50% RAM, priority 100)"
fi

# --- 3️⃣ DWM + Desktop tools ---------------------------------------------------
echo "=== 💻 3. Installing DWM and desktop utilities ==="
sudo apt install -y xorg dwm suckless-tools feh picom slstatus mesa-utils vulkan-tools

# --- 4️⃣ Zen Kernel (Liquorix signed) ----------------------------------------
echo "=== ⚙️ 4. Installing Zen Kernel (Liquorix, signed) ==="
sudo rm -f /etc/apt/sources.list.d/liquorix.list
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://liquorix.net/liquorix-keyring.gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/liquorix-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/liquorix-keyring.gpg] http://liquorix.net/debian sid main" | \
  sudo tee /etc/apt/sources.list.d/liquorix.list

sudo apt update
sudo apt install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64 || \
  echo "⚠️  Liquorix kernel not available – keeping default kernel."

# --- 5️⃣ Wallpaper ------------------------------------------------------------
echo "=== 🖼️ 5. Setting up wallpaper ==="
if [ -f "./coding-2.png" ]; then
  sudo mkdir -p /usr/share/backgrounds
  sudo cp ./coding-2.png /usr/share/backgrounds/wallpaper.png
  echo "✅ Wallpaper installed: /usr/share/backgrounds/wallpaper.png"
else
  echo "⚠️  coding-2.png not found – please copy manually later."
fi

# --- 6️⃣ Install Alacritty ----------------------------------------------------
echo "=== 🌈 6. Installing Alacritty (GPU-accelerated transparent terminal) ==="
sudo apt install -y alacritty || {
  echo "⚠️  Alacritty not found in Debian repos – falling back to stterm."
  sudo apt install -y stterm
}

# --- 7️⃣ DWM Autostart --------------------------------------------------------
echo "=== ⚙️ 7. Configuring DWM autostart and Xinitrc ==="
mkdir -p ~/.dwm
cat > ~/.dwm/autostart.sh <<'EOF'
#!/bin/bash
feh --bg-scale /usr/share/backgrounds/wallpaper.png &
picom --experimental-backends &
slstatus &

# --- Auto-start transparent terminal (Alacritty fallback to stterm) ---
if command -v alacritty >/dev/null 2>&1; then
  (sleep 2 && alacritty &) &
else
  (sleep 2 && stterm &) &
fi
EOF

chmod +x ~/.dwm/autostart.sh

cat > ~/.xinitrc <<'EOF'
#!/bin/bash
~/.dwm/autostart.sh &
exec dwm
EOF
chmod +x ~/.xinitrc

# --- 8️⃣ Auto-login -----------------------------------------------------------
echo "=== 🔧 8. Enabling auto-login to DWM on tty1 ==="
PROFILE=/home/$USER/.bash_profile
grep -q startx "$PROFILE" || echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$PROFILE"

# --- 9️⃣ GPU Setup ------------------------------------------------------------
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
    sudo apt install -y ffmpeg nv-codec-headers || true
    ;;
  2)
    echo "=== 🧩 Installing AMD drivers ==="
    sudo apt install -y firmware-amd-graphics mesa-vulkan-drivers vulkan-tools \
      libdrm-amdgpu1 mesa-utils libgl1-mesa-dri
    sudo apt install -y ffmpeg mesa-va-drivers vainfo || true
    ;;
  3)
    echo "❎ GPU setup skipped."
    ;;
  *)
    echo "⚠️ Invalid choice – skipping GPU setup."
    ;;
esac

# --- 🔟 Done -----------------------------------------------------------------
echo
echo "✅ Installation complete!"
echo "System running Debian ${CODENAME} + DWM + Zen Kernel (Liquorix) + ZRAM + Alacritty."
echo "Transparent terminal auto-starts (2s delay)."
echo "Reboot now to apply changes:"
echo "  sudo reboot"
