#!/usr/bin/env bash
# ────────────────────────────────────────────────
# Debian 13 DWM Ultimate Setup by Dennis Hilk
# Final version – local DWM build in ~/.config/dwm
# ────────────────────────────────────────────────

set -e

# ── Root check
if [[ $EUID -ne 0 ]]; then
  echo "Bitte mit sudo oder als root ausführen."
  exit 1
fi

# ── Ensure dialog exists
if ! command -v dialog &>/dev/null; then
  echo "→ Installiere fehlendes Paket: dialog"
  apt update -y && apt install -y dialog
fi

GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; RESET="\e[0m"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
USER_HOME="/home/$SUDO_USER"

clear
echo -e "${GREEN}──────────────────────────────────────────────"
echo -e "        DWM Ultimate Setup (Debian 13)"
echo -e "──────────────────────────────────────────────${RESET}"

while true; do
CHOICE=$(dialog --clear --stdout --title "DWM Setup Menü" \
  --menu "Wähle eine Option:" 23 75 12 \
  1 "System aktualisieren" \
  2 "Fish Shell + Systeminfos" \
  3 "GPU-Treiber automatisch erkennen" \
  4 "Google Chrome installieren" \
  5 "DWM + Tools installieren (lokal, mit Wallpaper)" \
  6 "Zen Kernel installieren / prüfen" \
  7 "Neustart" \
  8 "Beenden")

clear
case $CHOICE in
# ────────────────────────────────────────────────
1)
  echo -e "${YELLOW}→ System wird aktualisiert...${RESET}"
  apt update && apt full-upgrade -y
  echo -e "${GREEN}✔ Systemupdate abgeschlossen.${RESET}"
  read -rp "Weiter mit Enter..."
  ;;
# ────────────────────────────────────────────────
2)
  echo -e "${YELLOW}→ Installiere Fish Shell...${RESET}"
  apt install -y fish fastfetch

  # benötigte Ordner für Fish
  sudo -u "$SUDO_USER" mkdir -p "$USER_HOME/.config/fish/functions" \
                              "$USER_HOME/.config/fish/conf.d" \
                              "$USER_HOME/.config/fish/completions"

  # config.fish schreiben
  sudo -u "$SUDO_USER" bash -c "cat > '$USER_HOME/.config/fish/config.fish' <<'EOF'
fastfetch
echo ''
set_color cyan
echo 'OS:' (grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | tr -d '\"')
set_color green
echo 'Uptime:' (uptime -p)
set_color yellow
echo 'System gestartet seit:' (who -b | awk '{print \$3,\$4}')
set_color normal

# DWM Autostart (nur auf TTY1)
if test -z '\$DISPLAY'
    and test (tty) = '/dev/tty1'
    echo ''
    echo '🐧 Willkommen Dennis — DWM startet in 2 Sekunden...'
    sleep 2
    exec startx
end
EOF"

  chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config/fish"
  chsh -s /usr/bin/fish "$SUDO_USER"
  echo -e "${GREEN}✔ Fish Shell mit Autostart und korrekten Berechtigungen eingerichtet.${RESET}"
  read -rp "Weiter mit Enter..."
  ;;
# ────────────────────────────────────────────────
3)
  echo -e "${YELLOW}→ Erkenne GPU...${RESET}"
  GPU=$(lspci | grep -E "VGA|3D")
  echo "$GPU"
  if echo "$GPU" | grep -qi nvidia; then
    apt install -y nvidia-driver firmware-misc-nonfree
    echo -e "${GREEN}✔ NVIDIA-Treiber installiert.${RESET}"
  elif echo "$GPU" | grep -qi amd; then
    apt install -y firmware-amd-graphics mesa-vulkan-drivers
    echo -e "${GREEN}✔ AMD-Treiber installiert.${RESET}"
  elif echo "$GPU" | grep -qi intel; then
    apt install -y intel-media-va-driver-non-free mesa-va-drivers
    echo -e "${GREEN}✔ Intel-Treiber installiert.${RESET}"
  else
    echo -e "${RED}Keine bekannte GPU erkannt.${RESET}"
  fi
  read -rp "Weiter mit Enter..."
  ;;
