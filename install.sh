#!/usr/bin/env bash
set -euo pipefail

echo "🐧 Debian 13 DWM Ultimate v7.3.4 – by Dennis Hilk"
sleep 1

# ───────────────────────────────────────────────
# 0️⃣ Basis & Build-Dependencies
# ───────────────────────────────────────────────
sudo apt update
sudo apt install -y \
  dialog git curl wget build-essential pkg-config \
  xorg xinit feh \
  libx11-dev libxft-dev libxinerama-dev libxrandr-dev libxrender-dev libxext-dev \
  libfreetype6-dev libfontconfig1-dev libnotify-bin

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

sudo tee /etc/default/keyboard >/dev/null <<EOF
XKBLAYOUT="$XKB_LAYOUT"
XKBVARIANT="$XKB_VARIANT"
BACKSPACE="guess"
EOF
sudo dpkg-reconfigure -f noninteractive keyboard-configuration
sudo localectl set-x11-keymap "$XKB_LAYOUT" "$XKB_VARIANT"

mkdir -p ~/.config/fish
touch ~/.config/fish/config.fish ~/.xinitrc
grep -qxF "setxkbmap $XKB_LAYOUT $XKB_VARIANT &" ~/.xinitrc || echo "setxkbmap $XKB_LAYOUT $XKB_VARIANT &" >> ~/.xinitrc
grep -qxF "setxkbmap $XKB_LAYOUT $XKB_VARIANT" ~/.config/fish/config.fish || echo "setxkbmap $XKB_LAYOUT $XKB_VARIANT" >> ~/.config/fish/config.fish

# ───────────────────────────────────────────────
# 2️⃣ Browser-Auswahl
# ───────────────────────────────────────────────
BROWSERS=$(dialog --checklist "Wähle Browser zum Installieren:" 18 60 8 \
1 "Firefox ESR" on 2 "Google Chrome" off 3 "Brave Browser" off 4 "Ungoogled Chromium" off 3>&1 1>&2 2>&3)
clear
for B in $BROWSERS; do
  case $B in
    1) sudo apt install -y firefox-esr;;
    2) wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb && sudo apt install -y /tmp/chrome.deb;;
    3) sudo apt install -y apt-transport-https curl; \
       curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg >/dev/null; \
       echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list; \
       sudo apt update && sudo apt install -y brave-browser;;
    4) sudo apt install -y ungoogled-chromium;;
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
# 4️⃣ DWM + Dmenu (ohne slstatus, lokal)
# ───────────────────────────────────────────────
BASE_DIR="$HOME/.config/dwm/src"
PREFIX_DIR="$HOME/.config/dwm"
BIN_DIR="$PREFIX_DIR/bin"
mkdir -p "$BASE_DIR" "$BIN_DIR"
cd "$BASE_DIR"

for r in dwm dmenu; do
  [ -d "$r" ] || git clone "https://git.suckless.org/$r"
  cd "$r"; git reset --hard HEAD >/dev/null || true; cd "$BASE_DIR"
done

for r in dwm dmenu; do
  sed -i "s|^PREFIX =.*|PREFIX =\$(HOME)/.config/dwm|" "$BASE_DIR/$r/config.mk"
done

# DWM Config
sed -i 's/Mod1Mask/Mod4Mask/g' "$BASE_DIR/dwm/config.def.h" || true
sed -i 's|"st", NULL|"alacritty", NULL|' "$BASE_DIR/dwm/config.def.h" || true

make -C "$BASE_DIR/dwm" clean install
make -C "$BASE_DIR/dmenu" clean install

grep -qxF 'export PATH="$HOME/.config/dwm/bin:$PATH"' ~/.bashrc || echo 'export PATH="$HOME/.config/dwm/bin:$PATH"' >> ~/.bashrc
echo 'set -Ux PATH $HOME/.config/dwm/bin $PATH' >> ~/.config/fish/config.fish 2>/dev/null || true

# ───────────────────────────────────────────────
# 5️⃣ Theme & Autostart
# ───────────────────────────────────────────────
mkdir -p ~/.config/picom ~/.config/alacritty ~/.config/dwm/autostart
cat > ~/.config/picom.conf <<'EOF'
backend="glx"; vsync=true; corner-radius=10;
inactive-opacity=0.9; active-opacity=1.0;
blur-method="dual_kawase"; blur-strength=6;
EOF
cat > ~/.config/alacritty/alacritty.yml <<'EOF'
window: { opacity: 0.9, padding: { x: 8, y: 8 } }
font: { normal: { family: "JetBrainsMono Nerd Font" }, size: 12 }
EOF
echo "picom --config ~/.config/picom.conf &; dunst &" > ~/.config/dwm/autostart.sh
chmod +x ~/.config/dwm/autostart.sh
grep -q 'exec dwm' ~/.xinitrc || cat >> ~/.xinitrc <<'EOF'
export PATH="$HOME/.config/dwm/bin:$PATH"
bash ~/.config/dwm/autostart.sh &
exec dwm
EOF

