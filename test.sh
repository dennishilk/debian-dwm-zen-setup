#!/bin/bash
# =============================================================
# 🧠 Debian 13 DWM Full Dark Setup (Dennis Hilk Auto-Fix Edition)
# Includes: self-healing DWM binary check
# =============================================================
set -e

# --- Detect user -------------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
    REAL_USER=$(logname)
    HOME_DIR=$(eval echo "~$REAL_USER")
else
    REAL_USER=$USER
    HOME_DIR=$HOME
fi
echo "👤 Detected user: $REAL_USER ($HOME_DIR)"

# --- Detect VM ---------------------------------------------------------------
if systemd-detect-virt | grep -Eq "qemu|kvm|vmware|vbox"; then
    PICOM_BACKEND="xrender"
else
    PICOM_BACKEND="glx"
fi
echo "💻 Picom backend: ${PICOM_BACKEND}"

# --- Remove Debian DWM package if present ------------------------------------
if dpkg -l | grep -q "^ii\s\+dwm"; then
    echo "⚙️ Removing Debian DWM package..."
    sudo apt remove --purge -y dwm
else
    echo "✅ No Debian DWM package installed."
fi

# --- Base install ------------------------------------------------------------
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y xorg feh picom slstatus build-essential git curl wget \
    zram-tools alacritty unzip plymouth-themes grub2-common zsh lxappearance \
    gtk2-engines-murrine adwaita-icon-theme-full papirus-icon-theme \
    thunar thunar-volman gvfs gvfs-backends gvfs-fuse

# --- ZRAM --------------------------------------------------------------------
sudo systemctl enable --now zramswap.service
sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
echo "✅ ZRAM configured"

# --- Nerd Font ---------------------------------------------------------------
sudo mkdir -p /usr/share/fonts/truetype/nerd
cd /usr/share/fonts/truetype/nerd
sudo wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip
sudo unzip -o JetBrainsMono.zip >/dev/null
sudo fc-cache -fv >/dev/null
cd ~
echo "✅ JetBrainsMono Nerd Font installed"

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

# --- Minimal Xinit + Self-Healing Binary Check -------------------------------
cat > "$HOME_DIR/.xinitrc" <<'EOF'
#!/bin/bash
# --- DWM Binary Self-Healing ---
if [ ! -x /usr/local/bin/dwm ]; then
  echo "⚠️ DWM missing! Rebuilding..."
  if [ -d /usr/src/dwm ]; then
    cd /usr/src/dwm && sudo make clean install
  elif [ -d ~/dwm ]; then
    cd ~/dwm && sudo make clean install
  else
    echo "❌ No DWM source found!"
  fi
fi

xmodmap ~/.Xmodmap &
~/.dwm/autostart.sh &
exec dwm > ~/.dwm.log 2>&1
EOF
chmod +x "$HOME_DIR/.xinitrc"

# --- Auto-start DWM on login -------------------------------------------------
for f in "$HOME_DIR/.bash_profile" "$HOME_DIR/.profile" "$HOME_DIR/.zprofile"; do
    if ! grep -q 'exec startx' "$f" 2>/dev/null; then
        echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$f"
    fi
done
echo "✅ Auto-start configured (TTY1 login launches DWM)"

# --- GPU setup ---------------------------------------------------------------
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
echo "✅ ZSH + Starship ready"

# --- GTK Dark Theme ----------------------------------------------------------
mkdir -p "$HOME_DIR/.config/gtk-3.0" "$HOME_DIR/.config/gtk-4.0"
cat > "$HOME_DIR/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 10
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
EOF
cp "$HOME_DIR/.config/gtk-3.0/settings.ini" "$HOME_DIR/.config/gtk-4.0/settings.ini"

# --- Clone + Build DWM -------------------------------------------------------
if [ ! -d "/usr/src/dwm" ]; then
    sudo git clone https://git.suckless.org/dwm /usr/src/dwm
fi
cd /usr/src/dwm
sudo cp config.def.h config.h
sudo sed -i 's/#define MODKEY.*/#define MODKEY Mod4Mask/' config.h
sudo sed -i 's|"st"|"alacritty"|g' config.h
if ! grep -q 'thunar' config.h; then
    sudo sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_t, spawn, SHCMD("thunar") },' config.h
fi
sudo make clean install
sudo ln -sf /usr/local/bin/dwm /usr/bin/dwm
echo "✅ Custom DWM installed and symlinked"

# --- Mod4 key mapping --------------------------------------------------------
cat > "$HOME_DIR/.Xmodmap" <<'EOF'
clear mod4
keycode 133 = Super_L
add mod4 = Super_L
EOF

# --- Self-healing DWM check script ------------------------------------------
sudo tee /usr/local/bin/verify_dwm_binary.sh >/dev/null <<'EOF'
#!/bin/bash
# Auto-check DWM binary at each boot
if [ ! -x /usr/local/bin/dwm ]; then
  echo "⚠️ DWM binary missing, attempting rebuild..."
  if [ -d /usr/src/dwm ]; then
    cd /usr/src/dwm && make clean install
  elif [ -d ~/dwm ]; then
    cd ~/dwm && make clean install
  else
    echo "❌ DWM source not found!"
  fi
fi
EOF
sudo chmod +x /usr/local/bin/verify_dwm_binary.sh

# Add to startup
if ! grep -q verify_dwm_binary "$HOME_DIR/.bash_profile"; then
  echo "/usr/local/bin/verify_dwm_binary.sh &" >> "$HOME_DIR/.bash_profile"
fi

# --- GRUB Dark ---------------------------------------------------------------
sudo bash -c "cat > /etc/default/grub <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT='quiet splash'
GRUB_TERMINAL=console
GRUB_GFXMODE=1024x768
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_COLOR_NORMAL='light-green/black'
GRUB_COLOR_HIGHLIGHT='black/light-green'
EOF"
sudo update-grub
sudo plymouth-set-default-theme spinner
sudo update-initramfs -u

sudo chown -R "$REAL_USER:$REAL_USER" "$HOME_DIR"

# --- Self-check --------------------------------------------------------------
echo
echo "🔍 Running final checks..."
which dwm | grep -q '/usr/local/bin' && echo "✅ DWM binary correct" || echo "❌ DWM binary incorrect"
grep -q 'thunar' /usr/src/dwm/config.h && echo "✅ Super+T active" || echo "❌ Super+T missing"
grep -q 'alacritty' /usr/src/dwm/config.h && echo "✅ Super+Return active" || echo "❌ Terminal missing"
command -v starship >/dev/null && echo "✅ Starship installed"
command -v thunar >/dev/null && echo "✅ Thunar installed"
command -v picom >/dev/null && echo "✅ Picom installed"

echo
echo "🎉 Installation complete!"
echo "🧠 DWM auto-starts & self-repairs at login"
echo "💻 Super+Return → Alacritty"
echo "🗂️  Super+T → Thunar"
echo "🌈 GTK: Adwaita-dark + Papirus-Dark"
echo
echo "Reboot now:"
echo "  sudo reboot"
