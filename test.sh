#!/bin/bash
# ======================================================================
# 🧠 Debian 13 DWM Nerd OS Deluxe v10.2  (Dennis Hilk Edition #1)
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

# ---------- Logging ----------
exec > >(tee -a "$LOG") 2>&1
trap 'echo "❌ Error at line $LINENO. See $LOG for details." >&2' ERR
msg() { echo -e "\n\033[1;36m==> $*\033[0m"; }
ok()  { echo -e "✅ $*"; }
warn(){ echo -e "⚠️  $*"; }

# ---------- Helpers ----------
backup_dir() { [ -d "$1" ] && mv "$1" "${1}__backup_$(date +%s)"; }
ensure_dir() { mkdir -p "$1"; }
apt_install() { sudo apt-get update -y && sudo apt-get install -y "$@"; }

# ---------- Functions ----------
detect_env() {
  msg "Environment detection"
  if systemd-detect-virt | grep -Eq "qemu|kvm|vmware|vbox"; then
    PICOM_BACKEND="xrender"
  else
    PICOM_BACKEND="glx"
  fi
  echo "Picom backend: $PICOM_BACKEND"
}

install_base() {
  msg "Installing base packages"
  apt_install xorg feh picom build-essential git curl wget unzip ca-certificates \
    libx11-dev libxft-dev libxinerama-dev \
    zram-tools fish lxappearance thunar thunar-volman gvfs gvfs-backends gvfs-fuse \
    gtk2-engines-murrine adwaita-icon-theme-full papirus-icon-theme \
    fastfetch libnotify-bin imagemagick maim slop xclip alsa-utils brightnessctl
}

install_gpu() {
  msg "GPU driver selection"
  echo "1) NVIDIA"
  echo "2) AMD"
  echo "3) Skip"
  read -rp "→ " gpu_choice
  case "${gpu_choice,,}" in
    1|"nvidia") apt_install firmware-misc-nonfree "linux-headers-$(uname -r)" nvidia-driver nvidia-settings vulkan-tools ;;
    2|"amd")     apt_install firmware-linux-nonfree "linux-headers-$(uname -r)" mesa-vulkan-drivers vulkan-tools libvulkan1 radeontop ;;
    *)           warn "Skipping GPU drivers." ;;
  esac
}

# ---------- NEW: Modifier Key Selection ----------
choose_modkey() {
  msg "Choose your DWM modifier key (for keyboard shortcuts)"
  echo "1) Super / Windows key (real hardware)"
  echo "2) Alt key (safe for VMs / noVNC)"
  read -rp "→ " mod_choice
  case "$mod_choice" in
    1|"super"|"Super") DWM_MODKEY="Mod4Mask" ;;
    2|"alt"|"Alt")     DWM_MODKEY="Mod1Mask" ;;
    *)                 DWM_MODKEY="Mod4Mask" ;;
  esac
  echo "Selected: $DWM_MODKEY"
  export DWM_MODKEY
}

setup_zram() {
  msg "Configuring ZRAM"
  sudo systemctl enable --now zramswap.service
  sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
  sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
}

install_fonts() {
  msg "Installing JetBrainsMono Nerd Font"
  ensure_dir "$HOME_DIR/.local/share/fonts/nerd"
  cd "$HOME_DIR/.local/share/fonts/nerd"
  wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip -O JetBrainsMono.zip
  unzip -o JetBrainsMono.zip >/dev/null 2>&1 || true
  fc-cache -fv >/dev/null 2>&1
}

setup_alacritty() {
  msg "Configuring Alacritty"
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
EOF
}

setup_picom() {
  msg "Creating Picom config"
  cat > "$HOME_DIR/.config/picom.conf" <<EOF
backend = "${PICOM_BACKEND}";
vsync = true;
shadow = true;
shadow-radius = 12;
shadow-color = "#00ff99";
shadow-opacity = 0.35;
blur-method = "dual_kawase";
blur-strength = 5;
inactive-opacity = 0.85;
active-opacity = 1.0;
EOF
}

