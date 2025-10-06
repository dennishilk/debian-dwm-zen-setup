#!/bin/bash
# ======================================================================
# 🧠 Debian 13 DWM Nerd OS Deluxe (v9.3)
# by Dennis Hilk & ChatGPT (GPT-5)
# ======================================================================

set -e

# ----------[ 0. User Detection ]---------------------------------------
if [ "$EUID" -eq 0 ]; then
  REAL_USER=$(logname)
  HOME_DIR=$(eval echo "~$REAL_USER")
else
  REAL_USER=$USER
  HOME_DIR=$HOME
fi
echo "👤 User: $REAL_USER | HOME=$HOME_DIR"

# ----------[ 1. VM / GPU Detection ]-----------------------------------
if systemd-detect-virt | grep -Eq "qemu|kvm|vmware|vbox"; then
  PICOM_BACKEND="xrender"
else
  PICOM_BACKEND="glx"
fi
echo "🖥️ Picom backend: $PICOM_BACKEND"

# ----------[ 2. Base Packages ]----------------------------------------
sudo apt update -y
sudo apt install -y \
  xorg feh picom build-essential git curl wget unzip ca-certificates \
  libx11-dev libxft-dev libxinerama-dev \
  zram-tools fish lxappearance thunar thunar-volman gvfs gvfs-backends gvfs-fuse \
  gtk2-engines-murrine adwaita-icon-theme-full papirus-icon-theme \
  fastfetch libnotify-bin imagemagick maim slop xclip \
  alsa-utils brightnessctl

# ----------[ 3. GPU Driver Selection ]---------------------------------
echo "🎮 GPU detection & setup"
echo "Do you want to install NVIDIA or AMD drivers? (nvidia / amd / skip)"
read -rp "→ " gpu_choice

case "$gpu_choice" in
  nvidia|NVIDIA)
    echo "🟩 Installing NVIDIA drivers..."
    sudo apt install -y firmware-misc-nonfree linux-headers-$(uname -r)
    sudo apt install -y nvidia-driver nvidia-settings vulkan-tools
    echo "✅ NVIDIA drivers installed. Run 'nvidia-smi' to verify."
    ;;
  amd|AMD)
    echo "🟥 Installing AMD drivers..."
    sudo apt install -y firmware-linux-nonfree linux-headers-$(uname -r)
    sudo apt install -y mesa-vulkan-drivers vulkan-tools libvulkan1 radeontop
    echo "✅ AMD drivers installed. Run 'vulkaninfo | grep driver' to verify."
    ;;
  skip|Skip|*)
    echo "⚙️ Skipping GPU driver installation."
    ;;
esac

# ----------[ 4. ZRAM Setup ]-------------------------------------------
sudo systemctl enable --now zramswap.service
sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
echo "✅ ZRAM enabled (50 %, zstd)"

# ----------[ 5. JetBrainsMono Nerd Font (user install) ]---------------
mkdir -p "$HOME_DIR/.local/share/fonts/nerd"
cd "$HOME_DIR/.local/share/fonts/nerd"
wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip -O JetBrainsMono.zip
unzip -o JetBrainsMono.zip >/dev/null 2>&1 || true
fc-cache -fv >/dev/null 2>&1
cd -
echo "✅ JetBrainsMono Nerd Font installed in ~/.local/share/fonts"

# ----------[ 6. Alacritty Config ]-------------------------------------
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

[shell]
program = "/usr/bin/fish"
args = ["--login"]
EOF

# ----------[ 7. Picom Config ]-----------------------------------------
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

# ----------[ 8. Wallpaper ]--------------------------------------------
sudo mkdir -p /usr/share/backgrounds
if [ -f "./coding-2.png" ]; then
  sudo cp ./coding-2.png /usr/share/backgrounds/wallpaper.png
else
  convert -size 1920x1080 xc:black /usr/share/backgrounds/wallpaper.png
fi

# ----------[ 9. Helper Scripts ]---------------------------------------
mkdir -p "$HOME_DIR/.local/bin"

# Control Center
cat > "$HOME_DIR/.local/bin/dwm-control.sh" <<'EOF'
#!/bin/bash
choice=$(printf "Update system\nRestart DWM\nBackup configs\nReboot system\nPower off\nExit X session" | dmenu -i -p "Control Center:")
case "$choice" in
  "Update system")
    notify-send "🧰 Update" "System update started…"
    alacritty -e bash -c "sudo apt update && sudo apt upgrade -y; echo; echo '✅ Update complete'; read -n 1 -s -p 'Press any key...'"
    notify-send "✅ Update complete" ;;
  "Restart DWM") pkill dwm ;;
  "Backup configs")
    OUT=~/dwm-backup-$(date +%F-%H%M).tar.gz
    tar -czf "$OUT" ~/.config/dwm ~/.config/dmenu ~/.config/slstatus ~/.config/fish ~/.dwm 2>/dev/null
    notify-send "💾 Backup complete" "$OUT" ;;
  "Reboot system") sudo reboot ;;
  "Power off") sudo poweroff ;;
  "Exit X session") pkill X ;;
