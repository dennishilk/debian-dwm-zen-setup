#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────
#  Debian 13 DWM Setup Script by Dennis Hilk
# ─────────────────────────────────────────────

abort(){ echo "❌ Fehler: $1" >&2; exit 1; }

# ── Debian-Check
if [ -f /etc/os-release ]; then . /etc/os-release; else abort "/etc/os-release nicht gefunden."; fi
if [ "$ID" != "debian" ] || [[ "$VERSION_ID" != "13" && "$VERSION_CODENAME" != "trixie" ]]; then
  abort "Dieses Skript ist nur für Debian 13 (Trixie)."
fi
echo "✅ Debian 13 erkannt – Installation startet ..."

sudo apt update && sudo apt install -y dialog git curl wget build-essential feh unzip lsb-release pciutils lm-sensors bc make gcc

# ── Zen-Kernel optional
if dialog --yesno "Zen-Kernel installieren?" 8 40; then
  sudo apt install -y linux-image-zen linux-headers-zen || echo "⚠️ Zen-Kernel evtl. nicht im Repo verfügbar."
fi

# ── GPU-Treiber optional
if dialog --yesno "Aktuelle GPU-Treiber installieren?" 8 45; then
  if lspci | grep -qi nvidia; then sudo apt install -y nvidia-driver nvidia-kernel-dkms
  elif lspci | grep -qi amd; then sudo apt install -y firmware-amd-graphics
  elif lspci | grep -qi intel; then sudo apt install -y i965-driver intel-media-va-driver-non-free
  else echo "❔ Keine unterstützte GPU erkannt."; fi
fi

# ── Tastatur-/Sprachauswahl
KEYBOARD=$(dialog --menu "Wähle Tastatur-Layout / Keyboard layout:" 15 60 6 \
1 "Deutsch (DE nodeadkeys)" \
2 "English (US)" \
3 "Français (FR)" \
4 "Español (ES)" \
5 "Italiano (IT)" \
6 "Polski (PL)" 3>&1 1>&2 2>&3)
case $KEYBOARD in
  1) XKB_LAYOUT="de nodeadkeys";;
  2) XKB_LAYOUT="us";;
  3) XKB_LAYOUT="fr";;
  4) XKB_LAYOUT="es";;
  5) XKB_LAYOUT="it";;
  6) XKB_LAYOUT="pl";;
  *) XKB_LAYOUT="us";;
esac
clear; echo "⌨️  Tastatur-Layout: $XKB_LAYOUT"

# ── Browser-Menü
BROWSERS=$(dialog --checklist "Wähle Browser zur Installation:" 15 60 5 \
1 "Firefox ESR" on 2 "Brave" off 3 "Chromium" off 4 "Zen Browser" off 5 "Google Chrome" off 3>&1 1>&2 2>&3)
clear
for choice in $BROWSERS; do
  case $choice in
    1) sudo apt install -y firefox-esr ;;
    2) sudo apt install -y apt-transport-https curl; \
       curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg; \
       echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list; \
       sudo apt update && sudo apt install -y brave-browser ;;
    3) sudo apt install -y chromium ;;
    4) wget -O zen.deb https://github.com/zen-browser/desktop/releases/latest/download/zen-browser-linux-amd64.deb && sudo apt install -y ./zen.deb ;;
    5) wget -O chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && sudo apt install -y ./chrome.deb ;;
  esac
done

