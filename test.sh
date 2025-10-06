#!/bin/bash
# =============================================================
# 🧠 Debian 13 DWM Full Dark Setup (Dennis Hilk Auto-Fix v7)
#  - Fixes "exec dwm not found"
#  - Includes X11 dev libs
#  - Safe Mode for GPU-less VMs (uses xterm + no picom/feh)
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

# --- detect VM / GPU --------------------------------------------------------
SAFE_MODE=false
if systemd-detect-virt | grep -Eq "qemu|kvm|vmware|vbox"; then
  PICOM_BACKEND="xrender"
  SAFE_MODE=true
else
  PICOM_BACKEND="glx"
  # test GPU presence
  if ! lspci | grep -qiE 'vga|3d|nvidia|amd|intel'; then SAFE_MODE=true; fi
fi

if $SAFE_MODE; then
  echo "🧩 Safe Mode enabled – no GPU detected → using xterm & no picom"
else
  echo "💻 GPU detected → normal mode with Alacritty & Picom"
fi

# --- base packages + dev libs -----------------------------------------------
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y xorg feh picom slstatus build-essential git curl wget unzip \
  libx11-dev libxft-dev libxinerama-dev \
  zram-tools plymouth-themes grub2-common zsh lxappearance \
  gtk2-engines-murrine adwaita-icon-theme-full papirus-icon-theme \
  thunar thunar-volman gvfs gvfs-backends gvfs-fuse ca-certificates

# --- ZRAM --------------------------------------------------------------------
sudo systemctl enable --now zramswap.service
sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
echo "✅ ZRAM configured"

# --- JetBrains Mono Nerd Font ----------------------------------------------
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
      success=true; break
  fi
done
if [ "$success" = true ]; then
  sudo unzip -o JetBrainsMono.zip >/dev/null 2>&1 || true
  sudo fc-cache -fv >/dev/null
  echo "✅ JetBrains Mono Nerd Font installed"
else
  echo "⚠️ Font download failed – place JetBrainsMono.zip manually in /usr/share/fonts/truetype/nerd/"
fi
cd ~

# --- Terminal choice --------------------------------------------------------
if $SAFE_MODE; then TERM_CMD="xterm"; else TERM_CMD="alacritty"; fi

# --- Autostart --------------------------------------------------------------
mkdir -p "$HOME_DIR/.dwm"
cat > "$HOME_DIR/.dwm/autostart.sh" <<EOF
#!/bin/bash
xsetroot -solid black &
EOF
if ! $SAFE_MODE; then
cat >> "$HOME_DIR/.dwm/autostart.sh" <<'EOF'
feh --no-fehbg --bg-scale /usr/share/backgrounds/wallpaper.png &
picom --experimental-backends --config ~/.config/picom.conf &
EOF
fi
cat >> "$HOME_DIR/.dwm/autostart.sh" <<EOF
slstatus &
(sleep 2 && ${TERM_CMD} &) &
EOF
chmod +x "$HOME_DIR/.dwm/autostart.sh"

# --- .xinitrc with absolute path -------------------------------------------
cat > "$HOME_DIR/.xinitrc" <<EOF
#!/bin/bash
if [ ! -x /usr/local/bin/dwm ]; then
  echo "⚠️ DWM missing – rebuilding..."
  sudo mkdir -p /usr/src
  if [ ! -d /usr/src/dwm ]; then
    cd /usr/src && sudo git clone https://git.suckless.org/dwm
  fi
  cd /usr/src/dwm
  sudo cp config.def.h config.h 2>/dev/null || true
  sudo sed -i 's/#define MODKEY.*/#define MODKEY Mod4Mask/' config.h
  sudo sed -i 's|"st"|"${TERM_CMD}"|g' config.h
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

# --- Auto-start on login ---------------------------------------------------
for f in "$HOME_DIR/.bash_profile" "$HOME_DIR/.profile" "$HOME_DIR/.zprofile"; do
  grep -q 'exec startx' "$f" 2>/dev/null || echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$f"
done

# --- Build DWM once --------------------------------------------------------
if [ ! -x /usr/local/bin/dwm ]; then
  sudo mkdir -p /usr/src && cd /usr/src
  sudo git clone https://git.suckless.org/dwm
  cd dwm
  sudo cp config.def.h config.h
  sudo sed -i 's/#define MODKEY.*/#define MODKEY Mod4Mask/' config.h
  sudo sed -i "s|\"st\"|\"${TERM_CMD}\"|g" config.h
  sudo sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_t, spawn, SHCMD("thunar") },' config.h
  sudo make clean install
fi
sudo ln -sf /usr/local/bin/dwm /usr/bin/dwm

# --- Xmodmap ---------------------------------------------------------------
cat > "$HOME_DIR/.Xmodmap" <<'EOF'
clear mod4
keycode 133 = Super_L
add mod4 = Super_L
EOF

# --- Final check ------------------------------------------------------------
echo
echo "🔍 Final check..."
which dwm | grep -q '/usr/local/bin' && echo "✅ DWM binary ok" || echo "❌ DWM binary missing"
command -v ${TERM_CMD} >/dev/null && echo "✅ Terminal (${TERM_CMD}) ok"
command -v thunar >/dev/null && echo "✅ Thunar ok"
command -v picom >/dev/null && echo "✅ Picom ok (optional)"
echo
echo "🎉 Done!"
if $SAFE_MODE; then
  echo "🧠 Started in Safe Mode – no GPU effects, xterm only"
else
  echo "💻 Normal Mode – with Picom + Alacritty"
fi
echo
echo "Reboot now:"
echo "  sudo reboot"
