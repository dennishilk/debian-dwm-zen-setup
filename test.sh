#!/bin/bash
# =============================================================
# 🧠 Debian 13 (Trixie) DWM Full Setup by Dennis Hilk
# Core: DWM + Zen Kernel + GPU (NVIDIA/AMD/None) + ZRAM + Alacritty (TOML)
# Style: Fonts + Powerline + Rofi + Conky + Arc GTK + Picom Blur + GRUB Theme
# Auto-detects VM vs native (switches Picom backend)
# =============================================================

set -e

### --- Detect User -----------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
    REAL_USER=$(logname)
    HOME_DIR=$(eval echo "~$REAL_USER")
else
    REAL_USER=$USER
    HOME_DIR=$HOME
fi
echo "👤 Detected user: $REAL_USER (home: $HOME_DIR)"

### --- Detect VM -------------------------------------------------------------
if systemd-detect-virt | grep -Eq "qemu|kvm|vmware|vbox"; then
    VM_MODE=true
    PICOM_BACKEND="xrender"
    echo "💻 VM detected → using Picom backend: xrender"
else
    VM_MODE=false
    PICOM_BACKEND="glx"
    echo "🧠 Native system → using Picom backend: glx"
fi

### --- Repositories ----------------------------------------------------------
echo "=== 🧩 Configuring Debian sources ==="
CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
sudo bash -c "cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian ${CODENAME} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${CODENAME}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${CODENAME}-backports main contrib non-free non-free-firmware
EOF"

sudo apt update && sudo apt full-upgrade -y

### --- Base + ZRAM -----------------------------------------------------------
echo "=== ⚙️ Base tools & ZRAM ==="
sudo apt install -y build-essential git curl wget nano unzip ca-certificates gnupg \
  lsb-release apt-transport-https zram-tools
sudo systemctl enable --now zramswap.service
sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap

### --- DWM & Zen Kernel ------------------------------------------------------
echo "=== 💻 Installing DWM + Zen Kernel ==="
sudo apt install -y xorg dwm suckless-tools feh picom slstatus mesa-utils vulkan-tools
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://liquorix.net/liquorix-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/liquorix-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/liquorix-keyring.gpg] http://liquorix.net/debian sid main" | \
  sudo tee /etc/apt/sources.list.d/liquorix.list
sudo apt update
sudo apt install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64 || true

### --- Wallpaper -------------------------------------------------------------
sudo mkdir -p /usr/share/backgrounds
if [ -f "./coding-2.png" ]; then
  sudo cp ./coding-2.png /usr/share/backgrounds/wallpaper.png
else
  echo "⚠️ coding-2.png not found — please copy later."
fi

### --- Alacritty -------------------------------------------------------------
echo "=== 🌈 Installing Alacritty ==="
sudo apt install -y alacritty || sudo apt install -y stterm
mkdir -p "$HOME_DIR/.config/alacritty"
cat > "$HOME_DIR/.config/alacritty/alacritty.toml" <<'EOF'
[window]
opacity = 0.8
background_opacity = 0.8
decorations = "none"
dynamic_title = true
padding = { x = 6, y = 4 }

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
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

### --- Picom --------------------------------------------------------------
mkdir -p "$HOME_DIR/.config"
cat > "$HOME_DIR/.config/picom.conf" <<EOF
backend = "${PICOM_BACKEND}";
vsync = true;
detect-rounded-corners = true;
detect-client-opacity = true;
use-damage = true;
corner-radius = 6;
shadow = true;
shadow-radius = 12;
shadow-color = "#00ccff";
shadow-opacity = 0.35;
opacity-rule = [ "90:class_g = 'Alacritty'" ];
fade-in-step = 0.03;
fade-out-step = 0.03;
blur-method = "dual_kawase";
blur-strength = 5;
fading = true;
inactive-opacity = 0.85;
active-opacity = 1.0;
EOF

