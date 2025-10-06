#!/bin/bash
# ======================================================================
#  🧠 Debian 13 DWM – Nerd OS Deluxe (v9.1)
#  by Dennis Hilk & ChatGPT (GPT-5)
#
#  ✨ Inhalt:
#   - DWM + dmenu + slstatus (lokal in ~/.config)
#   - Fish Shell (Auto startx, Nerd Infos)
#   - Alacritty (transparent, TOML, Fish)
#   - Control Center (Super+M), Quick Settings (Super+N)
#   - Screenshot Tool (Super+S), Lock Screen (Super+L)
#   - Maintenance Tools, Notifications, Wallpaper Blur
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

# ----------[ 1. GPU/VM Detection → Picom Backend ]----------------------
SAFE_MODE=false
if systemd-detect-virt | grep -Eq "qemu|kvm|vmware|vbox"; then
  PICOM_BACKEND="xrender"
  SAFE_MODE=true
else
  PICOM_BACKEND="glx"
  if ! lspci | grep -qiE 'vga|3d|nvidia|amd|intel'; then SAFE_MODE=true; fi
fi
echo "🖥️ Picom backend preset: $PICOM_BACKEND | SAFE_MODE=$SAFE_MODE"

# ----------[ 2. Base Packages (apt) ]-----------------------------------
echo "📦 Installing base system + dependencies..."
sudo apt update -y
sudo apt install -y \
  xorg feh picom build-essential git curl wget unzip ca-certificates \
  libx11-dev libxft-dev libxinerama-dev \
  zram-tools fish lxappearance \
  gtk2-engines-murrine adwaita-icon-theme-full papirus-icon-theme \
  thunar thunar-volman gvfs gvfs-backends gvfs-fuse \
  fastfetch libnotify-bin i3lock-color imagemagick maim slop xclip \
  alsa-utils brightnessctl

# ----------[ 3. ZRAM Setup ]-------------------------------------------
sudo systemctl enable --now zramswap.service
sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
echo "✅ ZRAM active (50%, zstd)"
# ----------[ 4. Nerd Font – JetBrainsMono Nerd ]------------------------
echo "🎨 Installing JetBrainsMono Nerd Font..."
sudo mkdir -p /usr/share/fonts/truetype/nerd
cd /usr/share/fonts/truetype/nerd
JB_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"
sudo wget -q "$JB_URL" -O JetBrainsMono.zip || true
sudo unzip -o JetBrainsMono.zip >/dev/null 2>&1 || true
sudo fc-cache -fv >/dev/null 2>&1
cd -

# ----------[ 5. Alacritty Config (TOML + Fish) ]------------------------
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

# ----------[ 6. Picom Config ]------------------------------------------
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

# ----------[ 7. Wallpaper ]---------------------------------------------
sudo mkdir -p /usr/share/backgrounds
if [ -f "./coding-2.png" ]; then
  sudo cp ./coding-2.png /usr/share/backgrounds/wallpaper.png
  echo "🖼️ Wallpaper installed."
else
  echo "⚠️ No wallpaper found (./coding-2.png missing)"
fi
# ----------[ 8. Helper Scripts – ~/.local/bin ]--------------------------
mkdir -p "$HOME_DIR/.local/bin"

# ---[ 8.1 Control Center (Super+M) ]------------------------------------
cat > "$HOME_DIR/.local/bin/dwm-control.sh" <<'EOF'
#!/bin/bash
choice=$(printf "Update system\nRestart DWM\nBackup configs\nReboot system\nPower off\nExit X session" | dmenu -i -p "Control Center:")
case "$choice" in
  "Update system")
    notify-send "🧰 Update" "System update started…"
    alacritty -e bash -c "sudo apt update && sudo apt upgrade -y; echo; echo '✅ Update complete'; read -n 1 -s -p 'Press any key...'"
    notify-send "✅ Update complete"
    ;;
  "Restart DWM")
    notify-send "🔁 Restarting DWM…"
    pkill dwm
    ;;
  "Backup configs")
    OUT=~/dwm-backup-$(date +%F-%H%M).tar.gz
    tar -czf "$OUT" ~/.config/dwm ~/.config/dmenu ~/.config/slstatus ~/.config/fish ~/.dwm 2>/dev/null
    notify-send "💾 Backup complete" "$OUT"
    ;;
  "Reboot system")
    notify-send "💻 Reboot" "Restarting now…"
    sudo reboot
    ;;
  "Power off")
    notify-send "🔌 Power" "Shutting down…"
    sudo poweroff
    ;;
  "Exit X session")
    notify-send "🚪 Exit" "Leaving X session…"
    pkill X
    ;;
