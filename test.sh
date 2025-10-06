#!/bin/bash
# =============================================================
# 🧠 Debian 13 DWM Full Dark Setup (Dennis Hilk Auto-Fix v4)
# Features:
#  - DWM Self-Healing + Binary Auto-Rebuild
#  - Nerd Font Mirror Fallback + Offline Support
#  - GPU optional (NVIDIA / AMD / Skip)
#  - ZSH + Starship + Thunar + Alacritty
# =============================================================
set -e

if [ "$EUID" -eq 0 ]; then
    REAL_USER=$(logname)
    HOME_DIR=$(eval echo "~$REAL_USER")
else
    REAL_USER=$USER
    HOME_DIR=$HOME
fi
echo "👤 User: $REAL_USER"

if systemd-detect-virt | grep -Eq "qemu|kvm|vmware|vbox"; then
    PICOM_BACKEND="xrender"
else
    PICOM_BACKEND="glx"
fi

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

# --- Nerd Font with Mirror Fallback ------------------------------------------
echo "📦 Installing JetBrainsMono Nerd Font..."
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
  if wget --timeout=30 --show-progress -q "$URL" -O JetBrainsMono.zip || curl -L --max-time 30 -o JetBrainsMono.zip "$URL"; then
      echo "✅ Downloaded from $URL"
      success=true
      break
  fi
done

if [ "$success" = true ]; then
    sudo unzip -o JetBrainsMono.zip >/dev/null 2>&1 || true
    sudo fc-cache -fv >/dev/null
    echo "✅ JetBrainsMono Nerd Font installed successfully"
elif [ -f "./JetBrainsMono.zip" ]; then
    echo "💾 Found local JetBrainsMono.zip – installing offline..."
    sudo unzip -o JetBrainsMono.zip >/dev/null 2>&1
    sudo fc-cache -fv >/dev/null
    echo "✅ Installed from local archive"
else
    echo "⚠️  All font mirrors failed. You can place JetBrainsMono.zip here manually:"
    echo "    /usr/share/fonts/truetype/nerd/"
fi
cd ~

# --- Alacritty config --------------------------------------------------------
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

# --- Picom config ------------------------------------------------------------
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
(sleep 2 && alacritty &) &
EOF
chmod +x "$HOME_DIR/.dwm/autostart.sh"

# --- .xinitrc with self-repair ----------------------------------------------
cat > "$HOME_DIR/.xinitrc" <<'EOF'
#!/bin/bash
if [ ! -x /usr/local/bin/dwm ]; then
  echo "⚠️  DWM missing! Rebuilding..."
  sudo mkdir -p /usr/src
  if [ ! -d /usr/src/dwm ]; then
    cd /usr/src && sudo git clone https://git.suckless.org/dwm
  fi
  cd /usr/src/dwm
  sudo cp config.def.h config.h 2>/dev/null || true
  sudo sed -i 's/#define MODKEY.*/#define MODKEY Mod4Mask/' config.h
  sudo sed -i 's|"st"|"alacritty"|g' config.h
  if ! grep -q 'thunar' config.h; then
      sudo sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_t, spawn, SHCMD("thunar") },' config.h
  fi
  sudo make clean install
  sudo ln -sf /usr/local/bin/dwm /usr/bin/dwm
fi
xmodmap ~/.Xmodmap &
~/.dwm/autostart.sh &
exec dwm > ~/.dwm.log 2>&1
EOF
chmod +x "$HOME_DIR/.xinitrc"

# --- Auto start on login -----------------------------------------------------
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

# --- ZSH + Starship ----------------------------------------------------------
sudo apt install -y git zsh curl
sudo -u "$REAL_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME_DIR/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-autosuggestions.git "$HOME_DIR/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
bash <(curl -fsSL https://starship.rs/install.sh) -y >/dev/null 2>&1
cat > "$HOME_DIR/.zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
plugins=(git zsh-syntax-highlighting zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh
eval "$(starship init zsh)"
EOF
sudo chsh -s /usr/bin/zsh "$REAL_USER"

# --- GTK Dark ---------------------------------------------------------------
mkdir -p "$HOME_DIR/.config/gtk-3.0" "$HOME_DIR/.config/gtk-4.0"
cat > "$HOME_DIR/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 10
gtk-application-prefer-dark-theme=1
EOF
cp "$HOME_DIR/.config/gtk-3.0/settings.ini" "$HOME_DIR/.config/gtk-4.0/settings.ini"

# --- DWM ensure build --------------------------------------------------------
if [ ! -d "/usr/src/dwm" ]; then
    sudo mkdir -p /usr/src && cd /usr/src
    sudo git clone https://git.suckless.org/dwm
fi
cd /usr/src/dwm
sudo cp config.def.h config.h
sudo sed -i 's/#define MODKEY.*/#define MODKEY Mod4Mask/' config.h
sudo sed -i 's|"st"|"alacritty"|g' config.h
sudo sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_t, spawn, SHCMD("thunar") },' config.h
sudo make clean install
sudo ln -sf /usr/local/bin/dwm /usr/bin/dwm

# --- Xmodmap -----------------------------------------------------------------
cat > "$HOME_DIR/.Xmodmap" <<'EOF'
clear mod4
keycode 133 = Super_L
add mod4 = Super_L
EOF

# --- Final checks ------------------------------------------------------------
echo
echo "🔍 Final check..."
which dwm | grep -q '/usr/local/bin' && echo "✅ DWM binary ok" || echo "❌ DWM binary missing"
command -v thunar >/dev/null && echo "✅ Thunar ok"
command -v alacritty >/dev/null && echo "✅ Alacritty ok"
command -v picom >/dev/null && echo "✅ Picom ok"
command -v starship >/dev/null && echo "✅ Starship ok"

echo
echo "🎉 Done!"
echo "🧠 DWM self-repairs automatically"
echo "💻 Super+Return → Alacritty"
echo "🗂️  Super+T → Thunar"
echo "🌈 Adwaita-Dark + Papirus-Dark"
echo
echo "Reboot:"
echo "  sudo reboot"
