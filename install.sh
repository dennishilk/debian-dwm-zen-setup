#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────
# Debian 13 DWM Ultimate v6  –  by Dennis Hilk
# Clean build without patches, with wallpaper fix
# ─────────────────────────────────────────────
abort(){ echo "❌ Fehler: $1" >&2; exit 1; }

# ── nicht als root ausführen
[ "$EUID" -eq 0 ] && abort "⚠️ Bitte NICHT als root starten!"
sudo -v || abort "sudo nicht verfügbar oder falsches Passwort."
# sudo-Keepalive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# ── Debian-Check
. /etc/os-release 2>/dev/null || abort "/etc/os-release fehlt."
[[ "$ID" != "debian" || "$VERSION_CODENAME" != "trixie" ]] && abort "Nur für Debian 13 Trixie!"
echo "✅ Debian 13 erkannt – Installation startet …"

# ── Grundpakete
sudo apt update && sudo apt install -y dialog git curl wget build-essential feh unzip lsb-release pciutils lm-sensors bc make gcc

# ── Zen-Kernel optional
if dialog --yesno "Zen-Kernel installieren?" 8 45; then
  sudo apt install -y linux-image-zen linux-headers-zen || echo "⚠️ Zen-Kernel nicht im Repo."
fi

# ── GPU-Treiber
if dialog --yesno "GPU-Treiber installieren?" 8 45; then
  if lspci | grep -qi nvidia; then sudo apt install -y nvidia-driver nvidia-kernel-dkms
  elif lspci | grep -qi amd; then sudo apt install -y firmware-amd-graphics
  elif lspci | grep -qi intel; then sudo apt install -y i965-driver intel-media-va-driver-non-free
  fi
fi

# ── Tastaturlayout
KEYBOARD=$(dialog --menu "Wähle Tastatur-Layout:" 15 60 6 \
1 "Deutsch (nodeadkeys)" 2 "English (US)" 3 "Français" 4 "Español" 5 "Italiano" 6 "Polski" 3>&1 1>&2 2>&3)
case $KEYBOARD in
  1) XKB="de nodeadkeys";; 2) XKB="us";; 3) XKB="fr";; 4) XKB="es";; 5) XKB="it";; 6) XKB="pl";; *) XKB="us";;
esac

# ── Browser
BROWSERS=$(dialog --checklist "Browser installieren:" 15 60 5 \
1 "Firefox ESR" on 2 "Brave" off 3 "Chromium" off 4 "Zen Browser" off 5 "Chrome" off 3>&1 1>&2 2>&3)
for b in $BROWSERS; do
  case $b in
    1) sudo apt install -y firefox-esr;;
    2) sudo apt install -y apt-transport-https curl; \
      curl -fsSLo /usr/share/keyrings/brave.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg; \
      echo "deb [signed-by=/usr/share/keyrings/brave.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave.list; \
      sudo apt update && sudo apt install -y brave-browser;;
    3) sudo apt install -y chromium;;
    4) wget -O zen.deb https://github.com/zen-browser/desktop/releases/latest/download/zen-browser-linux-amd64.deb && sudo apt install -y ./zen.deb;;
    5) wget -O chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && sudo apt install -y ./chrome.deb;;
  esac
done

# ── Systemtools
sudo apt install -y xorg xinit picom alacritty fish btop fzf eza bat ripgrep fastfetch feh \
pipewire wireplumber pipewire-pulse zram-tools variety arc-theme papirus-icon-theme tlp preload jq xclip
sudo systemctl enable --now tlp.service || true
sudo apt install -y libx11-dev libxft-dev libxinerama-dev libxrandr-dev libxrender-dev libxext-dev

# ── Fonts
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
mkdir -p ~/.local/share/fonts
wget -q $FONT_URL -O /tmp/JBM.zip
unzip -o /tmp/JBM.zip -d ~/.local/share/fonts >/dev/null
fc-cache -fv >/dev/null

# ── Wallpaper Fix
mkdir -p ~/.config/dwm
if [ -f ./wallpaper.png ]; then
  cp ./wallpaper.png ~/.config/dwm/wallpaper.png
else
  wget -q -O ~/.config/dwm/wallpaper.png https://raw.githubusercontent.com/dennishilk/linux-wallpapers/main/default.png || true
fi

# ── .xinitrc + Autostart
cat > ~/.xinitrc <<EOF
#!/bin/bash
export PATH="\$HOME/.config/dwm/bin:\$PATH"
setxkbmap $XKB &
xrandr --output "\$(xrandr | awk '/ connected/{print \$1;exit}')" --auto
feh --bg-fill ~/.config/dwm/wallpaper.png &
picom --config ~/.config/dwm/picom.conf &
exec dwm
EOF
chmod +x ~/.xinitrc

# ── Fish Config + Autostart
sudo mkdir -p /var/lib; echo 0 | sudo tee /var/lib/system-uptime.db >/dev/null
mkdir -p ~/.config/fish
cat > ~/.config/fish/config.fish <<'EOF'
function fish_greeting
 set_color cyan
 echo "🐧 "(lsb_release -ds)" "(uname -m)
 set_color normal
end
alias exa="eza"
# Autostart DWM bei TTY1
if status is-login
  if test -z "$DISPLAY" -a (tty) = "/dev/tty1"
    echo "🚀 Starting DWM..."
    exec startx -- :0 vt1 >/dev/null 2>&1
  end
end
EOF
chsh -s /usr/bin/fish

# ── DWM + Tools lokal
mkdir -p ~/.config/dwm/src ~/.config/dwm/bin
cd ~/.config/dwm/src
for r in dwm dmenu slstatus; do
  git clone https://git.suckless.org/$r
  cd $r
  sed -i "s|^PREFIX =.*|PREFIX = \$(HOME)/.config/dwm|" config.mk
  if [ "$r" = "dwm" ]; then
    sed -i 's|"st", NULL|"alacritty", NULL|' config.def.h
    sed -i 's|Mod1Mask|Mod4Mask|' config.def.h
  fi
  make clean install
  cd ..
done

echo 'export PATH="$HOME/.config/dwm/bin:$PATH"' >> ~/.bashrc
echo 'set -Ux PATH $HOME/.config/dwm/bin $PATH' | fish >/dev/null 2>&1 || true

echo
echo "✅ Fertig!"
echo "🧠 Automatischer Start von DWM nach Login auf TTY1"
echo "🎨 Wallpaper: ~/.config/dwm/wallpaper.png"
echo "🔥 Nur eine Passworteingabe, keine Patches mehr"