esac
EOF
chmod +x "$HOME_DIR/.local/bin/dwm-control.sh"

# ---[ 8.2 Quick Settings (Super+N) ]------------------------------------
cat > "$HOME_DIR/.local/bin/quick-settings.sh" <<'EOF'
#!/bin/bash
choice=$(printf "Volume +\nVolume -\nMute toggle\nBrightness +\nBrightness -\nNetwork info" | dmenu -i -p "Quick Settings:")
case "$choice" in
  "Volume +")
    amixer set Master 5%+ >/dev/null
    notify-send "🔊 Volume" "+5%"
    ;;
  "Volume -")
    amixer set Master 5%- >/dev/null
    notify-send "🔉 Volume" "-5%"
    ;;
  "Mute toggle")
    amixer set Master toggle >/dev/null
    M=$(amixer get Master | tail -n1 | grep -o "\[on\]\|\[off\]" | tr -d "[]")
    notify-send "🔇 Mute" "$M"
    ;;
  "Brightness +")
    brightnessctl set +5% >/dev/null
    P=$(brightnessctl | grep -oP '\(\K[0-9]+(?=%\))')
    notify-send "💡 Brightness" "+5% (now ${P}%)"
    ;;
  "Brightness -")
    brightnessctl set 5%- >/dev/null
    P=$(brightnessctl | grep -oP '\(\K[0-9]+(?=%\))')
    notify-send "💡 Brightness" "-5% (now ${P}%)"
    ;;
  "Network info")
    INFO=$(ip -br a | sed 's/UNKNOWN/--/g')
    notify-send "🌐 Network" "$INFO"
    ;;
esac
EOF
chmod +x "$HOME_DIR/.local/bin/quick-settings.sh"

# ---[ 8.3 Lock Screen (Super+L) – Wallpaper Blur via i3lock-color ]-----
cat > "$HOME_DIR/.local/bin/lock-blur.sh" <<'EOF'
#!/bin/bash
WALL=/usr/share/backgrounds/wallpaper.png
TMPBG=/tmp/lock_blur.png
if [ -f "$WALL" ]; then
  convert "$WALL" -blur 0x8 "$TMPBG"
else
  convert -size 1920x1080 xc:black "$TMPBG"
fi
i3lock-color -i "$TMPBG" --clock --insidecolor=00000066 --ringcolor=00ff99aa --timecolor=ffffffff --datecolor=ffffffff --line-uses-inside &
sleep 1 && rm -f "$TMPBG"
EOF
chmod +x "$HOME_DIR/.local/bin/lock-blur.sh"

# ---[ 8.4 Screenshot Tool (Super+S) ]----------------------------------
cat > "$HOME_DIR/.local/bin/screenshot.sh" <<'EOF'
#!/bin/bash
mkdir -p ~/Pictures/Screenshots
FILE=~/Pictures/Screenshots/screenshot-$(date +%F-%H%M%S).png
maim -s "$FILE"
if [ $? -eq 0 ]; then
  xclip -selection clipboard -t image/png -i "$FILE"
  notify-send "📸 Screenshot saved" "$FILE (copied to clipboard)"
else
  notify-send "❌ Screenshot aborted"
fi
EOF
chmod +x "$HOME_DIR/.local/bin/screenshot.sh"