esac
EOF
chmod +x "$HOME_DIR/.local/bin/dwm-control.sh"

# Quick Settings
cat > "$HOME_DIR/.local/bin/quick-settings.sh" <<'EOF'
#!/bin/bash
choice=$(printf "Volume +\nVolume -\nMute toggle\nBrightness +\nBrightness -\nNetwork info" | dmenu -i -p "Quick Settings:")
case "$choice" in
  "Volume +") amixer set Master 5%+ >/dev/null ;;
  "Volume -") amixer set Master 5%- >/dev/null ;;
  "Mute toggle") amixer set Master toggle >/dev/null ;;
  "Brightness +") brightnessctl set +5% >/dev/null ;;
  "Brightness -") brightnessctl set 5%- >/dev/null ;;
  "Network info") ip -br a | dmenu -i -p "Network:" ;;
esac
EOF
chmod +x "$HOME_DIR/.local/bin/quick-settings.sh"

# Fade Screen (no lock)
cat > "$HOME_DIR/.local/bin/screen-fade.sh" <<'EOF'
#!/bin/bash
WALL=/usr/share/backgrounds/wallpaper.png
TMPBG=/tmp/fade_screen.png
if [ -f "$WALL" ]; then
  convert "$WALL" -fill black -colorize 60% "$TMPBG"
else
  convert -size 1920x1080 xc:black "$TMPBG"
fi
feh --fullscreen --no-fehbg "$TMPBG" &
PID=$!
notify-send "🌌 Screen darkened" "Press any key to return."
read -n 1 -s
kill $PID 2>/dev/null
rm -f "$TMPBG"
EOF
chmod +x "$HOME_DIR/.local/bin/screen-fade.sh"

# Screenshot
cat > "$HOME_DIR/.local/bin/screenshot.sh" <<'EOF'
#!/bin/bash
mkdir -p ~/Pictures/Screenshots
FILE=~/Pictures/Screenshots/screenshot-$(date +%F-%H%M%S).png
maim -s "$FILE" && xclip -selection clipboard -t image/png -i "$FILE" && notify-send "📸 Screenshot saved" "$FILE"
EOF
chmod +x "$HOME_DIR/.local/bin/screenshot.sh"

