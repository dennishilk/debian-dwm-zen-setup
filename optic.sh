#!/usr/bin/env bash
set -e
echo "🎨 Optisches Feintuning + Tastaturlayout Fix (v6.8) ..."

# ── GTK, Icons, Cursor
sudo apt install -y arc-theme papirus-icon-theme bibata-cursor-theme fonts-noto-color-emoji
gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic' 2>/dev/null || true

# ── Picom Config (Transparenz + Blur)
mkdir -p ~/.config/dwm ~/.config/picom
cat > ~/.config/dwm/picom.conf <<'EOF'
backend = "glx";
vsync = true;
corner-radius = 10;
shadow = true;
shadow-radius = 12;
shadow-opacity = 0.4;
shadow-offset-x = -10;
shadow-offset-y = -10;
inactive-opacity = 0.9;
active-opacity = 1.0;
opacity-rule = [ "90:class_g = 'Alacritty'" ];
blur-method = "dual_kawase";
blur-strength = 6;
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
EOF

# ── Alacritty Config
mkdir -p ~/.config/alacritty
cat > ~/.config/alacritty/alacritty.yml <<'EOF'
window:
  opacity: 0.9
  padding: { x: 8, y: 8 }
font:
  normal: { family: "JetBrainsMono Nerd Font" }
  size: 12.0
colors:
  primary:
    background: "#1e1e2e"
    foreground: "#d9e0ee"
  cursor:
    text: "#1e1e2e"
    cursor: "#f5e0dc"
  selection:
    background: "#44475a"
    text: "#f8f8f2"
EOF

# ── Dunst Notifications
sudo apt install -y dunst
mkdir -p ~/.config/dunst
cat > ~/.config/dunst/dunstrc <<'EOF'
[global]
    geometry = "300x50-10+40"
    transparency = 10
    frame_color = "#1e1e2e"
    separator_color = frame
    font = JetBrainsMono Nerd Font 10
    icon_theme = Papirus-Dark
[urgency_low]
    background = "#1e1e2e"
    foreground = "#d9e0ee"
[urgency_normal]
    background = "#1e1e2e"
    foreground = "#d9e0ee"
[urgency_critical]
    background = "#ff5555"
    foreground = "#f8f8f2"
EOF

# ── Rofi Launcher
sudo apt install -y rofi
mkdir -p ~/.config/rofi
cat > ~/.config/rofi/config.rasi <<'EOF'
configuration {
  modi: "drun,run";
  font: "JetBrainsMono Nerd Font 12";
  show-icons: true;
  icon-theme: "Papirus-Dark";
  theme: "Arc-Dark";
}
EOF

# ── slstatus mit Netz-Auto-Detection
cd ~/.config/dwm/src/slstatus || exit 1
cat > config.def.h <<'EOF'
/* slstatus config by Dennis Hilk - Debian 13 DWM Ultimate v6.8 */
#include <stdio.h>
#include <time.h>
#include "slstatus.h"
#include "util.h"

static const unsigned int interval = 2;
static const char unknown_str[] = "n/a";
#define MAXLEN 2048

#define NET_CMD "ip route | awk '/default/ {print $5}' | head -n1"

static const struct arg args[] = {
    { cpu_perc,    "🧠 %3s%% ",      NULL },
    { cpu_freq,    "⚙️ %3sGHz ",     NULL },
    { ram_perc,    "💾 %2s%% ",      NULL },
    { temp,        "🌡️ %2s°C ",      "/sys/class/thermal/thermal_zone0/temp" },
    { run_command, "⬇ %s ",          "IF=$( " NET_CMD " ); RX1=$(cat /sys/class/net/$IF/statistics/rx_bytes 2>/dev/null); sleep 1; RX2=$(cat /sys/class/net/$IF/statistics/rx_bytes 2>/dev/null); echo $(((RX2-RX1)/1024))KB/s" },
    { run_command, "⬆ %s ",          "IF=$( " NET_CMD " ); TX1=$(cat /sys/class/net/$IF/statistics/tx_bytes 2>/dev/null); sleep 1; TX2=$(cat /sys/class/net/$IF/statistics/tx_bytes 2>/dev/null); echo $(((TX2-TX1)/1024))KB/s" },
    { vol_perc,    "🔊 %s%% ",       "default" },
    { uptime,      "⏱️ %s ",         NULL },
    { datetime,    "📅 %s",          "%H:%M | %d.%m.%Y" },
};
EOF

rm -f config.h
make clean install
pkill slstatus 2>/dev/null || true
slstatus &

# ── Autostart (Picom + Dunst)
mkdir -p ~/.config/dwm/autostart
cat > ~/.config/dwm/autostart.sh <<'EOF'
#!/bin/bash
picom --config ~/.config/dwm/picom.conf &
dunst &
EOF
chmod +x ~/.config/dwm/autostart.sh

# ── Autostart in .xinitrc registrieren
if ! grep -q "autostart.sh" ~/.xinitrc; then
  sed -i '/feh --bg-fill/a bash ~/.config/dwm/autostart.sh &' ~/.xinitrc
fi

# ── Tastaturlayout Fix (deutsch dauerhaft)
echo "⌨️  Fixiere deutsches Tastaturlayout ..."
sudo tee /etc/default/keyboard >/dev/null <<'EOF'
XKBLAYOUT="de"
XKBVARIANT="nodeadkeys"
BACKSPACE="guess"
EOF
sudo dpkg-reconfigure -f noninteractive keyboard-configuration
sudo localectl set-x11-keymap de nodeadkeys

# .xinitrc absichern
if ! grep -q "setxkbmap de nodeadkeys" ~/.xinitrc; then
  sed -i '/^setxkbmap/d' ~/.xinitrc 2>/dev/null || true
  sed -i '/xrandr --output/i setxkbmap de nodeadkeys &' ~/.xinitrc
fi

# Fish-Sessions absichern
if ! grep -q "setxkbmap de nodeadkeys" ~/.config/fish/config.fish; then
  echo "setxkbmap de nodeadkeys" >> ~/.config/fish/config.fish
fi

echo
echo "✅ Optisches Feintuning v6.8 abgeschlossen!"
echo "🎨 Dark Theme aktiv (Arc-Dark + Papirus-Dark + Bibata Cursor)"
echo "🌫️ Picom Blur & Alacritty Transparenz gesetzt"
echo "🧠 slstatus mit Auto-Netz & Layout-Fix kompiliert"
echo "⌨️  Tastaturlayout dauerhaft: Deutsch (nodeadkeys)"
echo "🔔 Dunst & Rofi starten automatisch"
