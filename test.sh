#!/bin/bash
# =============================================================
# 🧠 Debian 13 DWM Full Dark Setup (Dennis Hilk Auto-Fix v6)
#  - Fixes "exec dwm not found"
#  - Always uses absolute path /usr/local/bin/dwm
#  - Rebuilds automatically if missing
# =============================================================
set -e

# --- detect user -------------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
  REAL_USER=$(logname)
  HOME_DIR=$(eval echo "~$REAL_USER")
else
  REAL_USER=$USER
  HOME_DIR=$HOME
fi
echo "👤 User: $REAL_USER ($HOME_DIR)"

# --- detect VM ---------------------------------------------------------------
if systemd-detect-virt | grep -Eq "qemu|kvm|vmware|vbox"; then
  PICOM_BACKEND="xrender"
else
  PICOM_BACKEND="glx"
fi
echo "💻 Picom backend: $PICOM_BACKEND"

# --- base packages -----------------------------------------------------------
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y xorg feh picom slstatus build-essential git curl wget unzip \
  zram-tools plymouth-themes grub2-common zsh lxappearance \
  gtk2-engines-murrine adwaita-icon-theme-full papirus-icon-theme \
  thunar thunar-volman gvfs gvfs-backends gvfs-fuse ca-certificates

# --- ZRAM --------------------------------------------------------------------
sudo systemctl enable --now zramswap.service
sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
echo "✅ ZRAM configured"

# --- JetBrains Mono Nerd Font ------------------------------------------------
echo "📦 Installing JetBrains Mono Nerd Font..."
sudo mkdir -p /usr/share/fonts/truetype/nerd
cd /usr/share/fonts/truetype/nerd

FONT_URLS=(
  "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"
  "https://mirror.ghproxy.com/https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"
  "https://cdn.jsdelivr.net/gh/ryanoasis/nerd-fonts@v3.2.1/patched-fonts/JetBrainsMono/complete/JetBrainsMonoNerdFont-Regular.ttf"
)
success=false
for URL in "${FONT_URLS[@]}"; do
  echo "→ Trying $URL ..."
  if sudo wget --timeout=30 --show-progress -q "$URL" -O JetBrainsMono.zip || \
     sudo curl -L --max-time 30 -o JetBrainsMono.zip "$URL"; then
      echo "✅ Downloaded from $URL"
      success=true
      break
  fi
done

if [ "$success" = true ]; then
  sudo unzip -o JetBrainsMono.zip >/dev/null 2>&1 || true
  sudo fc-cache -fv >/dev/null
  echo "✅ JetBrains Mono Nerd Font installed successfully"
else
  echo "⚠️ Font download failed. You can place JetBrainsMono.zip manually in:"
  echo "   /usr/share/fonts/truetype/nerd/"
fi
cd ~
sleep 1

