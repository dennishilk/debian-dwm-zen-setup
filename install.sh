#!/usr/bin/env bash
set -euo pipefail

echo "🐧 Debian 13 DWM Ultimate v7.3 – by Dennis Hilk"
sleep 1

# ───────────────────────────────────────────────
# 0️⃣ Grundpakete
# ───────────────────────────────────────────────
sudo apt update
sudo apt install -y dialog git curl wget build-essential xorg xinit feh

# ───────────────────────────────────────────────
# 1️⃣ Tastaturlayout-Auswahl
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
sudo tee /etc/default/keyboard >/dev/null <<EOF
XKBLAYOUT="$XKB_LAYOUT"
XKBVARIANT="$XKB_VARIANT"
BACKSPACE="guess"
EOF
sudo dpkg-reconfigure -f noninteractive keyboard-configuration
sudo localectl set-x11-keymap "$XKB_LAYOUT" "$XKB_VARIANT"

mkdir -p ~/.config/fish
grep -qxF "setxkbmap $XKB_LAYOUT $XKB_VARIANT &" ~/.xinitrc || echo "setxkbmap $XKB_LAYOUT $XKB_VARIANT &" >> ~/.xinitrc
grep -qxF "setxkbmap $XKB_LAYOUT $XKB_VARIANT" ~/.config/fish/config.fish || echo "setxkbmap $XKB_LAYOUT $XKB_VARIANT" >> ~/.config/fish/config.fish
setxkbmap "$XKB_LAYOUT" "$XKB_VARIANT"
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
    3) sudo apt install -y apt-transport-https curl; curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg >/dev/null; echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list; sudo apt update && sudo apt install -y brave-browser ;;
    4) sudo apt install -y ungoogled-chromium ;;
  esac
done

# ───────────────────────────────────────────────
# 3️⃣ Systemtools & Themes
# ───────────────────────────────────────────────
sudo apt install -y fish alacritty rofi dunst picom flameshot playerctl brightnessctl \
arc-theme papirus-icon-theme bibata-cursor-theme fonts-jetbrains-mono fonts-noto-color-emoji \
zram-tools pipewire pipewire-audio pipewire-pulse wireplumber tlp lm-sensors feh

chsh -s /usr/bin/fish

# ───────────────────────────────────────────────
# 4️⃣ DWM + Tools
# ───────────────────────────────────────────────
mkdir -p ~/.config/dwm/src
cd ~/.config/dwm/src
for repo in dwm dmenu slstatus; do
  [ -d "$repo" ] || git clone "https://git.suckless.org/$repo"
done

cd dwm && sudo make clean install && cd ..
cd dmenu && sudo make clean install && cd ..

cd slstatus
cat > config.def.h <<'EOF'
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
make clean install
cd ~

# ───────────────────────────────────────────────
# 5️⃣ Theme & Transparenz
# ───────────────────────────────────────────────
mkdir -p ~/.config/dwm/autostart ~/.config/picom ~/.config/alacritty

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

grep -qxF 'bash ~/.config/dwm/autostart.sh &' ~/.xinitrc || echo 'bash ~/.config/dwm/autostart.sh &' >> ~/.xinitrc

# ───────────────────────────────────────────────
# 6️⃣ Hotkeys + PowerMenu + SystemInfo
# ───────────────────────────────────────────────
cd ~/.config/dwm/src/dwm
[ -f config.def.h ] || { echo "❌ DWM config.def.h nicht gefunden"; exit 1; }
cp -n config.def.h config.def.h.bak || true
sed -i '1i #include <X11/XF86keysym.h>' config.def.h
sed -i 's/Mod1Mask/Mod4Mask/g' config.def.h
sed -i 's|"st"|"alacritty"|g' config.def.h

# PowerMenu Script
mkdir -p ~/.local/bin
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

