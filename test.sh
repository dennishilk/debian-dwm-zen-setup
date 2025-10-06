#!/bin/bash
# =============================================================
# 🧠 Debian 13 DWM Full Setup (Minimal Dark + GPU + Fonts + ZSH + Starship)
# by Dennis Hilk
# =============================================================

set -e

# --- Detect User -------------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
    REAL_USER=$(logname)
    HOME_DIR=$(eval echo "~$REAL_USER")
else
    REAL_USER=$USER
    HOME_DIR=$HOME
fi
echo "👤 Detected user: $REAL_USER (home: $HOME_DIR)"

# --- Detect VM ---------------------------------------------------------------
if systemd-detect-virt | grep -Eq "qemu|kvm|vmware|vbox"; then
    PICOM_BACKEND="xrender"
    echo "💻 VM detected – Picom backend: xrender"
else
    PICOM_BACKEND="glx"
    echo "🧠 Native system – Picom backend: glx"
fi

# --- Base install ------------------------------------------------------------
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y xorg dwm suckless-tools feh picom slstatus \
                    build-essential git curl wget zram-tools alacritty unzip \
                    plymouth-themes grub2-common zsh

# --- ZRAM --------------------------------------------------------------------
sudo systemctl enable --now zramswap.service
sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
echo "✅ ZRAM configured (zstd, 50 % RAM, prio 100)"

# --- Nerd Fonts --------------------------------------------------------------
echo "🔤 Installing JetBrainsMono Nerd Font..."
sudo mkdir -p /usr/share/fonts/truetype/nerd
cd /usr/share/fonts/truetype/nerd
sudo wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip
sudo unzip -o JetBrainsMono.zip >/dev/null
sudo fc-cache -fv >/dev/null
cd ~
echo "✅ Nerd Font installed successfully!"

# --- Alacritty config (soft colors) ------------------------------------------
mkdir -p "$HOME_DIR/.config/alacritty"
cat > "$HOME_DIR/.config/alacritty/alacritty.toml" <<'EOF'
[window]
opacity = 0.8
decorations = "none"
dynamic_title = true
padding = { x = 6, y = 4 }

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
size = 11.0

[colors.primary]
background = "0x0a0a0a"
foreground = "0xcccccc"

[colors.normal]
black   = "0x0a0a0a"
red     = "0xaa4444"
green   = "0x88aa88"
yellow  = "0xaaaa66"
blue    = "0x6688aa"
magenta = "0x996699"
cyan    = "0x66aaaa"
white   = "0xcccccc"

[colors.cursor]
text = "0x0a0a0a"
cursor = "0x00ff99"
EOF

# --- Picom config ------------------------------------------------------------
mkdir -p "$HOME_DIR/.config"
cat > "$HOME_DIR/.config/picom.conf" <<EOF
backend = "${PICOM_BACKEND}";
vsync = true;
detect-client-opacity = true;
corner-radius = 6;
shadow = true;
shadow-radius = 12;
shadow-color = "#00ff99";
shadow-opacity = 0.35;
blur-method = "dual_kawase";
blur-strength = 5;
fading = true;
inactive-opacity = 0.85;
active-opacity = 1.0;
EOF

# --- Wallpaper ---------------------------------------------------------------
sudo mkdir -p /usr/share/backgrounds
if [ -f "./coding-2.png" ]; then
  sudo cp ./coding-2.png /usr/share/backgrounds/wallpaper.png
  echo "✅ Wallpaper installed."
else
  echo "⚠️ coding-2.png not found — please copy later to /usr/share/backgrounds/wallpaper.png"
fi

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

if ! grep -q startx "$HOME_DIR/.bash_profile" 2>/dev/null; then
  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$HOME_DIR/.bash_profile"
fi

# --- GPU setup ---------------------------------------------------------------
echo
echo "🎮 GPU Setup"
echo "1 = NVIDIA"
echo "2 = AMD"
echo "3 = Skip"
read -p "Select GPU option (1/2/3): " gpu_choice

case "$gpu_choice" in
  1)
    sudo apt install -y linux-headers-$(uname -r) nvidia-driver nvidia-smi \
      nvidia-settings nvidia-cuda-toolkit libnvidia-encode1 ffmpeg nv-codec-headers ;;
  2)
    sudo apt install -y firmware-amd-graphics mesa-vulkan-drivers vulkan-tools \
      libdrm-amdgpu1 mesa-utils libgl1-mesa-dri ffmpeg mesa-va-drivers vainfo ;;
  *) echo "❎ Skipping GPU installation." ;;
esac

# --- ZSH + Oh My Zsh + Starship ---------------------------------------------
echo "💀 Installing ZSH + Oh-My-Zsh + Starship..."
sudo apt install -y git zsh curl

# Install Oh My Zsh headless
sudo -u "$REAL_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install ZSH plugins manually
sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME_DIR/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-autosuggestions.git "$HOME_DIR/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

# Install Starship
sudo curl -fsSL https://starship.rs/install.sh | sudo bash -s -- -y
mkdir -p "$HOME_DIR/.config"

# Configure ZSH to use Starship
cat > "$HOME_DIR/.zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git zsh-syntax-highlighting zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh
eval "$(starship init zsh)"
EOF

# Configure Starship (dark minimal)
cat > "$HOME_DIR/.config/starship.toml" <<'EOF'
add_newline = false
format = """$directory$git_branch$git_status$character"""
[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
[git_branch]
format = " [ $branch]($style)"
style = "bold dimmed green"
[git_status]
style = "dimmed red"
[directory]
style = "dimmed white"
truncation_length = 3
EOF

# Set default shell
sudo chsh -s /usr/bin/zsh "$REAL_USER"
sudo chown -R "$REAL_USER:$REAL_USER" "$HOME_DIR"
echo "✅ Installed ZSH + Oh-My-Zsh + Starship (minimal dark)."

# --- GRUB Dark Config --------------------------------------------------------
sudo bash -c "cat > /etc/default/grub <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR=$(lsb_release -i -s 2>/dev/null || echo Debian)
GRUB_CMDLINE_LINUX_DEFAULT='quiet splash'
GRUB_CMDLINE_LINUX=''
GRUB_TERMINAL=console
GRUB_GFXMODE=1024x768
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_COLOR_NORMAL='light-green/black'
GRUB_COLOR_HIGHLIGHT='black/light-green'
EOF"
sudo update-grub

# --- Plymouth ---------------------------------------------------------------
sudo plymouth-set-default-theme spinner
sudo update-initramfs -u

# --- Final message ----------------------------------------------------------
echo
echo "✅ Final Debian DWM + ZSH + Starship setup complete!"
echo "💻 Picom backend: ${PICOM_BACKEND}"
echo "🎮 GPU driver setup finished"
echo "🚀 Starship active with dark minimal theme"
echo "Reboot to enjoy your new clean setup:"
echo "  sudo reboot"