# ───────────────────────────────────────────────
# 6️⃣ Hotkeys, Power-Menü & Overlays
# ───────────────────────────────────────────────
mkdir -p ~/.local/bin
cat > ~/.local/bin/dwm-power-menu <<'EOF'
#!/usr/bin/env bash
c=$(echo -e "Logout\nRestart\nShutdown\nCancel" | rofi -dmenu -p "Power Menu:")
case "$c" in Logout) pkill -u "$USER" dwm;; Restart) systemctl reboot;; Shutdown) systemctl poweroff;; *) exit 0;; esac
EOF
chmod +x ~/.local/bin/dwm-power-menu
cat > ~/.local/bin/vol-overlay <<'EOF'
#!/usr/bin/env bash
v=$(pactl get-sink-volume @DEFAULT_SINK@ | awk '{print $5}' | head -n1)
notify-send -h int:value:${v%\%} -h string:synchronous:volume "🔊 Volume: $v"
EOF
chmod +x ~/.local/bin/vol-overlay
cat > ~/.local/bin/sysinfo-popup <<'EOF'
#!/usr/bin/env bash
i="$(hostnamectl | grep -E 'Operating System|Kernel' | sed 's/^ *//')
Uptime: $(uptime -p)
CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -c14-)
RAM: $(free -h | awk '/Mem/ {print $3 "/" $2}')"
notify-send "💻 System Info" "$i"
EOF
chmod +x ~/.local/bin/sysinfo-popup

cd "$BASE_DIR/dwm"
sed -i '1i #include <X11/XF86keysym.h>' config.def.h || true
if ! grep -q 'DH-HOTKEYS' config.def.h; then
awk '/static const Key keys\[\] =/{print;print"  /* DH-HOTKEYS */\n  {MODKEY,XK_Return,spawn,{.v=termcmd}},\n  {MODKEY,XK_d,spawn,{.v=(const char*[]){\"rofi\",\"-show\",\"drun\",NULL}}},\n  {0,XF86XK_AudioRaiseVolume,spawn,{.v=(const char*[]){\"/bin/sh\",\"-c\",\"pactl set-sink-volume @DEFAULT_SINK@ +5%; vol-overlay\",NULL}}},\n  {0,XF86XK_AudioLowerVolume,spawn,{.v=(const char*[]){\"/bin/sh\",\"-c\",\"pactl set-sink-volume @DEFAULT_SINK@ -5%; vol-overlay\",NULL}}},\n  {0,XF86XK_AudioMute,spawn,{.v=(const char*[]){\"/bin/sh\",\"-c\",\"pactl set-sink-mute @DEFAULT_SINK@ toggle; vol-overlay\",NULL}}},\n  {0,XK_Print,spawn,{.v=(const char*[]){\"flameshot\",\"gui\",NULL}}},\n  {MODKEY|ShiftMask,XK_q,spawn,{.v=(const char*[]){\"dwm-power-menu\",NULL}}},\n  {MODKEY,XK_i,spawn,{.v=(const char*[]){\"sysinfo-popup\",NULL}}}";next}1' config.def.h > cfg && mv cfg config.def.h
fi
make clean install

# ───────────────────────────────────────────────
# 7️⃣ Autostart DWM (TTY1)
# ───────────────────────────────────────────────
grep -qxF '[ "$(tty)" = "/dev/tty1" ] && startx' ~/.bash_profile || echo '[ "$(tty)" = "/dev/tty1" ] && startx' >> ~/.bash_profile
cat >> ~/.config/fish/config.fish <<'EOF'

if status is-login
  if test -z "$DISPLAY"
    if test (tty) = "/dev/tty1"
      echo "🚀 Starte DWM ..."
      exec startx -- :0 vt1 >/dev/null 2>&1
    end
  end
end
EOF

clear
echo "✅ DWM Ultimate v7.3.4 fertig – ohne slstatus!"
echo "🎯 Kein netspeed, kein battery, kein ld-Fehler"
echo "🚀 Automatischer Start auf TTY1 (Fish + Bash)"
echo "🎹 Hotkeys, Power-Menü, Volume-OSD, System-Info"
echo "💾 Installationspfad: ~/.config/dwm/bin"
echo "🔁 Reboot empfohlen → sudo reboot"
