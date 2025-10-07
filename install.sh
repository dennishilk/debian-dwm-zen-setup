#!/usr/bin/env bash
set -euo pipefail

echo "🐧 Debian 13 DWM Ultimate v7.3.2 – by Dennis Hilk"
sleep 1

# ───────────────────────────────────────────────
# 0️⃣ Basis & Build-Dependencies
# ───────────────────────────────────────────────
sudo apt update
sudo apt install -y \
  dialog git curl wget build-essential pkg-config \
  xorg xinit feh \
  libx11-dev libxft-dev libxinerama-dev libxrandr-dev libxrender-dev libxext-dev \
  libfreetype6-dev libfontconfig1-dev \
  libnotify-bin

# ───────────────────────────────────────────────
# 1️⃣ Tastaturlayout-Auswahl (robust & persistent)
# ───────────────────────────────────────────────
KEYBOARD=$(dialog --menu "Wähle Tastatur-Layout:" 15 60 6 \
1 "Deutsch (nodeadkeys)" 2 "English (US)" 3 "Français" 4 "Español" 5 "Italiano" 6 "Polski" 3>&1 1>&2 2>&3)

case $KEYBOARD in
  1) XKB_LAYOUT="de"; XKB_VARIANT="nodeadkeys";;
  2) XKB_LAYOUT="us"; XKB_VARIANT="";;
  3) XKB_LAYOUT="fr"; XKB_VARIANT="";;
  4) XKB_LAYOUT="es"; XKB_VARIANT="";;
  5) XKB_LAYOUT="it"; XKB_VARIANT="";;
  6) XKB_LAYOUT="pl"; XKB_VARIANT="";;
  *) XKB_LAYOUT="us"; XKB_VARIANT="";;
esac

clear
echo "⌨️  Setze Tastaturlayout auf $XKB_LAYOUT $XKB_VARIANT ..."
sleep 1

sudo tee /etc/default/keyboard >/dev/null <<EOF
XKBLAYOUT="$XKB_LAYOUT"
XKBVARIANT="$XKB_VARIANT"
BACKSPACE="guess"
EOF
sudo dpkg-reconfigure -f noninteractive keyboard-configuration
sudo localectl set-x11-keymap "$XKB_LAYOUT" "$XKB_VARIANT"

mkdir -p ~/.config/fish
touch ~/.config/fish/config.fish
touch ~/.xinitrc

grep -qxF "setxkbmap $XKB_LAYOUT $XKB_VARIANT &" ~/.xinitrc || echo "setxkbmap $XKB_LAYOUT $XKB_VARIANT &" >> ~/.xinitrc
grep -qxF "setxkbmap $XKB_LAYOUT $XKB_VARIANT" ~/.config/fish/config.fish || echo "setxkbmap $XKB_LAYOUT $XKB_VARIANT" >> ~/.config/fish/config.fish

if command -v setxkbmap >/dev/null 2>&1; then
  setxkbmap "$XKB_LAYOUT" "$XKB_VARIANT" 2>/dev/null || echo "💡 Hinweis: Layout wird beim nächsten Startx aktiv."
fi

dialog --msgbox "Tastaturlayout dauerhaft auf $XKB_LAYOUT $XKB_VARIANT gesetzt." 7 55
clear

# ───────────────────────────────────────────────
# 2️⃣ Browser-Auswahl
# ───────────────────────────────────────────────
BROWSERS=$(dialog --checklist "Wähle Browser zum Installieren:" 18 60 8 \
1 "Firefox ESR" on \
2 "Google Chrome" off \
3 "Brave Browser" off \
4 "Ungoogled Chromium" off 3>&1 1>&2 2>&3)

clear; echo "🌐 Installiere Browser ..."
for B in $BROWSERS; do
  case $B in
    1) sudo apt install -y firefox-esr ;;
    2) wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb && sudo apt install -y /tmp/chrome.deb ;;
    3) sudo apt install -y apt-transport-https curl; \
       curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg >/dev/null; \
       echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list; \
       sudo apt update && sudo apt install -y brave-browser ;;
    4) sudo apt install -y ungoogled-chromium ;;
  esac
done

# ───────────────────────────────────────────────
# 3️⃣ Systemtools & Themes
# ───────────────────────────────────────────────
sudo apt install -y \
  fish alacritty rofi dunst picom flameshot playerctl brightnessctl \
  arc-theme papirus-icon-theme bibata-cursor-theme \
  fonts-jetbrains-mono fonts-noto-color-emoji \
  zram-tools pipewire pipewire-audio pipewire-pulse wireplumber tlp lm-sensors

# Fish als Standard-Shell
chsh -s /usr/bin/fish

# ───────────────────────────────────────────────
# 4️⃣ DWM + Dmenu + Slstatus – Build nach ~/.config/dwm (ohne sudo)
# ───────────────────────────────────────────────
BASE_DIR="$HOME/.config/dwm/src"
PREFIX_DIR="$HOME/.config/dwm"          # hierhin wird installiert
BIN_DIR="$PREFIX_DIR/bin"