# ── Extra-Tools
EXTRAS=$(dialog --checklist "Wähle weitere Tools:" 20 70 8 \
1 "OBS Studio" off 2 "VSCodium" off 3 "GIMP" off 4 "Audacity" off 5 "Blender" off 6 "Steam" off 7 "Lutris" off 8 "VirtualBox" off 3>&1 1>&2 2>&3)
clear
for choice in $EXTRAS; do
  case $choice in
    1) sudo apt install -y obs-studio ;;
    2) sudo apt install -y apt-transport-https curl gpg; \
       curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | sudo gpg --dearmor -o /usr/share/keyrings/vscodium.gpg; \
       echo "deb [signed-by=/usr/share/keyrings/vscodium.gpg] https://download.vscodium.com/debs vscodium main" | sudo tee /etc/apt/sources.list.d/vscodium.list; \
       sudo apt update && sudo apt install -y codium ;;
    3) sudo apt install -y gimp ;;
    4) sudo apt install -y audacity ;;
    5) sudo apt install -y blender ;;
    6) sudo sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list; \
       sudo dpkg --add-architecture i386; \
       wget -O /tmp/valve.gpg https://repo.steampowered.com/steam/archive/stable/steam.gpg; \
       sudo install -Dm644 /tmp/valve.gpg /etc/apt/trusted.gpg.d/steam.gpg; \
       echo "deb [arch=amd64,i386 signed-by=/etc/apt/trusted.gpg.d/steam.gpg] https://repo.steampowered.com/steam/ stable steam" | sudo tee /etc/apt/sources.list.d/steam.list; \
       sudo apt update && sudo apt install -y steam-launcher ;;
    7) sudo apt install -y lutris ;;
    8) sudo apt install -y virtualbox ;;
  esac
done

# ── Basis-Pakete
sudo apt install -y xorg xinit picom alacritty fish htop tmux fastfetch git feh \
pipewire wireplumber pipewire-audio pipewire-pulse timeshift zram-tools \
libx11-dev libxft-dev libxinerama-dev libxrandr-dev libxrender-dev libxext-dev unzip

# ── Nerd-Font-Installer
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
FONT_DIR="$HOME/.local/share/fonts"; ZIP_PATH="/tmp/JetBrainsMono.zip"; mkdir -p "$FONT_DIR"
animate_bar(){ local d=$1 s=0 w=40; while [ $s -le $d ]; do p=$((s*100/d)); f=$((p*w/100)); e=$((w-f)); printf "\r["; for((i=0;i<f;i++));do printf "▰";done; for((i=0;i<e;i++));do printf "▱";done; printf "] %3d%%" "$p"; sleep 0.05; s=$((s+1)); done; echo; }
echo "🧩 Installing JetBrainsMono Nerd Font ..."; wget -q "$FONT_URL" -O "$ZIP_PATH" & pid=$!; while ps -p $pid >/dev/null 2>&1; do animate_bar 20; done; echo
unzip -o "$ZIP_PATH" -d "$FONT_DIR" >/dev/null; fc-cache -fv >/dev/null; echo "✅ Font ready!"

# ── ZRAM
sudo sed -i 's/^#\?ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#\?PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo systemctl enable --now zramswap.service

# ── Wallpaper + .xinitrc
mkdir -p ~/.config/dwm; [ -f ./wallpaper.png ] && cp ./wallpaper.png ~/.config/dwm/
cat > ~/.xinitrc <<EOF
#!/bin/bash
export PATH="\$HOME/.config/dwm/bin:\$PATH"
setxkbmap $XKB_LAYOUT &
if [ ! -x "\$HOME/.config/dwm/bin/dwm" ]; then
  echo "❌ DWM nicht gefunden! → cd ~/.config/dwm/src/dwm && make"
  exit 1
fi
xrandr --output "\$(xrandr | awk '/ connected/{print \$1;exit}')" --auto
feh --bg-fill ~/.config/dwm/wallpaper.png &
picom --config ~/.config/dwm/picom.conf &
exec dwm
EOF
chmod +x ~/.xinitrc

# ── Auto-Login DWM
if ! grep -q "startx" ~/.bash_profile 2>/dev/null; then cat >> ~/.bash_profile <<'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  startx
fi
EOF
fi