# Maintenance
mkdir -p "$HOME_DIR/Logs"
cat > "$HOME_DIR/.local/bin/maintenance.sh" <<'EOF'
#!/bin/bash
LOG=~/Logs/maintenance-$(date +%F).log
{
echo "==== Maintenance $(date) ===="
sudo apt autoremove -y
sudo apt autoclean -y
sudo journalctl --vacuum-time=7d
sudo rm -rf /tmp/*
echo "Done."
} | tee -a "$LOG"
notify-send "🧹 Maintenance complete" "Log saved to ~/Logs"
EOF
chmod +x "$HOME_DIR/.local/bin/maintenance.sh"

# ----------[ 10. Build suckless stack – VM safe version ]--------------
for repo in dwm dmenu slstatus; do
  mkdir -p "$HOME_DIR/.config/$repo"
  if [ ! -d "$HOME_DIR/.config/$repo/.git" ]; then
    echo "📦 Cloning $repo ..."
    git clone https://git.suckless.org/$repo "$HOME_DIR/.config/$repo"
  fi
  cd "$HOME_DIR/.config/$repo"
  cp -f config.def.h config.h 2>/dev/null || true

  # ====== Patch DWM keybinds safely ======
  if [ "$repo" = "dwm" ]; then
    echo "⚙️  Patching DWM config ..."
    sed -i 's|#define MODKEY.*|#define MODKEY Mod4Mask|' config.h
    sed -i 's|"st"|"alacritty"|g' config.h

    START_LINE=$(grep -n "static Key keys" config.h | cut -d: -f1)
    END_LINE=$(grep -n "^};" config.h | grep -A1 "$START_LINE" | tail -n1 | cut -d: -f1)

    if [ -n "$START_LINE" ] && [ -n "$END_LINE" ]; then
      TMP_FILE=$(mktemp)
      head -n $((END_LINE - 1)) config.h > "$TMP_FILE"

      cat <<'KEYS' >> "$TMP_FILE"
    { MODKEY, XK_Return, spawn, SHCMD("alacritty") },
    { MODKEY, XK_t,      spawn, SHCMD("thunar") },
    { MODKEY, XK_m,      spawn, SHCMD("dwm-control.sh") },
    { MODKEY, XK_n,      spawn, SHCMD("quick-settings.sh") },
    { MODKEY, XK_l,      spawn, SHCMD("screen-fade.sh") },
    { MODKEY, XK_s,      spawn, SHCMD("screenshot.sh") },
KEYS

      tail -n +"$END_LINE" config.h >> "$TMP_FILE"
      mv "$TMP_FILE" config.h
    fi
  fi

  echo "🛠️  Building $repo ..."
  if ! make clean all; then
    echo "❌ Build failed for $repo"
    exit 1
  fi
done

# ----------[ 10.1 Safe Terminal Fallback for VMs ]---------------------
echo "🧩 Checking for Alacritty support..."
if ! alacritty --version >/dev/null 2>&1; then
  echo "⚠️  Alacritty not working (likely VM / no OpenGL). Installing xfce4-terminal fallback..."
  sudo apt install -y xfce4-terminal
  TERMINAL_CMD="xfce4-terminal"
else
  TERMINAL_CMD="alacritty"
fi

# Patch DWM terminal command automatically
DWM_CFG="$HOME_DIR/.config/dwm/config.h"
if [ -f "$DWM_CFG" ]; then
  echo "🔧 Setting terminal to: $TERMINAL_CMD"
  sed -i "s|\"st\"|\"$TERMINAL_CMD\"|g" "$DWM_CFG"
  sed -i "s|\"alacritty\"|\"$TERMINAL_CMD\"|g" "$DWM_CFG"
  cd "$HOME_DIR/.config/dwm"
  make clean all
fi

echo "✅ DWM terminal launcher configured for: $TERMINAL_CMD"
echo "───────────────────────────────────────────────"



# ----------[ 11. Autostart ]-------------------------------------------
mkdir -p "$HOME_DIR/.dwm"
cat > "$HOME_DIR/.dwm/autostart.sh" <<'EOF'
#!/bin/bash
xsetroot -solid black &
(sleep 2 && feh --no-fehbg --bg-scale /usr/share/backgrounds/wallpaper.png) &
picom --experimental-backends --config ~/.config/picom.conf &
~/.config/slstatus/slstatus &
EOF
chmod +x "$HOME_DIR/.dwm/autostart.sh"

cat > "$HOME_DIR/.xinitrc" <<'EOF'
#!/bin/bash
~/.dwm/autostart.sh &
exec ~/.config/dwm/dwm
EOF
chmod +x "$HOME_DIR/.xinitrc"

# ----------[ 12. Fish Shell Nerd Banner ]-------------------------------
sudo chsh -s /usr/bin/fish "$REAL_USER"
mkdir -p "$HOME_DIR/.config/fish"
cat > "$HOME_DIR/.config/fish/config.fish" <<'EOF'
set user (whoami)
set host (hostname)
set uptime_now (uptime -p | sed 's/up //')
set_color cyan
echo "───────────────────────────────────────────────"
echo "🐧 Welcome back, $user@$host"
echo "💻 Debian 13 | DWM + Alacritty | Fish Shell"
echo "🕒 Uptime: $uptime_now"
echo "───────────────────────────────────────────────"
set_color normal
if test -z "$DISPLAY" ; and test (tty) = "/dev/tty1"
  echo "🎨 Starting DWM..."
  exec startx
end
EOF

# ----------[ 13. Finish Banner ]----------------------------------------
clear
# ----------[ 12. Build Verification ]-----------------------------------
echo
echo "───────────────────────────────────────────────"
echo "🔍 Verifying DWM stack build integrity..."
echo "───────────────────────────────────────────────"

check_build() {
  local name="$1"
  local path="$2"
  if [ -x "$path" ]; then
    echo -e "✅  $name: OK ($path)"
  else
    echo -e "❌  $name: MISSING or not executable"
  fi
}

check_build "dwm" "$HOME_DIR/.config/dwm/dwm"
check_build "dmenu_run" "$HOME_DIR/.config/dmenu/dmenu_run"
check_build "slstatus" "$HOME_DIR/.config/slstatus/slstatus"

echo "───────────────────────────────────────────────"
if [ -x "$HOME_DIR/.config/dwm/dwm" ] && [ -x "$HOME_DIR/.config/dmenu/dmenu_run" ] && [ -x "$HOME_DIR/.config/slstatus/slstatus" ]; then
  echo "🎉 All suckless components built successfully!"
else
  echo "⚠️  One or more components failed. Try rebuilding manually:"
  echo "    cd ~/.config/dwm && make clean all"
  echo "    cd ~/.config/dmenu && make clean all"
  echo "    cd ~/.config/slstatus && make clean all"
fi
echo "───────────────────────────────────────────────"

echo "───────────────────────────────────────────────"
echo "✅ Installation complete – DWM Nerd OS v9.3"
echo "💻 Reboot and login → Fish auto-starts DWM"
echo "───────────────────────────────────────────────"
