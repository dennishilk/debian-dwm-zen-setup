#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWM_SRC_DIR="$REPO_DIR/src/dwm"
USER_BIN_DIR="$HOME/.local/bin"
USER_CONFIG_DIR="$HOME/.config"
USER_WALL_DIR="$HOME/.local/share/wallpapers"
LOG_PREFIX="[debian-dwm-setup]"

log() {
  echo "$LOG_PREFIX $*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

ensure_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
  else
    require_cmd sudo
    SUDO="sudo"
    $SUDO -v
  fi
}

install_packages() {
  log "Installing Debian dependencies for dwm + ThinkPad tweaks"
  $SUDO apt update
  $SUDO apt install -y \
    git build-essential libx11-dev libxft-dev libxinerama-dev libxrandr-dev \
    libxcb1-dev libxcb-util0-dev libxcb-icccm4-dev libxcb-ewmh-dev libxcb-keysyms1-dev \
    ttf-jetbrains-mono kitty dmenu feh brightnessctl scrot tlp \
    xorg xinit x11-xserver-utils libx11-xcb-dev libxext-dev libxrender-dev libxfixes-dev \
    rofi alsa-utils pulseaudio-utils acpi curl
}

prepare_dwm_source() {
  mkdir -p "$REPO_DIR/src"
  if [ ! -d "$DWM_SRC_DIR/.git" ]; then
    log "Cloning dwm source into repository: $DWM_SRC_DIR"
    git clone https://git.suckless.org/dwm "$DWM_SRC_DIR"
  else
    log "Using existing dwm source checkout in repo"
    git -C "$DWM_SRC_DIR" fetch --all --prune
    git -C "$DWM_SRC_DIR" reset --hard origin/master
  fi

  log "Applying repository dwm config.h"
  cp "$REPO_DIR/configs/dwm/config.h" "$DWM_SRC_DIR/config.h"
}

build_install_dwm() {
  log "Building dwm from local source"
  make -C "$DWM_SRC_DIR" clean
  make -C "$DWM_SRC_DIR"
  $SUDO make -C "$DWM_SRC_DIR" install
}

install_dwmblocks_runner() {
  log "Installing dwm status bar runner"
  mkdir -p "$USER_BIN_DIR" "$USER_CONFIG_DIR/dwmblocks"
  install -m 0755 "$REPO_DIR/scripts/dwmblocks.sh" "$USER_BIN_DIR/dwmblocks"
  cp "$REPO_DIR/configs/dwmblocks/dwmblocks.conf" "$USER_CONFIG_DIR/dwmblocks/dwmblocks.conf"
}

install_wallpapers() {
  log "Installing wallpapers"
  mkdir -p "$USER_WALL_DIR"
  cp -f "$REPO_DIR"/assets/wallpapers/* "$USER_WALL_DIR/" 2>/dev/null || true
}

install_xinitrc() {
  log "Installing ~/.xinitrc"
  install -m 0755 "$REPO_DIR/configs/xinit/xinitrc" "$HOME/.xinitrc"
}

configure_tlp_and_input() {
  log "Enabling TLP power management"
  $SUDO systemctl enable tlp
  $SUDO systemctl start tlp

  log "Applying ThinkPad T480 touchpad/trackpoint tweaks"
  $SUDO mkdir -p /etc/X11/xorg.conf.d
  $SUDO tee /etc/X11/xorg.conf.d/30-thinkpad-input.conf >/dev/null <<'EOT'
Section "InputClass"
    Identifier "ThinkPad Touchpad"
    MatchProduct "SynPS/2 Synaptics TouchPad"
    Driver "libinput"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "DisableWhileTyping" "true"
    Option "AccelSpeed" "0.2"
EndSection

Section "InputClass"
    Identifier "ThinkPad TrackPoint"
    MatchProduct "TPPS/2 IBM TrackPoint"
    Driver "libinput"
    Option "AccelSpeed" "0.4"
    Option "MiddleEmulation" "on"
EndSection
EOT

  log "Allowing video group brightness control"
  $SUDO tee /etc/udev/rules.d/90-backlight.rules >/dev/null <<'EOT'
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOT
  $SUDO udevadm control --reload
}

sync_repo_helpers() {
  if [ -f "$REPO_DIR/.gitmodules" ]; then
    log "Updating repository submodules"
    git -C "$REPO_DIR" submodule update --init --recursive
  fi
}

main() {
  require_cmd git
  require_cmd make
  ensure_sudo

  sync_repo_helpers
  install_packages
  prepare_dwm_source
  build_install_dwm
  install_dwmblocks_runner
  install_wallpapers
  install_xinitrc
  configure_tlp_and_input

  log "Installation complete. Reboot, login on tty, then run: startx"
}

main "$@"