# ── Picom + Alacritty
cat > ~/.config/dwm/picom.conf <<'EOF'
backend="glx"; vsync=true; corner-radius=12;
opacity-rule=[ "90:class_g = 'Alacritty'" ]; shadow=true; fading=true;
EOF
mkdir -p ~/.config/alacritty
cat > ~/.config/alacritty/alacritty.yml <<'EOF'
window: {opacity: 0.9, decorations: full, padding: {x: 10, y: 10}}
font: {normal: {family: "JetBrainsMono Nerd Font"}, size: 12}
colors: {primary: {background: "0x0f111a", foreground: "0xc5c8c6"}}
shell: {program: /usr/bin/fish}
EOF

# ── Fish Dashboard
chsh -s /usr/bin/fish
sudo mkdir -p /var/lib; [ ! -f /var/lib/system-uptime.db ] && echo "0" | sudo tee /var/lib/system-uptime.db >/dev/null
mkdir -p ~/.config/fish
cat > ~/.config/fish/config.fish <<'EOF'
function fish_greeting
  set_color cyan
  echo "🐧 "(lsb_release -ds)" "(uname -m)
  echo "──────────────────────────────────────────────"
  set_color green
  echo "🧠 Host:" (hostname)
  echo "⚙️ Kernel:" (uname -r)
  echo "⏱️ Uptime:" (uptime -p | sed 's/up //')
  set u (awk '{print int($1)}' /proc/uptime)
  set s (cat /var/lib/system-uptime.db 2>/dev/null; or echo 0)
  if not string match -rq '^[0-9]+$' -- $s; set s 0; end
  set n (math $u + $s ^/dev/null)
  echo $n | sudo tee /var/lib/system-uptime.db >/dev/null
  set d (math "scale=2; $n / 86400" 2>/dev/null)
  echo "🕓 Total system uptime:" $d" days"
  echo "📦 Packages:" (dpkg -l | grep '^ii' | wc -l)" (apt)"
  echo "💻 Shell:" (fish --version | awk '{print $3}')
  echo "🧩 WM: dwm"
  echo "🖥️ CPU:" (lscpu | awk -F: '/Model name/ {print $2}' | sed 's/^ *//')
  echo "🎮 GPU:" (lspci | grep -E "VGA|3D" | awk -F ': ' '{print $3}' | head -n1)
  echo "💽 Disk:" (df -h / | awk 'NR==2 {print $5 " of " $2}')
  echo "💾 RAM:" (free -h | awk '/Mem/ {print $3 " / " $2}')
  echo "🧮 ZRAM:" (systemctl is-active zramswap.service)
  echo "🔊 Audio: PipeWire active"
  if test -d /timeshift; echo "💾 Timeshift: enabled"; else echo "💾 Timeshift: not found"; end
  echo "──────────────────────────────────────────────"
  echo "✨ Tip: F2 → fastfetch | F3 → htop | exit → logout"
  set_color normal
end
EOF

# ── DWM + Tools lokal unter ~/.config/dwm
mkdir -p ~/.config/dwm/src ~/.config/dwm/bin
cd ~/.config/dwm/src

for repo in dwm dmenu slstatus; do
  echo "🧩 Clone & build $repo ..."
  git clone https://git.suckless.org/$repo
  cd $repo
  sed -i "s|^PREFIX = .*|PREFIX = \$(HOME)/.config/dwm|" config.mk
  if [ "$repo" = "dwm" ]; then
    sed -i 's|"st", NULL|"alacritty", NULL|' config.def.h
    sed -i 's|Mod1Mask|Mod4Mask|' config.def.h
  fi
  make clean install
  cd ..
done
cd ~

# ── PATH
echo 'export PATH="$HOME/.config/dwm/bin:$PATH"' >> ~/.bashrc
echo 'set -Ux PATH $HOME/.config/dwm/bin $PATH' | fish

# ── Fertig
echo
echo "✅ Installation abgeschlossen!"
echo "🧠 Automatischer Start in DWM nach Login auf TTY1"
echo "⌨️ Tastaturlayout: $XKB_LAYOUT"
echo "🎨 DWM + Tools: ~/.config/dwm/bin"
echo "🎮 Steam-Fix, ZRAM, PipeWire, Fish & Fastfetch aktiv."