# ────────────────────────────────────────────────
4)
  echo -e "${YELLOW}→ Installiere Google Chrome...${RESET}"
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
  apt install -y /tmp/chrome.deb || apt -f install -y
  rm -f /tmp/chrome.deb
  echo -e "${GREEN}✔ Google Chrome installiert.${RESET}"
  read -rp "Weiter mit Enter..."
  ;;
# ────────────────────────────────────────────────
5)
  echo -e "${YELLOW}→ Installiere DWM und Tools lokal unter ~/.config/dwm...${RESET}"
  apt install -y build-essential libx11-dev libxft-dev libxinerama-dev feh xinit alacritty git curl unzip

  mkdir -p "$USER_HOME/.config/dwm"
  cd "$USER_HOME/.config/dwm"

  # DWM klonen und lokal bauen
  if [[ ! -d dwm ]]; then
    sudo -u "$SUDO_USER" git clone https://git.suckless.org/dwm
  fi
  cd dwm
  sudo -u "$SUDO_USER" make clean all
  cd ..

  # Xinitrc lokal anpassen
  echo 'exec ~/.config/dwm/dwm/dwm' > "$USER_HOME/.xinitrc"

  # Wallpaper automatisch aktivieren
  WALLPAPER_SRC="$SCRIPT_DIR/wallpaper.png"
  WALLPAPER_DST="$USER_HOME/.config/dwm/wallpaper.png"
  if [[ -f "$WALLPAPER_SRC" ]]; then
    cp "$WALLPAPER_SRC" "$WALLPAPER_DST"
    chown "$SUDO_USER:$SUDO_USER" "$WALLPAPER_DST"
    echo "feh --bg-scale $WALLPAPER_DST" > "$USER_HOME/.fehbg"
    chmod +x "$USER_HOME/.fehbg"
    if ! grep -q ".fehbg" "$USER_HOME/.xinitrc"; then
      echo "~/.fehbg &" >> "$USER_HOME/.xinitrc"
    fi
    echo -e "${GREEN}✔ Wallpaper automatisch kopiert und aktiviert.${RESET}"
  else
    echo -e "${RED}⚠️  Kein wallpaper.png im Skriptordner gefunden (${SCRIPT_DIR})${RESET}"
  fi

  chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config/dwm" "$USER_HOME/.xinitrc"
  echo -e "${GREEN}✔ DWM lokal installiert unter ~/.config/dwm${RESET}"
  read -rp "Weiter mit Enter..."
  ;;
# ────────────────────────────────────────────────
6)
  echo -e "${YELLOW}→ Prüfe Zen Kernel...${RESET}"
  if uname -r | grep -q "zen"; then
    echo -e "${GREEN}✔ Zen Kernel aktiv: $(uname -r)${RESET}"
  elif dpkg -l | grep -q linux-image-zen; then
    echo -e "${GREEN}✔ Zen Kernel installiert, aber nicht aktiv.${RESET}"
    echo -e "${YELLOW}→ Bitte Neustart durchführen.${RESET}"
  else
    echo -e "${YELLOW}→ Installiere Zen Kernel...${RESET}"
    apt update
    if ! apt install -y linux-image-zen linux-headers-zen; then
      echo -e "${RED}Zen Kernel nicht verfügbar – Fallback aktiv.${RESET}"
      echo "deb http://deb.debian.org/debian sid main contrib non-free non-free-firmware" > /etc/apt/sources.list.d/zen-temp.list
      apt update -y || true
      apt install -y linux-image-amd64 linux-headers-amd64 || apt install -y linux-image-cloud-amd64
      rm -f /etc/apt/sources.list.d/zen-temp.list
      apt update -y
    fi
    echo -e "${GREEN}✔ Kernel-Installation abgeschlossen.${RESET}"
    echo -e "${YELLOW}Bitte neu starten.${RESET}"
  fi
  read -rp "Weiter mit Enter..."
  ;;
# ────────────────────────────────────────────────
7)
  echo -e "${YELLOW}→ Starte System neu...${RESET}"
  sleep 2
  reboot
  ;;
# ────────────────────────────────────────────────
8)
  clear
  echo -e "${GREEN}Installation abgeschlossen!${RESET}"
  echo -e "${YELLOW}Nach Login auf TTY1 startet DWM automatisch über Fish.${RESET}"
  exit 0
  ;;
esac
done