mkdir -p "$BASE_DIR" "$BIN_DIR"
cd "$BASE_DIR"

for repo in dwm dmenu slstatus; do
  echo "📦 Prüfe Repository: $repo ..."
  if [ ! -d "$repo" ]; then
    echo "⬇️  Klone $repo ..."
    git clone "https://git.suckless.org/$repo" || { echo "❌ Fehler beim Klonen von $repo"; exit 1; }
  else
    cd "$repo"
    git pull --rebase || echo "⚠️  Pull fehlgeschlagen, verwende lokale Version."
    cd "$BASE_DIR"
  fi
done

# config.mk in allen Projekten auf PREFIX=$HOME/.config/dwm setzen
for dir in dwm dmenu slstatus; do
  [ -f "$BASE_DIR/$dir/config.mk" ] || { echo "❌ $dir/config.mk fehlt."; exit 1; }
  sed -i "s|^PREFIX = .*|PREFIX = \$(HOME)/.config/dwm|" "$BASE_DIR/$dir/config.mk"
done

# DWM: Super als Mod, Alacritty als Terminal
sed -i 's/Mod1Mask/Mod4Mask/g' "$BASE_DIR/dwm/config.def.h" || true
sed -i 's|"st", NULL|"alacritty", NULL|' "$BASE_DIR/dwm/config.def.h" || true

# Slstatus minimal (ohne Netz & Akku)
cat > "$BASE_DIR/slstatus/config.def.h" <<'EOF'
#include <stdio.h>
#include <time.h>
#include "slstatus.h"
#include "util.h"
static const unsigned int interval = 2;
static const char unknown_str[] = "n/a";
#define MAXLEN 2048
static const struct arg args[] = {
  { cpu_perc, "🧠 %3s%% ", NULL },
  { cpu_freq, "⚙️ %3sGHz ", NULL },
  { ram_perc, "💾 %2s%% ", NULL },
  { temp, "🌡️ %2s°C ", "/sys/class/thermal/thermal_zone0/temp" },
  { uptime, "⏱️ %s ", NULL },
  { datetime, "📅 %s", "%H:%M | %d.%m.%Y" },
};
EOF
rm -f "$BASE_DIR/slstatus/config.h" || true

# Build & Install (lokal, ohne sudo)
make -C "$BASE_DIR/dwm" clean install
make -C "$BASE_DIR/dmenu" clean install
make -C "$BASE_DIR/slstatus" clean install

# PATH für Bash & Fish setzen
grep -qxF 'export PATH="$HOME/.config/dwm/bin:$PATH"' ~/.bashrc || echo 'export PATH="$HOME/.config/dwm/bin:$PATH"' >> ~/.bashrc
if ! grep -q 'set -Ux PATH' ~/.config/fish/config.fish 2>/dev/null; then
  echo 'set -Ux PATH $HOME/.config/dwm/bin $PATH' >> ~/.config/fish/config.fish
fi

# ───────────────────────────────────────────────
# 5️⃣ Theme, Picom, Alacritty, Autostart
# ───────────────────────────────────────────────
mkdir -p ~/.config/picom ~/.config/alacritty ~/.config/dwm/autostart

cat > ~/.config/picom.conf <<'EOF'
backend = "glx";
vsync = true;
corner-radius = 10;
inactive-opacity = 0.9;
active-opacity = 1.0;
blur-method = "dual_kawase";
blur-strength = 6;
EOF

cat > ~/.config/alacritty/alacritty.yml <<'EOF'
window:
  opacity: 0.9
  padding: { x: 8, y: 8 }
font:
  normal: { family: "JetBrainsMono Nerd Font" }
  size: 12.0
EOF

cat > ~/.config/dwm/autostart.sh <<'EOF'
#!/bin/bash
picom --config ~/.config/picom.conf &
dunst &
EOF
chmod +x ~/.config/dwm/autostart.sh

# .xinitrc vervollständigen (DWM + Autostart + PATH)
if ! grep -q 'exec dwm' ~/.xinitrc; then
  cat >> ~/.xinitrc <<'EOF'
export PATH="$HOME/.config/dwm/bin:$PATH"
xrandr --output "$(xrandr | awk '/ connected/{print $1;exit}')" --auto
feh --bg-fill ~/Pictures/wallpaper.png 2>/dev/null &
bash ~/.config/dwm/autostart.sh &
exec dwm
EOF
fi

# ───────────────────────────────────────────────
# 6️⃣ Hotkeys + Power-Menü + Overlays in DWM (lokal)
# ───────────────────────────────────────────────
DWM_DIR="$BASE_DIR/dwm"
cd "$DWM_DIR"
cp -n config.def.h config.def.h.bak || true
sed -i '1i #include <X11/XF86keysym.h>' config.def.h || true

mkdir -p ~/.local/bin

