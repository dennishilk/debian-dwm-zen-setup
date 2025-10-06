#!/bin/bash
# =============================================================
# 🧠 Debian 13 DWM Full Dark Setup (Dennis Hilk Final Edition)
# Includes: ZSH + Starship, Thunar, Alacritty, Auto-start + Keybind fix
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

# --- Base system -------------------------------------------------------------
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y xorg dwm suckless-tools feh picom slstatus \
    build-essential git curl wget zram-tools alacritty unzip \
    plymouth-themes grub2-common zsh lxappearance gtk2-engines-murrine \
    adwaita-icon-theme-full papirus-icon-theme thunar thunar-volman \
    gvfs gvfs-backends gvfs-fuse

# --- ZRAM --------------------------------------------------------------------
sudo systemctl enable --now zramswap.service
sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
echo "✅ ZRAM enabled"

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

cat > "$HOME_DIR/.xinitrc" <<'EOF'
#!/bin/bash
~/.dwm/autostart.sh &
exec dwm
EOF
chmod +x "$HOME_DIR/.xinitrc"

# --- Auto-start DWM on login -------------------------------------------------
for f in "$HOME_DIR/.bash_profile" "$HOME_DIR/.profile" "$HOME_DIR/.zprofile"; do
    if ! grep -q 'exec startx' "$f" 2>/dev/null; then
        echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$f"
        echo "→ Added auto-start line to $f"
    fi
done
echo "✅ Auto-start configured (no manual startx needed)"

# --- GPU setup ---------------------------------------------------------------
echo
echo "🎮 GPU Setup: 1=NVIDIA  2=AMD  3=Skip"
read -p "Select GPU option (1/2/3): " gpu_choice
case "$gpu_choice" in
  1) sudo apt install -y linux-headers-$(uname -r) nvidia-driver nvidia-smi \
         nvidia-settings nvidia-cuda-toolkit libnvidia-encode1 ffmpeg nv-codec-headers ;;
  2) sudo apt install -y firmware-amd-graphics mesa-vulkan-drivers vulkan-tools \
         libdrm-amdgpu1 mesa-utils libgl1-mesa-dri ffmpeg mesa-va-drivers vainfo ;;
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

mkdir -p "$HOME_DIR/.config"
cat > "$HOME_DIR/.config/starship.toml" <<'EOF'
add_newline = false
format = """$directory$git_branch$git_status$character"""
[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
[directory]
style = "dimmed white"
truncation_length = 3
[git_branch]
format = " [ $branch]($style)"
style = "bold dimmed green"
[git_status]
style = "dimmed red"
EOF

sudo chsh -s /usr/bin/zsh "$REAL_USER"
echo "✅ ZSH + Starship installed"

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
echo "✅ GTK Dark Theme enabled (Adwaita-dark + Papirus-Dark)"

# --- Fix DWM keybinds --------------------------------------------------------
if [ -d "/usr/src/dwm" ]; then
    DWM_DIR="/usr/src/dwm"
elif [ -d "$HOME_DIR/dwm" ]; then
    DWM_DIR="$HOME_DIR/dwm"
else
    echo "⚠️  DWM source not found, skipping keybind patch."
    DWM_DIR=""
fi

if [ -n "$DWM_DIR" ]; then
    echo "🔧 Updating DWM keybinds..."
    cd "$DWM_DIR"
    sudo cp config.h config.h.bak
    if grep -q '"st"' config.h; then
        sudo sed -i 's|"st"|"alacritty"|g' config.h
    fi
    if ! grep -q 'thunar' config.h; then
        sudo sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_t, spawn, SHCMD("thunar") },' config.h
    fi
    if ! grep -q 'XK_Return' config.h; then
        cat <<'EOF' | sudo tee -a config.h >/dev/null
static const char *termcmd[]  = { "alacritty", NULL };
static Key keys[] = {
    { MODKEY, XK_Return, spawn, {.v = termcmd } },
    { MODKEY, XK_t,      spawn, SHCMD("thunar") },
};
EOF
    fi
    sudo make clean install
    echo "✅ DWM rebuilt with working Super+Return and Super+T"
fi

# --- GRUB + Plymouth ---------------------------------------------------------
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

# --- Final summary -----------------------------------------------------------
sudo chown -R "$REAL_USER:$REAL_USER" "$HOME_DIR"
echo
echo "🎉 Installation complete!"
echo "💻 Auto-start: DWM starts automatically on login (no startx)"
echo "💀 ZSH + Starship prompt ready"
echo "🗂️  Super+T → Thunar (dark theme)"
echo "💻 Super+Return → Alacritty"
echo "🌈 GTK: Adwaita-dark + Papirus-Dark"
echo
echo "Reboot now to enjoy your new desktop:"
echo "  sudo reboot"
