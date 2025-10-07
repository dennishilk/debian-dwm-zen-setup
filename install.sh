#!/usr/bin/env bash
# ────────────────────────────────────────────────
# Debian 13 DWM Ultimate Setup by Dennis Hilk
# Clean, menu-driven installer (Fish autostart)
# ────────────────────────────────────────────────

set -e

if [[ $EUID -ne 0 ]]; then
  echo "Bitte mit sudo oder als root ausführen."
  exit 1
fi

GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; RESET="\e[0m"

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
  5 "DWM + Tools installieren" \
  6 "Wallpaper aktivieren" \
  7 "Zen Kernel installieren" \
  8 "Autostart für DWM in Fish aktivieren" \
  9 "Neustart" \
  10 "Beenden")

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
  chsh -s /usr/bin/fish "$SUDO_USER"
  mkdir -p /home/$SUDO_USER/.config/fish
  cat <<'EOF' > /home/$SUDO_USER/.config/fish/config.fish
# ────────────────────────────────────────────────
# Fish Config mit Systeminfo
fastfetch
echo ""
set_color cyan
echo "OS:" (grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | tr -d '"')
set_color green
echo "Uptime:" (uptime -p)
set_color yellow
echo "System gestartet seit:" (who -b | awk '{print $3,$4}')
set_color normal
# ────────────────────────────────────────────────
# DWM Autostart (nur auf TTY1)
if test -z "$DISPLAY"
    and test (tty) = "/dev/tty1"
    echo ""
    echo "Starte automatisch DWM..."
    sleep 1
    exec startx
end
# ────────────────────────────────────────────────
EOF
  chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/fish
  echo -e "${GREEN}✔ Fish Shell mit Autostart eingerichtet.${RESET}"
  read -rp "Weiter mit Enter..."
  ;;
# ────────────────────────────────────────────────
3)
  echo -e "${YELLOW}→ Erkenne GPU...${RESET}"
  GPU=$(lspci | grep -E "VGA|3D")
  echo "$GPU"

  if echo "$GPU" | grep -qi nvidia; then
    echo -e "${GREEN}NVIDIA erkannt – installiere Treiber...${RESET}"
    apt install -y nvidia-driver firmware-misc-nonfree
  elif echo "$GPU" | grep -qi amd; then
    echo -e "${GREEN}AMD erkannt – installiere Treiber...${RESET}"
    apt install -y firmware-amd-graphics mesa-vulkan-drivers
  elif echo "$GPU" | grep -qi intel; then
    echo -e "${GREEN}Intel erkannt – installiere Treiber...${RESET}"
    apt install -y intel-media-va-driver-non-free mesa-va-drivers
  else
    echo -e "${RED}Keine bekannte GPU erkannt.${RESET}"
  fi
  echo -e "${GREEN}✔ GPU-Treiber abgeschlossen.${RESET}"
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
  echo -e "${YELLOW}→ Installiere DWM und Tools...${RESET}"
  apt install -y build-essential libx11-dev libxft-dev libxinerama-dev feh xinit alacritty git curl unzip

  mkdir -p /home/$SUDO_USER/.config/dwm
  cd /home/$SUDO_USER/.config/dwm

  git clone https://git.suckless.org/dwm
  cd dwm
  make clean install
  cd ..

  echo 'exec dwm' > /home/$SUDO_USER/.xinitrc
  chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/dwm /home/$SUDO_USER/.xinitrc
  echo -e "${GREEN}✔ DWM installiert.${RESET}"
  read -rp "Weiter mit Enter..."
  ;;
# ────────────────────────────────────────────────
6)
  echo -e "${YELLOW}→ Wallpaper aktivieren...${RESET}"
  WALLPAPER="/home/$SUDO_USER/.config/dwm/wallpaper.png"
  if [[ -f "$WALLPAPER" ]]; then
    echo "feh --bg-scale $WALLPAPER" > /home/$SUDO_USER/.fehbg
    chmod +x /home/$SUDO_USER/.fehbg
    if ! grep -q ".fehbg" /home/$SUDO_USER/.xinitrc; then
      echo "~/.fehbg &" >> /home/$SUDO_USER/.xinitrc
    fi
    echo -e "${GREEN}✔ Wallpaper hinzugefügt.${RESET}"
  else
    echo -e "${RED}Kein wallpaper.png gefunden! Bitte in ~/.config/dwm legen.${RESET}"
  fi
  read -rp "Weiter mit Enter..."
  ;;
# ────────────────────────────────────────────────
7)
  echo -e "${YELLOW}→ Installiere Zen Kernel...${RESET}"
  apt install -y linux-image-zen linux-headers-zen || {
    echo -e "${RED}Zen Kernel nicht in Repo gefunden. Füge Sid Repo hinzu...${RESET}"
    echo "deb http://deb.debian.org/debian sid main contrib non-free non-free-firmware" > /etc/apt/sources.list.d/sid.list
    apt update
    apt install -y linux-image-zen linux-headers-zen
  }
  echo -e "${GREEN}✔ Zen Kernel installiert.${RESET}"
  echo -e "${YELLOW}Bitte nach Installation neu starten, um Zen Kernel zu nutzen.${RESET}"
  read -rp "Weiter mit Enter..."
  ;;
# ────────────────────────────────────────────────
8)
  echo -e "${YELLOW}→ Prüfe Fish-Autostart-Konfiguration...${RESET}"
  if grep -q "exec startx" /home/$SUDO_USER/.config/fish/config.fish; then
    echo -e "${GREEN}✔ Fish-Autostart ist bereits aktiv.${RESET}"
  else
    echo -e "${RED}Fish wurde noch nicht konfiguriert. Bitte Menüpunkt 2 zuerst ausführen.${RESET}"
  fi
  read -rp "Weiter mit Enter..."
  ;;
# ────────────────────────────────────────────────
9)
  echo -e "${YELLOW}→ Starte System neu...${RESET}"
  sleep 2
  reboot
  ;;
# ────────────────────────────────────────────────
10)
  clear
  echo -e "${GREEN}Installation abgeschlossen!${RESET}"
  echo -e "${YELLOW}Nach dem Login auf TTY1 startet DWM automatisch über Fish.${RESET}"
  exit 0
  ;;
esac
done
