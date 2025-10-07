#!/usr/bin/env bash
set -e
echo "🎨 Starte DWM Feintuning …"

# GTK + Icon + Cursor Themes
sudo apt install -y arc-theme papirus-icon-theme bibata-cursor-theme
gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark' || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic' || true

# Fonts
sudo apt install -y fonts-noto-color-emoji
fc-cache -fv >/dev/null

# Picom Config
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
inactive-opacity = 0.90;
active-opacity = 1.0;
opacity-rule = [ "90:class_g = 'Alacritty'" ];
blur-method = "dual_kawase";
blur-strength = 6;
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
EOF

# Alacritty Config
mkdir -p ~/.config/alacritty
cat > ~/.config/alacritty/alacritty.yml <<'EOF'
window:
  opacity: 0.9
  padding:
    x: 8
    y: 8
font:
  normal:
    family: "JetBrainsMono Nerd Font"
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

# slstatus Config
mkdir -p ~/.config/dwm/src/slstatus
cat > ~/.config/dwm/src/slstatus/config.def.h <<'EOF'
static const struct arg args[] = {
    /* function format          argument */
    { cpu_perc,   "🧠 %s%% ",  NULL },
    { ram_perc,   "💾 %s%% ",  NULL },
    { vol_perc,   "🔊 %s%% ",  "default" },
    { datetime,   "📅 %s",     "%H:%M | %d.%m.%Y" },
};
EOF
cd ~/.config/dwm/src/slstatus && make clean install

# dunst (Notifications)
sudo apt install -y dunst
mkdir -p ~/.config/dunst
cat > ~/.config/dunst/dunstrc <<'EOF'
[global]
    monitor = 0
    follow = mouse
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

# rofi Launcher
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

# Extra Tools
sudo apt install -y pavucontrol pwvucontrol gamemode mangohud powertop

# Autostart daemons
mkdir -p ~/.config/dwm/autostart
cat > ~/.config/dwm/autostart.sh <<'EOF'
#!/bin/bash
picom --config ~/.config/dwm/picom.conf &
dunst &
EOF
chmod +x ~/.config/dwm/autostart.sh

# Add autostart to .xinitrc
if ! grep -q "autostart.sh" ~/.xinitrc; then
  sed -i '/feh --bg-fill/a bash ~/.config/dwm/autostart.sh &' ~/.xinitrc
fi

echo
echo "✅ Feintuning abgeschlossen!"
echo "🎨 Dark Theme aktiv, Transparenz & Bar konfiguriert"
echo "🔔 Dunst + Rofi + Audio-Tools installiert"
