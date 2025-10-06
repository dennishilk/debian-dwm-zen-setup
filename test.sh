#!/bin/bash
# ======================================================================
# 🧠  Debian 13 DWM – Nerd OS Deluxe (v9.1, clean edition)
# by Dennis Hilk & ChatGPT (GPT-5)
# ======================================================================

set -e

# ----------[ 0. User / Env Detection ]---------------------------------
if [ "$EUID" -eq 0 ]; then
  REAL_USER=$(logname)
  HOME_DIR=$(eval echo "~$REAL_USER")
else
  REAL_USER=$USER
  HOME_DIR=$HOME
fi
echo "👤  User: $REAL_USER | HOME=$HOME_DIR"

# ----------[ 1. GPU / VM Detection → Picom Backend ]-------------------
SAFE_MODE=false
if systemd-detect-virt | grep -Eq "qemu|kvm|vmware|vbox"; then
  PICOM_BACKEND="xrender"
  SAFE_MODE=true
else
  PICOM_BACKEND="glx"
fi
echo "🖥️  Picom backend: $PICOM_BACKEND"

# ----------[ 2. Base System Packages ]---------------------------------
sudo apt update -y
sudo apt install -y \
  xorg feh picom build-essential git curl wget unzip ca-certificates \
  libx11-dev libxft-dev libxinerama-dev \
  zram-tools fish lxappearance thunar thunar-volman gvfs gvfs-backends gvfs-fuse \
  gtk2-engines-murrine adwaita-icon-theme-full papirus-icon-theme \
  fastfetch libnotify-bin imagemagick maim slop xclip \
  alsa-utils brightnessctl

# ----------[ 3. ZRAM Setup ]-------------------------------------------
sudo systemctl enable --now zramswap.service
sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
echo "✅  ZRAM enabled (50 %, zstd)"

# ----------[ 4. Nerd Font ]--------------------------------------------
sudo mkdir -p /usr/share/fonts/truetype/nerd
cd /usr/share/fonts/truetype/nerd
wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip -O JetBrainsMono.zip
unzip -o JetBrainsMono.zip >/dev/null 2>&1 || true
fc-cache -fv >/dev/null 2>&1
cd -

# ----------[ 5. Alacritty Config ]-------------------------------------
sudo apt install -y alacritty
mkdir -p "$HOME_DIR/.config/alacritty"
rm -f "$HOME_DIR/.config/alacritty/alacritty.yml" 2>/dev/null || true
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

# ----------[ 6. Picom Config ]-----------------------------------------
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

# ----------[ 7. Wallpaper ]--------------------------------------------
sudo mkdir -p /usr/share/backgrounds
if [ -f "./coding-2.png" ]; then
  sudo cp ./coding-2.png /usr/share/backgrounds/wallpaper.png
else
  convert -size 1920x1080 xc:black /usr/share/backgrounds/wallpaper.png
fi

# ----------[ 8. Helper Scripts ]---------------------------------------
mkdir -p "$HOME_DIR/.local/bin"

# 8.1 Control Center
cat > "$HOME_DIR/.local/bin/dwm-control.sh" <<'EOF'
#!/bin/bash
choice=$(printf "Update system\nRestart DWM\nBackup configs\nReboot system\nPower off\nExit X session" | dmenu -i -p "Control Center:")
case "$choice" in
  "Update system")
    notify-send "🧰 Update" "System update started…"
    alacritty -e bash -c "sudo apt update && sudo apt upgrade -y; echo; echo '✅ Update complete'; read -n 1 -s -p 'Press any key...'"
    notify-send "✅ Update complete"
    ;;
  "Restart DWM") pkill dwm ;;
  "Backup configs")
    OUT=~/dwm-backup-$(date +%F-%H%M).tar.gz
    tar -czf "$OUT" ~/.config/dwm ~/.config/dmenu ~/.config/slstatus ~/.config/fish ~/.dwm 2>/dev/null
    notify-send "💾 Backup complete" "$OUT"
    ;;
  "Reboot system") sudo reboot ;;
  "Power off") sudo poweroff ;;
  "Exit X session") pkill X ;;
esac
EOF
chmod +x "$HOME_DIR/.local/bin/dwm-control.sh"

# 8.2 Quick Settings
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

# 8.3 Screen Fade (no lock)
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

# 8.4 Screenshot
cat > "$HOME_DIR/.local/bin/screenshot.sh" <<'EOF'
#!/bin/bash
mkdir -p ~/Pictures/Screenshots
FILE=~/Pictures/Screenshots/screenshot-$(date +%F-%H%M%S).png
maim -s "$FILE" && xclip -selection clipboard -t image/png -i "$FILE" && notify-send "📸 Screenshot" "$FILE"
EOF
chmod +x "$HOME_DIR/.local/bin/screenshot.sh"

# 8.5 Maintenance
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

# ----------[ 9. DWM / DMENU / SLSTATUS ]-------------------------------
for repo in dwm dmenu slstatus; do
  mkdir -p "$HOME_DIR/.config/$repo"
  git clone https://git.suckless.org/$repo "$HOME_DIR/.config/$repo"
  cd "$HOME_DIR/.config/$repo"
  cp config.def.h config.h 2>/dev/null || true
  if [ "$repo" = "dwm" ]; then
    sed -i 's/#define MODKEY.*/#define MODKEY Mod4Mask/' config.h
    sed -i 's|"st"|"alacritty"|g' config.h
    grep -q XK_Return config.h || echo '{ MODKEY, XK_Return, spawn, SHCMD("alacritty") },' >> config.h
    echo '{ MODKEY, XK_t, spawn, SHCMD("thunar") },' >> config.h
    echo '{ MODKEY, XK_m, spawn, SHCMD("dwm-control.sh") },' >> config.h
    echo '{ MODKEY, XK_n, spawn, SHCMD("quick-settings.sh") },' >> config.h
    echo '{ MODKEY, XK_l, spawn, SHCMD("screen-fade.sh") },' >> config.h
    echo '{ MODKEY, XK_s, spawn, SHCMD("screenshot.sh") },' >> config.h
  fi
  make clean all
done

# ----------[ 10. Autostart + Xinit ]-----------------------------------
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

# ----------[ 11. Fish Shell Nerd Banner ]-------------------------------
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

# ----------[ 12. Finish Banner ]----------------------------------------
clear
echo "───────────────────────────────────────────────"
echo "✅  Installation complete – DWM Nerd OS v9.1"
echo "💻  Log out, re-login (Fish auto-starts DWM)"
echo "───────────────────────────────────────────────"