# ---[ 8.5 Maintenance Script – Clean & Log ]----------------------------
mkdir -p "$HOME_DIR/Logs"
cat > "$HOME_DIR/.local/bin/maintenance.sh" <<'EOF'
#!/bin/bash
LOG=~/Logs/maintenance-$(date +%F).log
{
echo "==== Maintenance $(date) ===="
sudo apt autoremove -y && echo "✓ Orphans removed"
sudo apt autoclean -y && echo "✓ Cache cleaned"
sudo journalctl --vacuum-time=7d && echo "✓ Journals trimmed"
sudo rm -rf /tmp/* && echo "✓ Temp cleared"
echo "Done."
} | tee -a "$LOG"
notify-send "🧹 Maintenance complete" "Log saved to ~/Logs"
EOF
chmod +x "$HOME_DIR/.local/bin/maintenance.sh"
# ----------[ 9. DWM / DMENU / SLSTATUS – Build local ]------------------
echo "🔧 Building DWM, DMENU, SLSTATUS (local config build)..."

for repo in dwm dmenu slstatus; do
  mkdir -p "$HOME_DIR/.config/$repo"
  if [ ! -d "$HOME_DIR/.config/$repo/.git" ]; then
    git clone https://git.suckless.org/$repo "$HOME_DIR/.config/$repo"
  else
    git -C "$HOME_DIR/.config/$repo" pull
  fi
  cd "$HOME_DIR/.config/$repo"
  cp config.def.h config.h 2>/dev/null || true

  # --- Custom Keybindings (Dennis Edition) ---
  if [ "$repo" = "dwm" ]; then
    sed -i 's/#define MODKEY.*/#define MODKEY Mod4Mask/' config.h        # Super key as MOD
    sed -i 's|"st"|"alacritty"|g' config.h
    sed -i 's|"xterm"|"alacritty"|g' config.h

    # Super + Return → Alacritty
    if ! grep -q 'XK_Return' config.h; then
      echo '    { MODKEY, XK_Return, spawn, SHCMD("alacritty") },' >> config.h
    fi
    # Super + T → Thunar
    if ! grep -q 'XK_t' config.h; then
      sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_t, spawn, SHCMD("thunar") },' config.h
    fi
    # Super + M → Control Center
    if ! grep -q 'XK_m' config.h; then
      sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_m, spawn, SHCMD("dwm-control.sh") },' config.h
    fi
    # Super + N → Quick Settings
    if ! grep -q 'XK_n' config.h; then
      sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_n, spawn, SHCMD("quick-settings.sh") },' config.h
    fi
    # Super + L → Lock
    if ! grep -q 'XK_l' config.h; then
      sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_l, spawn, SHCMD("lock-blur.sh") },' config.h
    fi
    # Super + S → Screenshot
    if ! grep -q 'XK_s' config.h; then
      sed -i '/{ MODKEY,.*XK_Return/,/},/a\    { MODKEY, XK_s, spawn, SHCMD("screenshot.sh") },' config.h
    fi
  fi

  make clean all
  chmod +x "$HOME_DIR/.config/$repo/$repo"
done

echo "✅ DWM, DMENU, SLSTATUS built & installed locally."

# ----------[ 10. Autostart Script – ~/.dwm/autostart.sh ]---------------
mkdir -p "$HOME_DIR/.dwm"
cat > "$HOME_DIR/.dwm/autostart.sh" <<EOF
#!/bin/bash
xsetroot -solid black &
(sleep 2 && feh --no-fehbg --bg-scale /usr/share/backgrounds/wallpaper.png) &
EOF
if ! \$SAFE_MODE; then
cat >> "$HOME_DIR/.dwm/autostart.sh" <<'EOF'
picom --experimental-backends --config ~/.config/picom.conf &
EOF
fi
cat >> "$HOME_DIR/.dwm/autostart.sh" <<'EOF'
~/.config/slstatus/slstatus &
(sleep 2 && alacritty &) &
EOF
chmod +x "$HOME_DIR/.dwm/autostart.sh"

# ----------[ 11. .xinitrc – startx config ]------------------------------
cat > "$HOME_DIR/.xinitrc" <<'EOF'
#!/bin/bash
xmodmap ~/.Xmodmap &
~/.dwm/autostart.sh &
exec $HOME/.config/dwm/dwm > ~/.dwm.log 2>&1
EOF
chmod +x "$HOME_DIR/.xinitrc"
# ----------[ 12. Fish Shell – Nerd Setup ]------------------------------
echo "🐟 Setting up Fish Shell..."
sudo chsh -s /usr/bin/fish "$REAL_USER"
mkdir -p "$HOME_DIR/.config/fish"

cat > "$HOME_DIR/.config/fish/config.fish" <<'EOF'
# =============================================================
# 🐟 Fish Nerd Setup – by $USER
#  auto-loaded every time Alacritty or TTY opens
# =============================================================