# Power-Menü (Rofi)
cat > ~/.local/bin/dwm-power-menu <<'EOF'
#!/usr/bin/env bash
choice=$(echo -e "Logout\nRestart\nShutdown\nCancel" | rofi -dmenu -p "Power Menu:")
case "$choice" in
  Logout)   pkill -u "$USER" dwm ;;
  Restart)  systemctl reboot ;;
  Shutdown) systemctl poweroff ;;
  *) exit 0 ;;
esac
EOF
chmod +x ~/.local/bin/dwm-power-menu

# Volume OSD
cat > ~/.local/bin/vol-overlay <<'EOF'
#!/usr/bin/env bash
vol=$(pactl get-sink-volume @DEFAULT_SINK@ | awk '{print $5}' | head -n1)
notify-send -h int:value:${vol%\%} -h string:synchronous:volume "🔊 Volume: $vol"
EOF
chmod +x ~/.local/bin/vol-overlay

# System Info Popup (Super+I)
cat > ~/.local/bin/sysinfo-popup <<'EOF'
#!/usr/bin/env bash
info="$(hostnamectl | grep -E 'Operating System|Kernel' | sed 's/^ *//')
Uptime: $(uptime -p)
CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -c14-)
RAM: $(free -h | awk '/Mem/ {print $3 "/" $2}')"
notify-send "💻 System Info" "$info"
EOF
chmod +x ~/.local/bin/sysinfo-popup

# Keybinds einfügen (nur einmal)
if ! grep -q '/* DH-HOTKEYS-BEGIN */' config.def.h; then
  awk '
    /static const Key keys\[\] = \{/ && !f {
      print;
      print "    /* DH-HOTKEYS-BEGIN */";
      print "    { MODKEY,              XK_Return, spawn, {.v = termcmd } },";
      print "    { MODKEY,              XK_d,      spawn, {.v = (const char*[]){\"rofi\",\"-show\",\"drun\",NULL} } },";
      print "    { 0,                   XF86XK_AudioRaiseVolume, spawn, {.v = (const char*[]){\"/bin/sh\",\"-c\",\"pactl set-sink-volume @DEFAULT_SINK@ +5%; vol-overlay\",NULL} } },";
      print "    { 0,                   XF86XK_AudioLowerVolume, spawn, {.v = (const char*[]){\"/bin/sh\",\"-c\",\"pactl set-sink-volume @DEFAULT_SINK@ -5%; vol-overlay\",NULL} } },";
      print "    { 0,                   XF86XK_AudioMute,        spawn, {.v = (const char*[]){\"/bin/sh\",\"-c\",\"pactl set-sink-mute @DEFAULT_SINK@ toggle; vol-overlay\",NULL} } },";
      print "    { 0,                   XK_Print,  spawn, {.v = (const char*[]){\"flameshot\",\"gui\",NULL} } },";
      print "    { MODKEY|ShiftMask,    XK_q,      spawn, {.v = (const char*[]){\"dwm-power-menu\",NULL} } },";
      print "    { MODKEY,              XK_i,      spawn, {.v = (const char*[]){\"sysinfo-popup\",NULL} } },";
      print "    /* DH-HOTKEYS-END */";
      f=1; next
    }1
  ' config.def.h > config.tmp && mv config.tmp config.def.h
fi

# Terminal/ModKey sicherstellen
sed -i 's/Mod1Mask/Mod4Mask/g' config.def.h || true
sed -i 's|"st"|"alacritty"|g' config.def.h || true

rm -f config.h
make clean install
cd ~

# ───────────────────────────────────────────────
# 7️⃣ Autostart DWM (TTY1) – robust für Bash & Fish
# ───────────────────────────────────────────────
# Fallback für Bash-Logins
grep -qxF '[ "$(tty)" = "/dev/tty1" ] && startx' ~/.bash_profile || echo '[ "$(tty)" = "/dev/tty1" ] && startx' >> ~/.bash_profile

# Primär: Fish-Login startet X auf TTY1
if ! grep -q 'exec startx -- :0 vt1' ~/.config/fish/config.fish 2>/dev/null; then
  cat >> ~/.config/fish/config.fish <<'EOF'

# Auto-Start DWM auf TTY1 (robust)
if status is-login
  if test -z "$DISPLAY"
    if test (tty) = "/dev/tty1"
      echo "🚀 Starte DWM ..."
      exec startx -- :0 vt1 >/dev/null 2>&1
    end
  end
end
EOF
fi

# ───────────────────────────────────────────────
# ✅ Fertig
# ───────────────────────────────────────────────
clear
echo "✅ Debian 13 DWM Ultimate v7.3.2 installiert (lokal, dev-libs vorhanden)!"
echo "🛠️  Build-Dev-Pakete installiert: X11/Xft/Xinerama/Xrandr/Xrender/Xext/Freetype/Fontconfig"
echo "📦 Installationspfad: $HOME/.config/dwm/bin (kein sudo nötig)"
echo "🎹 Hotkeys aktiv • 🔌 Power-Menü • 🔔 Overlays"
echo "🚀 Autostart: Fish (TTY1) + Fallback Bash"
echo
echo "🔁 Abmelden und auf TTY1 neu anmelden – DWM startet automatisch."
