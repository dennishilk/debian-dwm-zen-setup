#!/bin/bash
# ======================================================================
#  DWM Nerd OS Deluxe — v10.0 (modular • backups • patches • logging)
#  by Dennis & GPT-5 Thinking
#
#  Highlights
#  - Modular wie "dwm-setup": Funktionen, Backups, optionale Patches
#  - Volllogging in ~/install.log + klare Fehlerausgaben
#  - GPU-Auswahl (NVIDIA/AMD/Skip) + VM-sicherer Terminal-Fallback
#  - User-Fonts (keine Root-Probleme), kein i3lock, Fade-Screen
#  - DWM/dmenu/slstatus lokal in ~/.config, Autostart, Fish auto-startx
# ======================================================================

set -euo pipefail
IFS=$'\n\t'

# ---------- Globals ----------
SCRIPT_DIR="$(pwd)"
LOG="$HOME/install.log"
DATE_TAG="$(date +%F-%H%M%S)"

if [ "$EUID" -eq 0 ]; then
  REAL_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-root}")
  HOME_DIR=$(eval echo "~$REAL_USER")
else
  REAL_USER="$USER"
  HOME_DIR="$HOME"
fi

# ---------- Logging & error handling ----------
exec > >(tee -a "$LOG") 2>&1
trap 'echo "❌ Error at line $LINENO. See $LOG for details." >&2' ERR

