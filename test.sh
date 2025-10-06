#!/bin/bash
# =============================================================
# 🧠 Debian 13 (Trixie) Universal Setup
# DWM + Zen Kernel (Liquorix) + GPU (NVIDIA/AMD/None)
# + ZRAM + Alacritty (TOML) + Picom transparency (neon blue)
# Author: Dennis Hilk • License: MIT
# =============================================================

set -e

# --- 1️⃣  Debian repositories -------------------------------------------------
echo "=== 🧩 1. Configure Debian repositories ==="
CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
sudo bash -c "cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian ${CODENAME} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${CODENAME}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${CODENAME}-backports main contrib non-free non-free-firmware
EOF"

sudo apt update && sudo apt full-upgrade -y

# --- 2️⃣  Base tools + ZRAM ---------------------------------------------------
echo "=== ⚙️ 2. Installing base tools and enabling ZRAM ==="
sudo apt install -y build-essential git curl wget nano unzip ca-certificates gnupg \
  lsb-release apt-transport-https zram-tools

sudo systemctl enable --now zramswap.service
sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
echo "✅ ZRAM configured (zstd, 50 % RAM, prio 100)"

# --- 3️⃣  DWM + Desktop tools -------------------------------------------------
echo "=== 💻 3. Installing DWM and utilities ==="
sudo apt install -y xorg dwm suckless-tools feh picom slstatus mesa-utils vulkan-tools

# --- 4️⃣  Zen Kernel ----------------------------------------------------------
echo "=== ⚙️ 4. Installing Zen Kernel (Liquorix, signed) ==="
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://liquorix.net/liquorix-keyring.gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/liquorix-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/liquorix-keyring.gpg] http://liquorix.net/debian sid main" | \
  sudo tee /etc/apt/sources.list.d/liquorix.list
sudo apt update
sudo apt install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64 || \
  echo "⚠️ Liquorix kernel not available – keeping default kernel."

# --- 5️⃣  Wallpaper -----------------------------------------------------------
echo "=== 🖼️ 5. Installing wallpaper ==="
sudo mkdir -p /usr/share/backgrounds
if [ -f "./coding-2.png" ]; then
  sudo cp ./coding-2.png /usr/share/backgrounds/wallpaper.png
  echo "✅ Wallpaper installed."
else
  echo "⚠️ coding-2.png missing – copy later to /usr/share/backgrounds/wallpaper.png"
fi

# --- 6️⃣  Alacritty -----------------------------------------------------------
echo "=== 🌈 6. Installing Alacritty terminal ==="
sudo apt install -y alacritty || { sudo apt install -y stterm; }

# --- 7️⃣  Alacritty (TOML) + Picom configs -----------------------------------
echo "=== 🎨 7. Creating Alacritty (TOML) and Picom configs ==="
mkdir -p ~/.config/alacritty
cat > ~/.config/alacritty/alacritty.toml <<'EOF'
[window]
opacity = 0.8
decorations = "none"
dynamic_title = true
padding = { x = 6, y = 4 }

[font]
normal = { family = "monospace", style = "Regular" }
size = 11.0

[colors.primary]
background = "0x0a0a0a"
foreground = "0xffffff"

[colors.cursor]
text = "0x0a0a0a"
cursor = "0x00ccff"

[cursor]
blink_interval = 500
unfocused_hollow = true
thickness = 0.15

[cursor.style]
shape = "Block"
blinking = "On"

[scrolling]
history = 10000
multiplier = 3
EOF

mkdir -p ~/.config
cat > ~/.config/picom.conf <<'EOF'
backend = "glx";
vsync = true;
detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
use-damage = true;
corner-radius = 6;
round-borders = 1;
shadow = true;
shadow-radius = 12;
shadow-color = "#00ccff";
shadow-opacity = 0.35;
opacity-rule = [ "90:class_g = 'Alacritty'" ];
fade-in-step = 0.03;
fade-out-step = 0.03;
EOF

# --- 8️⃣  DWM autostart ------------------------------------------------------
echo "=== ⚙️ 8. Configuring DWM autostart ==="
mkdir -p ~/.dwm
cat > ~/.dwm/autostart.sh <<'EOF'
#!/bin/bash
feh --bg-scale /usr/share/backgrounds/wallpaper.png &
picom --experimental-backends --config ~/.config/picom.conf &
slstatus &
(sleep 2 && alacritty &) &
EOF
chmod +x ~/.dwm/autostart.sh

cat > ~/.xinitrc <<'EOF'
#!/bin/bash
~/.dwm/autostart.sh &
exec dwm
EOF
chmod +x ~/.xin