build_suckless() {
  msg "Building DWM / dmenu / slstatus"
  for d in "$HOME_DIR/.config/dwm" "$HOME_DIR/.config/dmenu" "$HOME_DIR/.config/slstatus"; do
    [ -d "$d" ] && backup_dir "$d"
  done

  for repo in dwm dmenu slstatus; do
    local dir="$HOME_DIR/.config/$repo"
    ensure_dir "$dir"
    if [ ! -d "$dir/.git" ]; then
      git clone https://git.suckless.org/$repo "$dir"
    fi
    cd "$dir"
    cp -f config.def.h config.h 2>/dev/null || true
    [ "$repo" = "dwm" ] && {
      sed -i "s|#define MODKEY.*|#define MODKEY ${DWM_MODKEY:-Mod4Mask}|" config.h
      sed -i 's|"st"|"alacritty"|g' config.h
      awk '/static Key keys/ {print; print "    { MODKEY, XK_Return, spawn, SHCMD(\"alacritty\") },\n    { MODKEY, XK_t, spawn, SHCMD(\"thunar\") }"; next}1' config.h > tmp && mv tmp config.h
    }
    make clean all
  done
}

terminal_fallback_vm() {
  msg "Checking Alacritty availability"
  local term="alacritty"
  if ! alacritty --version >/dev/null 2>&1; then
    warn "Alacritty not working — installing xfce4-terminal"
    apt_install xfce4-terminal
    term="xfce4-terminal"
  fi
  sed -i "s|\"st\"|\"$term\"|g" "$HOME_DIR/.config/dwm/config.h" || true
  sed -i "s|\"alacritty\"|\"$term\"|g" "$HOME_DIR/.config/dwm/config.h" || true
  (cd "$HOME_DIR/.config/dwm" && make clean all)
}

setup_autostart() {
  msg "Setting up autostart + .xinitrc"
  mkdir -p "$HOME_DIR/.dwm"
  cat > "$HOME_DIR/.dwm/autostart.sh" <<'EOF'
#!/bin/bash
xsetroot -solid black &
(sleep 2 && feh --bg-scale /usr/share/backgrounds/wallpaper.png) &
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
}

setup_fish() {
  msg "Fish auto startx setup"
  sudo chsh -s /usr/bin/fish "$REAL_USER"
  mkdir -p "$HOME_DIR/.config/fish"
  cat > "$HOME_DIR/.config/fish/config.fish" <<'EOF'
set user (whoami)
set host (hostname)
set uptime_now (uptime -p | sed 's/up //')
set_color cyan
echo "───────────────────────────────────────────────"
echo "🐧 Welcome, $user@$host"
echo "🕒 Uptime: $uptime_now"
set_color normal
if test -z "$DISPLAY" ; and test (tty) = "/dev/tty1"
  echo "🎨 Starting DWM..."
  exec startx
end
EOF
}

verify_build() {
  msg "Verifying DWM components"
  for bin in "$HOME_DIR/.config/dwm/dwm" "$HOME_DIR/.config/dmenu/dmenu_run" "$HOME_DIR/.config/slstatus/slstatus"; do
    [ -x "$bin" ] && echo "✅ $(basename "$bin") OK" || echo "❌ $(basename "$bin") missing"
  done
}

# ---------- Main ----------
detect_env
install_base
install_gpu
choose_modkey
setup_zram
install_fonts
setup_alacritty
setup_picom
build_suckless
terminal_fallback_vm
setup_autostart
setup_fish
verify_build

echo "───────────────────────────────────────────────"
ok "DWM Nerd OS Deluxe v10.2 installed."
echo "💾 Log: $LOG"
echo "Reboot → login on TTY1 → Fish starts DWM automatically."
echo "───────────────────────────────────────────────"