msg() { echo -e "\n\033[1;36m==> $*\033[0m"; }
ok()  { echo -e "✅ $*"; }
warn(){ echo -e "⚠️  $*" ; }
die() { echo -e "❌ $*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

# ---------- Helpers ----------
backup_dir() {
  local d="$1"
  [ -d "$d" ] || return 0
  local out="${d}__backup_${DATE_TAG}"
  msg "Backup $d → $out"
  mv "$d" "$out"
}

ensure_dir() { mkdir -p "$1"; }

apt_install() {
  sudo apt-get update -y
  sudo apt-get install -y "$@"
}

# Safe sed on config.h keys[] — inject lines before closing "};" of keys list
dwm_inject_keys_safely() {
  local cfg="$HOME_DIR/.config/dwm/config.h"
  [ -f "$cfg" ] || return 0
  local start end
  start=$(grep -n "static Key keys" "$cfg" | head -n1 | cut -d: -f1 || true)
  [ -n "$start" ] || return 0
  end=$(awk "NR>$start && /};/ {print NR; exit}" "$cfg")
  [ -n "$end" ] || return 0

  local tmp
  tmp=$(mktemp)
  head -n $((end-1)) "$cfg" > "$tmp"
  cat >> "$tmp" <<'KEYS'
    { MODKEY, XK_Return, spawn, SHCMD("alacritty") },
    { MODKEY, XK_t,      spawn, SHCMD("thunar") },
    { MODKEY, XK_m,      spawn, SHCMD("dwm-control.sh") },
    { MODKEY, XK_n,      spawn, SHCMD("quick-settings.sh") },
    { MODKEY, XK_l,      spawn, SHCMD("screen-fade.sh") },
    { MODKEY, XK_s,      spawn, SHCMD("screenshot.sh") },
KEYS
  tail -n +"$end" "$cfg" >> "$tmp"
  mv "$tmp" "$cfg"
}

apply_patches_if_any() {
  # Optional: apply user patches from ./patches/<dwm|dmenu|slstatus>/*.diff or *.patch
  for repo in dwm dmenu slstatus; do
    local patch_dir="$SCRIPT_DIR/patches/$repo"
    local repo_dir="$HOME_DIR/.config/$repo"
    [ -d "$patch_dir" ] || continue
    [ -d "$repo_dir/.git" ] || continue
    msg "Applying patches for $repo from $patch_dir"
    cd "$repo_dir"
    for p in "$patch_dir"/*.{diff,patch} 2>/dev/null; do
      [ -e "$p" ] || continue
      if git apply --check "$p" >/dev/null 2>&1; then
        git apply "$p"
        ok "applied $(basename "$p")"
      else
        warn "could not apply $(basename "$p") — skipping"
      fi
    done
  done
}

# ---------- Steps ----------
detect_env() {
  msg "Environment"
  echo "User: $REAL_USER   HOME: $HOME_DIR"
  if systemd-detect-virt | grep -Eq "qemu|kvm|vmware|vbox"; then
    PICOM_BACKEND="xrender"
  else
    PICOM_BACKEND="glx"
  fi
  echo "Picom backend: $PICOM_BACKEND"
}

install_base() {
  msg "Install base packages"
  apt_install xorg feh picom build-essential git curl wget unzip ca-certificates \
    libx11-dev libxft-dev libxinerama-dev \
    zram-tools fish lxappearance thunar thunar-volman gvfs gvfs-backends gvfs-fuse \
    gtk2-engines-murrine adwaita-icon-theme-full papirus-icon-theme \
    fastfetch libnotify-bin imagemagick maim slop xclip \
    alsa-utils brightnessctl
  ok "Base packages OK"
}

install_gpu() {
  msg "GPU selection"
  echo "Choose GPU drivers: nvidia / amd / skip"
  read -rp "→ " gpu_choice
  case "${gpu_choice,,}" in
    nvidia)
      apt_install firmware-misc-nonfree "linux-headers-$(uname -r)" nvidia-driver nvidia-settings vulkan-tools
      ok "NVIDIA installed — test: nvidia-smi"
      ;;
    amd)
      apt_install firmware-linux-nonfree "linux-headers-$(uname -r)" mesa-vulkan-drivers vulkan-tools libvulkan1 radeontop
      ok "AMD installed — test: vulkaninfo | grep driver"
      ;;
    *)
      warn "Skipping GPU drivers."
      ;;
  esac
}

setup_zram() {
  msg "Configure ZRAM"
  sudo systemctl enable --now zramswap.service
  sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
  sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
  sudo sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
  ok "ZRAM enabled"
}

install_fonts() {
  msg "Install JetBrainsMono Nerd Font (user)"
  ensure_dir "$HOME_DIR/.local/share/fonts/nerd"
  cd "$HOME_DIR/.local/share/fonts/nerd"
  wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip -O JetBrainsMono.zip
  unzip -o JetBrainsMono.zip >/dev/null 2>&1 || true
  fc-cache -fv >/dev/null 2>&1
  cd - >/dev/null
  ok "Fonts installed in ~/.local/share/fonts"
}

setup_alacritty() {
  msg "Configure Alacritty"
  apt_install alacritty
  ensure_dir "$HOME_DIR/.config/alacritty"
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
  ok "Alacritty configured"
}

setup_picom() {
  msg "Configure Picom"
  ensure_dir "$HOME_DIR/.config"
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
  ok "Picom config written"
}

install_wallpaper() {
  msg "Install wallpaper"
  sudo mkdir -p /usr/share/backgrounds
  if [ -f "$SCRIPT_DIR/coding-2.png" ]; then
    sudo cp "$SCRIPT_DIR/coding-2.png" /usr/share/backgrounds/wallpaper.png
  else
    convert -size 1920x1080 xc:black /usr/share/backgrounds/wallpaper.png
  fi
  ok "Wallpaper ready"
}

install_helpers() {
  msg "Install helper scripts"
  ensure_dir "$HOME_DIR/.local/bin"

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

  # Fade screen (no lock)
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
  ensure_dir "$HOME_DIR/Logs"
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

  ok "Helper scripts installed"
}

build_suckless() {
  msg "Build suckless stack (with backups & optional patches)"

  # Backups before modifying
  for d in "$HOME_DIR/.config/dwm" "$HOME_DIR/.config/dmenu" "$HOME_DIR/.config/slstatus"; do
    [ -d "$d" ] && backup_dir "$d"
  done

  for repo in dwm dmenu slstatus; do
    local dir="$HOME_DIR/.config/$repo"
    ensure_dir "$dir"
    if [ ! -d "$dir/.git" ]; then
      git clone https://git.suckless.org/$repo "$dir"
    else
      git -C "$dir" pull --ff-only || true
    fi

    cd "$dir"
    cp -f config.def.h config.h 2>/dev/null || true

    if [ "$repo" = "dwm" ]; then
      sed -i 's|#define MODKEY.*|#define MODKEY Mod4Mask|' config.h
      sed -i 's|"st"|"alacritty"|g' config.h
      dwm_inject_keys_safely
    fi

    # Optional user patches (like dwm-setup style)
    cd "$dir"
  done

  apply_patches_if_any

  # Build all
  for repo in dwm dmenu slstatus; do
    cd "$HOME_DIR/.config/$repo"
    msg "make $repo"
    make clean all
    ok "$repo built"
  done
}

terminal_fallback_vm() {
  msg "Configure VM-safe terminal fallback"
  local term="alacritty"
  if ! alacritty --version >/dev/null 2>&1; then
    warn "Alacritty missing/unusable — installing xfce4-terminal"
    apt_install xfce4-terminal
    term="xfce4-terminal"
  fi
  local cfg="$HOME_DIR/.config/dwm/config.h"
  if [ -f "$cfg" ]; then
    sed -i "s|\"st\"|\"$term\"|g" "$cfg"
    sed -i "s|\"alacritty\"|\"$term\"|g" "$cfg"
    cd "$HOME_DIR/.config/dwm" && make clean all
  fi
  ok "Terminal command set to $term"
}

setup_autostart() {
  msg "Setup autostart & xinit"
  ensure_dir "$HOME_DIR/.dwm"
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
  ok ".xinitrc + autostart ready"
}

setup_fish() {
  msg "Fish shell + auto startx"
  sudo chsh -s /usr/bin/fish "$REAL_USER"
  ensure_dir "$HOME_DIR/.config/fish"
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
  ok "Fish config installed"
}

verify_build() {
  msg "Verify builds"
  check() { [ -x "$1" ] && echo "✅ $2 OK" || echo "❌ $2 MISSING"; }
  check "$HOME_DIR/.config/dwm/dwm"           "dwm"
  check "$HOME_DIR/.config/dmenu/dmenu_run"   "dmenu_run"
  check "$HOME_DIR/.config/slstatus/slstatus" "slstatus"
}

# ---------- Main ----------
detect_env
install_base
install_gpu
setup_zram
install_fonts
setup_alacritty
setup_picom
install_wallpaper
install_helpers
build_suckless
terminal_fallback_vm
setup_autostart
setup_fish
verify_build

echo
echo "───────────────────────────────────────────────"
ok  "DWM Nerd OS Deluxe v10.0 — installation finished."
echo "Log file: $LOG"
echo "Reboot, login on TTY1 — Fish will start DWM automatically."
echo "───────────────────────────────────────────────"