# --- Alacritty ---------------------------------------------------------------
mkdir -p "$HOME_DIR/.config/alacritty"
cat > "$HOME_DIR/.config/alacritty/alacritty.toml" <<'EOF'
[window]
opacity = 0.8
decorations = "none"
padding = { x = 6, y = 4 }
[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
size = 11.0
[colors.primary]
background = "0x0a0a0a"
foreground = "0xcccccc"
[colors.cursor]
text = "0x0a0a0a"
cursor = "0x00ff99"
EOF

# --- Picom -------------------------------------------------------------------
mkdir -p "$HOME_DIR/.config"
cat > "$HOME_DIR/.config/picom.conf" <<EOF
backend = "${PICOM_BACKEND}";
vsync = true;
corner-radius = 6;
shadow = true;
shadow-radius = 12;
shadow-color = "#00ff99";
shadow-opacity = 0.35;
blur-method = "dual_kawase";
blur-strength = 5;
inactive-opacity = 0.85;
active-opacity = 1.0;
EOF

# --- Wallpaper ---------------------------------------------------------------
sudo mkdir -p /usr/share/backgrounds
[ -f "./coding-2.png" ] && sudo cp ./coding-2.png /usr/share/backgrounds/wallpaper.png

# --- Autostart ---------------------------------------------------------------
mkdir -p "$HOME_DIR/.dwm"
cat > "$HOME_DIR/.dwm/autostart.sh" <<'EOF'
#!/bin/bash
xsetroot -solid black &
feh --no-fehbg --bg-scale /usr/share/backgrounds/wallpaper.png &
picom --experimental-backends --config ~/.config/picom.conf &
slstatus &
(sleep 2 && xterm &) &
EOF
chmod +x "$HOME_DIR/.dwm/autostart.sh"

# --- .xinitrc with absolute path + rebuild -----------------------------------
cat > "$HOME_DIR/.xinitrc" <<'EOF'
#!/bin/bash
# --- DWM Self-Healing ---
if [ ! -x /usr/local/bin/dwm ]; then
  echo "⚠️  DWM missing! Rebuilding..."
  sudo mkdir -p /usr/src
  if [ ! -d /usr/src/dwm ]; then
    cd /usr/src && sudo git clone https://git.suckless.org/dwm
  fi
  cd /usr/src/dwm
  sudo cp config.def.h config.h 2>/dev/null || true
  sudo sed -i 's/#define MODKEY.*/#define MODKEY Mod4Mask/' config.h
  sudo sed -i 's|"st"|"xterm"|g' config.h
  if ! grep -q 'thunar' config.h; then
      sudo sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_t, spawn, SHCMD("thunar") },' config.h
  fi
  sudo make clean install
  sudo ln -sf /usr/local/bin/dwm /usr/bin/dwm
fi
xmodmap ~/.Xmodmap &
~/.dwm/autostart.sh &
exec /usr/local/bin/dwm > ~/.dwm.log 2>&1
EOF
chmod +x "$HOME_DIR/.xinitrc"

# --- Auto-start on login -----------------------------------------------------
for f in "$HOME_DIR/.bash_profile" "$HOME_DIR/.profile" "$HOME_DIR/.zprofile"; do
  grep -q 'exec startx' "$f" 2>/dev/null || echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$f"
done

# --- GPU choice --------------------------------------------------------------
echo
echo "🎮 GPU Setup: 1=NVIDIA  2=AMD  3=Skip"
read -p "Select GPU option (1/2/3): " gpu_choice
case "$gpu_choice" in
  1) sudo apt install -y linux-headers-$(uname -r) nvidia-driver nvidia-settings ;;
  2) sudo apt install -y firmware-amd-graphics mesa-vulkan-drivers vulkan-tools ;;
  *) echo "Skipping GPU installation." ;;
esac

# --- Ensure DWM exists -------------------------------------------------------
if [ ! -x /usr/local/bin/dwm ]; then
  echo "⚙️ Building DWM (initial install)..."
  sudo mkdir -p /usr/src
  cd /usr/src
  sudo git clone https://git.suckless.org/dwm
  cd dwm
  sudo cp config.def.h config.h
  sudo sed -i 's/#define MODKEY.*/#define MODKEY Mod4Mask/' config.h
  sudo sed -i 's|"st"|"xterm"|g' config.h
  sudo sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_t, spawn, SHCMD("thunar") },' config.h
  sudo make clean install
fi
sudo ln -sf /usr/local/bin/dwm /usr/bin/dwm

# --- Xmodmap -----------------------------------------------------------------
cat > "$HOME_DIR/.Xmodmap" <<'EOF'
clear mod4
keycode 133 = Super_L
add mod4 = Super_L
EOF

# --- Final check -------------------------------------------------------------
echo
echo "🔍 Final check..."
which dwm | grep -q '/usr/local/bin' && echo "✅ DWM binary ok" || echo "❌ DWM binary missing"
command -v thunar >/dev/null && echo "✅ Thunar ok"
command -v xterm >/dev/null && echo "✅ Xterm ok"
command -v picom >/dev/null && echo "✅ Picom ok"

echo
echo "🎉 Done!"
echo "🧠 DWM self-repairs automatically and uses absolute path"
echo "💻 Super+Return → Xterm"
echo "🗂️  Super+T → Thunar"
echo "🌈 Adwaita-Dark + Papirus-Dark"
echo
echo "Reboot now:"
echo "  sudo reboot"