set user (whoami)
set host (hostname)
set uptime_now (uptime -p | sed 's/up //')
set ram_total (free -m | awk '/Mem:/ {print $2}')
set ram_used (free -m | awk '/Mem:/ {print $3}')
set root_dev (findmnt -no SOURCE /)
set install_date (sudo tune2fs -l $root_dev ^/dev/null | grep "Filesystem created:" | sed 's/Filesystem created: //')
if test -z "$install_date"
    set install_date (ls -lt --time=ctime /etc | tail -n 1 | awk '{print $6, $7, $8}')
end
set install_epoch (date -d "$install_date" +%s ^/dev/null)
set now_epoch (date +%s)
set system_days (math "($now_epoch - $install_epoch) / 86400")

set_color cyan
echo "───────────────────────────────────────────────"
echo "🐧 Welcome back, $user@$host"
echo "💻 Debian 13 | DWM + Alacritty | Fish Shell"
echo "🕒 Uptime (session): $uptime_now"
echo "📅 Installed: $install_date"
echo "⏳ System age: ≈ $system_days days"
echo "🧠 RAM usage: $ram_used / $ram_total MB"
echo "───────────────────────────────────────────────"
set_color normal

# --- Aliases ---
alias ll="ls -lh --color=auto"
alias la="ls -lah --color=auto"
alias ..="cd .."
alias ...="cd ../.."
alias update="sudo apt update && sudo apt upgrade -y"
alias fetch="fastfetch"
alias reboot="sudo reboot"
alias poweroff="sudo poweroff"
alias dwmconf="cd ~/.config/dwm && alacritty -e nano config.h"
alias dwmrebuild="cd ~/.config/dwm && make clean all"

# --- Show hint ---
set_color green
echo "✨  Type 'update' to update or 'fetch' for system info."
set_color normal

# --- Auto-start DWM if on TTY1 ---
if test -z "$DISPLAY"
    and test (tty) = "/dev/tty1"
    echo "🎨 Starting DWM..."
    exec startx
end
EOF

# ensure ownership
sudo chown -R "$REAL_USER":"$REAL_USER" "$HOME_DIR/.config/fish"

# ----------[ 13. Permissions & PATH Fixes ]------------------------------
echo "🔧 Fixing PATH and permissions..."
echo 'export PATH="$HOME/.local/bin:$PATH"' | sudo tee -a "$HOME_DIR/.profile" >/dev/null
chmod -R +x "$HOME_DIR/.local/bin"
sudo chown -R "$REAL_USER":"$REAL_USER" "$HOME_DIR/.local"

# ----------[ 14. Final Notification Test ]------------------------------
notify-send "✅ DWM Nerd OS Deluxe v9.1" "Installation almost complete"
echo "✅ Fish + DWM autostart integrated successfully."
# ----------[ 15. Final System Check ]----------------------------------
echo "🧪 Running post-install checks..."

check_ok() { command -v "$1" >/dev/null 2>&1 && echo "✅ $1 found" || echo "❌ $1 missing"; }

for cmd in dwm dmenu slstatus alacritty fish feh picom notify-send i3lock-color maim; do
  check_ok "$cmd"
done

# ----------[ 16. Nerd Completion Banner ]------------------------------
clear
cat <<'EOF'
───────────────────────────────────────────────
🚀  DWM Nerd OS Deluxe v9.1 Installation Complete
───────────────────────────────────────────────
🐧 Core:
   - DWM + dmenu + slstatus (local builds)
   - Fish shell (auto startx on TTY1)
   - Alacritty (transparent, JetBrainsMono Nerd Font)
   - Picom compositor (blur & vsync)
🧩 Extras:
   - Control Center (Super + M)
   - Quick Settings (Super + N)
   - Screenshot Tool (Super + S)
   - Lock Screen (Super + L)
   - Maintenance Script (~/Logs/)
🎨 Style:
   - Wallpaper from /usr/share/backgrounds/wallpaper.png
   - NerdBar+ Status Modules (CPU | RAM | NET | optional GPU)
───────────────────────────────────────────────
✨  Tip:
   - Reboot now, log in as user, and watch Fish start DWM automatically.
   - Inside DWM, try your Super keys and enjoy the nerd flow.
───────────────────────────────────────────────
EOF

# ----------[ 17. Reboot Prompt ]---------------------------------------
read -rp "🔁 Reboot now? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  sudo reboot
else
  echo "👌 You can reboot later manually with: sudo reboot"
fi