# Volume OSD + System Info Popup (Super+I)
cat > ~/.local/bin/vol-overlay <<'EOF'
#!/usr/bin/env bash
vol=$(pactl get-sink-volume @DEFAULT_SINK@ | awk '{print $5}' | head -n1)
notify-send -h int:value:${vol%\%} -h string:synchronous:volume "🔊 Volume: $vol"
EOF
chmod +x ~/.local/bin/vol-overlay

cat > ~/.local/bin/sysinfo-popup <<'EOF'
#!/usr/bin/env bash
info="$(hostnamectl | grep -E 'Operating System|Kernel' | sed 's/^ *//')
Uptime: $(uptime -p)
CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -c14-)
RAM: $(free -h | awk '/Mem/ {print $3 "/" $2}')"
notify-send "💻 System Info" "$info"
EOF
chmod +x ~/.local/bin/sysinfo-popup

# Keybinds einfügen
if ! grep -q '/* DH-ALL-KEYS-BEGIN */' config.def.h; then
awk '
  /static const Key keys\[\] = \{/ && !f {
    print;
    print "    /* DH-ALL-KEYS-BEGIN */";
    print "    { MODKEY,              XK_Return, spawn, {.v = termcmd } },";
    print "    { MODKEY,              XK_d,      spawn, {.v = (const char*[]){\"rofi\",\"-show\",\"drun\",NULL} } },";
    print "    { 0,                   XF86XK_AudioRaiseVolume, spawn, {.v = (const char*[]){\"/bin/sh\",\"-c\",\"pactl set-sink-volume @DEFAULT_SINK@ +5%; vol-overlay\",NULL} } },";
    print "    { 0,                   XF86XK_AudioLowerVolume, spawn, {.v = (const char*[]){\"/bin/sh\",\"-c\",\"pactl set-sink-volume @DEFAULT_SINK@ -5%; vol-overlay\",NULL} } },";
    print "    { 0,                   XF86XK_AudioMute, spawn, {.v = (const char*[]){\"/bin/sh\",\"-c\",\"pactl set-sink-mute @DEFAULT_SINK@ toggle; vol-overlay\",NULL} } },";
    print "    { 0,                   XK_Print,  spawn, {.v = (const char*[]){\"flameshot\",\"gui\",NULL} } },";
    print "    { MODKEY|ShiftMask,    XK_q,      spawn, {.v = (const char*[]){\"dwm-power-menu\",NULL} } },";
    print "    { MODKEY,              XK_i,      spawn, {.v = (const char*[]){\"sysinfo-popup\",NULL} } },";
    print "    /* DH-ALL-KEYS-END */";
    f=1; next
  }1
' config.def.h > config.tmp && mv config.tmp config.def.h
fi

rm -f config.h
make clean install
cd ~

# ───────────────────────────────────────────────
# 7️⃣ Autostart DWM via TTY1
# ───────────────────────────────────────────────
grep -qxF '[ "$(tty)" = "/dev/tty1" ] && startx' ~/.bash_profile || echo '[ "$(tty)" = "/dev/tty1" ] && startx' >> ~/.bash_profile

# ───────────────────────────────────────────────
# 8️⃣ Abschluss
# ───────────────────────────────────────────────
clear
echo "✅ Debian 13 DWM Ultimate v7.3 fertig!"
echo "🚀 DWM startet automatisch nach Login (TTY1)"
echo "⌨️  Tastatur: $XKB_LAYOUT $XKB_VARIANT"
echo "🎨  Theme: Arc-Dark + Transparenz"
echo "🎹  Hotkeys aktiv (Super = Mod)"
echo "   Super+Return  → Alacritty"
echo "   Super+D       → Rofi"
echo "   Super+I       → System-Info"
echo "   Super+Shift+Q → Power-Menü"
echo "   Print         → Screenshot"
echo "   Lautstärke/Medien/Helligkeitstasten aktiv"
echo
echo "🔁 Neustart empfohlen: sudo reboot"
