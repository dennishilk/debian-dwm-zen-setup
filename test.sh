#!/bin/bash
# =============================================================
# 🧠 Debian 13 DWM Full Dark Setup (Dennis Hilk Auto-Fix v8)
#  - DWM self-healing + absolute path
#  - Safe Mode (for GPU-less VMs)
#  - Alacritty + transparent config
#  - ZSH + Oh My ZSH + Starship
# =============================================================
set -e

if [ "$EUID" -eq 0 ]; then
  REAL_USER=$(logname)
  HOME_DIR=$(eval echo "~$REAL_USER")
else
  REAL_USER=$USER
  HOME_DIR=$HOME
fi
echo "👤 User: $REAL_USER ($HOME_DIR)"

# --- Detect VM/GPU ----------------------------------------------------------
SAFE_MODE=false
if systemd-detect-virt | grep -Eq "qemu|kvm|vmware|vbox"; then
  PICOM_BACKEND="xrender"
  SAFE_MODE=true
else
  PICOM_BACKEND="glx"
  if ! lspci | grep -qiE 'vga|3d|nvidia|amd|intel'; then SAFE_MODE=true; fi
fi
if $SAFE_MODE; then
  echo "🧩 Safe Mode: no GPU detected → using xterm & no picom"
else
  echo "💻 GPU detected → normal mode with Alacritty & Picom"
fi

# --- Base system packages ---------------------------------------------------
sudo apt update -y
sudo apt install -y xorg feh picom slstatus build-essential git curl wget unzip \
  libx11-dev libxft-dev libxinerama-dev zram-tools zsh lxappearance \
  gtk2-engines-murrine adwaita-icon-theme-full papirus-icon-theme \
  thunar thunar-volman gvfs gvfs-backends gvfs-fuse ca-certificates

# --- ZRAM -------------------------------------------------------------------
sudo systemctl enable --now zramswap.service
sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
echo "✅ ZRAM configured"

# --- Nerd Font --------------------------------------------------------------
echo "📦 Installing JetBrains Mono Nerd Font..."
sudo mkdir -p /usr/share/fonts/truetype/nerd
cd /usr/share/fonts/truetype/nerd
URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"
sudo wget -q "$URL" -O JetBrainsMono.zip || true
sudo unzip -o JetBrainsMono.zip >/dev/null 2>&1 || true
sudo fc-cache -fv >/dev/null 2>&1
cd ~

# --- Alacritty --------------------------------------------------------------
sudo apt install -y alacritty
mkdir -p "$HOME_DIR/.config/alacritty"
cat > "$HOME_DIR/.config/alacritty/alacritty.toml" <<'EOF'
[window]
opacity = 0.85
decorations = "none"
padding = { x = 8, y = 6 }
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

# --- Picom ------------------------------------------------------------------
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

# --- Wallpaper --------------------------------------------------------------
sudo mkdir -p /usr/share/backgrounds
[ -f "./coding-2.png" ] && sudo cp ./coding-2.png /usr/share/backgrounds/wallpaper.png

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
cat >> "$HOME_DIR/.dwm/autostart.sh" <<'EOF'
slstatus &
(sleep 2 && alacritty &) &
EOF
chmod +x "$HOME_DIR/.dwm/autostart.sh"

# --- .xinitrc ---------------------------------------------------------------
cat > "$HOME_DIR/.xinitrc" <<'EOF'
#!/bin/bash
if [ ! -x /usr/local/bin/dwm ]; then
  echo "⚙️ Rebuilding DWM..."
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
exec /usr/local/bin/dwm > ~/.dwm.log 2>&1
EOF
chmod +x "$HOME_DIR/.xinitrc"

# --- Auto start on login ----------------------------------------------------
for f in "$HOME_DIR/.bash_profile" "$HOME_DIR/.profile" "$HOME_DIR/.zprofile"; do
  grep -q 'exec startx' "$f" 2>/dev/null || echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$f"
done

# --- GPU packages -----------------------------------------------------------
echo
echo "🎮 GPU Setup: 1=NVIDIA  2=AMD  3=Skip"
read -p "Select GPU option (1/2/3): " gpu_choice
case "$gpu_choice" in
  1) sudo apt install -y linux-headers-$(uname -r) nvidia-driver nvidia-settings ;;
  2) sudo apt install -y firmware-amd-graphics mesa-vulkan-drivers vulkan-tools ;;
  *) echo "Skipping GPU installation." ;;
esac

# --- Build DWM --------------------------------------------------------------
if [ ! -x /usr/local/bin/dwm ]; then
  sudo mkdir -p /usr/src && cd /usr/src
  sudo git clone https://git.suckless.org/dwm
  cd dwm
  sudo cp config.def.h config.h
  sudo sed -i 's/#define MODKEY.*/#define MODKEY Mod4Mask/' config.h
  sudo sed -i 's|"st"|"alacritty"|g' config.h
  sudo sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_t, spawn, SHCMD("thunar") },' config.h
  sudo make clean install
fi
sudo ln -sf /usr/local/bin/dwm /usr/bin/dwm

# --- ZSH + Starship ---------------------------------------------------------
echo "🐚 Installing ZSH + Starship..."
sudo apt install -y zsh git curl
if [ ! -d "$HOME_DIR/.oh-my-zsh" ]; then
  sudo -u "$REAL_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME_DIR/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-autosuggestions.git "$HOME_DIR/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
fi
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
command -v alacritty >/dev/null && echo "✅ Alacritty ok"
command -v thunar >/dev/null && echo "✅ Thunar ok"
command -v picom >/dev/null && echo "✅ Picom ok"
command -v zsh >/dev/null && echo "✅ ZSH ok"
command -v starship >/dev/null && echo "✅ Starship ok"
echo
echo "🎉 Installation complete!"
echo "🧠 DWM repairs itself on login"
echo "💻 Super+Return → Alacritty"
echo "🗂️  Super+T → Thunar"
echo "🌈 Adwaita-Dark + Papirus-Dark"
echo
echo "Reboot now:"
echo "  sudo reboot"