### --- Autostart ------------------------------------------------------------
mkdir -p "$HOME_DIR/.dwm"
cat > "$HOME_DIR/.dwm/autostart.sh" <<'EOF'
#!/bin/bash
xsetroot -solid black &
feh --no-fehbg --bg-scale /usr/share/backgrounds/wallpaper.png &
picom --experimental-backends --config ~/.config/picom.conf &
slstatus &
(sleep 2 && alacritty &) &
(sleep 5 && conky &) &
EOF
chmod +x "$HOME_DIR/.dwm/autostart.sh"

cat > "$HOME_DIR/.xinitrc" <<'EOF'
#!/bin/bash
~/.dwm/autostart.sh &
exec dwm
EOF
chmod +x "$HOME_DIR/.xinitrc"

PROFILE="$HOME_DIR/.bash_profile"
grep -q startx "$PROFILE" 2>/dev/null || echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$PROFILE"

### --- GPU Wizard -----------------------------------------------------------
echo "🎮 GPU Setup (1=NVIDIA 2=AMD 3=Skip)"
read -p "Select: " gpu
case "$gpu" in
  1) sudo apt install -y linux-headers-$(uname -r) nvidia-driver nvidia-smi nvidia-settings \
        nvidia-cuda-toolkit libnvidia-encode1 ffmpeg nv-codec-headers ;;
  2) sudo apt install -y firmware-amd-graphics mesa-vulkan-drivers vulkan-tools \
        libdrm-amdgpu1 mesa-utils libgl1-mesa-dri ffmpeg mesa-va-drivers vainfo ;;
  *) echo "❎ Skipping GPU install." ;;
esac

### --- STYLE PACK -----------------------------------------------------------
echo "=== 🎨 Installing style pack ==="
sudo apt install -y fonts-firacode fonts-jetbrains-mono fonts-powerline powerline rofi \
                    conky-all lxappearance arc-theme papirus-icon-theme \
                    grub2-theme-starfield plymouth-themes

# Powerline
if ! grep -q "powerline.sh" "$HOME_DIR/.bashrc"; then
  echo 'if [ -f /usr/share/powerline/bindings/bash/powerline.sh ]; then
  source /usr/share/powerline/bindings/bash/powerline.sh
  fi' >> "$HOME_DIR/.bashrc"
fi

# Rofi config
mkdir -p "$HOME_DIR/.config/rofi"
cat > "$HOME_DIR/.config/rofi/config.rasi" <<'EOF'
configuration {
  modi: "drun,run";
  font: "JetBrainsMono Nerd Font 11";
  show-icons: true;
  icon-theme: "Papirus-Dark";
  theme: "Arc-Dark";
}
EOF

# Conky config
mkdir -p "$HOME_DIR/.config/conky"
cat > "$HOME_DIR/.config/conky/conky.conf" <<'EOF'
conky.config = {
    alignment = 'top_right',
    background = true,
    update_interval = 1,
    double_buffer = true,
    own_window = true,
    own_window_type = 'dock',
    own_window_argb_visual = true,
    own_window_argb_value = 180,
    draw_borders = false,
    draw_shades = false,
    use_xft = true,
    font = 'JetBrainsMono Nerd Font:size=10',
};
conky.text = [[
${time %H:%M:%S}
${execi 60 uname -r}
CPU: ${cpu}%  |  RAM: ${memperc}% 
Disk: ${fs_used_perc /}%  |  Uptime: ${uptime_short}
]];
EOF

# GTK
mkdir -p "$HOME_DIR/.config/gtk-3.0"
cat > "$HOME_DIR/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 11
EOF

# Plymouth
sudo plymouth-set-default-theme spinner
sudo update-initramfs -u

# --- Permissions fix ---------------------------------------------------------
sudo chown -R "$REAL_USER:$REAL_USER" "$HOME_DIR"

echo
echo "✅ Full DWM setup complete!"
if [ "$VM_MODE" = true ]; then
  echo "💻 VM mode → Picom uses Xrender (CPU transparency)"
else
  echo "🧠 Native → Picom uses GLX (GPU transparency)"
fi
echo "🎨 Includes Zen Kernel, Alacritty TOML, Blur, Rofi, Conky, GTK Dark"
echo "Reboot to enjoy your new desktop:"
echo "  sudo reboot"
