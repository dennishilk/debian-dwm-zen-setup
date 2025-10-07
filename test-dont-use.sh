#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────
#  Debian 13 DWM Ultimate Setup by Dennis Hilk
# ─────────────────────────────────────────────
abort(){ echo "❌ Fehler: $1" >&2; exit 1; }

# ── Root prüfen
[ "$EUID" -eq 0 ] && abort "⚠️ Bitte NICHT als root ausführen – normales Userkonto reicht."
sudo -v || abort "sudo nicht verfügbar oder falsches Passwort."

# ── Debian-Check
. /etc/os-release 2>/dev/null || abort "/etc/os-release nicht gefunden."
[[ "$ID" != "debian" || "$VERSION_CODENAME" != "trixie" ]] && abort "Nur für Debian 13 (Trixie)."
echo "✅ Debian 13 erkannt – Installation startet …"

sudo apt update && sudo apt install -y dialog git curl wget build-essential feh unzip lsb-release pciutils lm-sensors bc make gcc

# ── Zen-Kernel optional
if dialog --yesno "Zen-Kernel installieren?" 8 40; then
  sudo apt install -y linux-image-zen linux-headers-zen || echo "⚠️ Zen-Kernel nicht verfügbar."
fi

# ── GPU-Treiber optional
if dialog --yesno "GPU-Treiber installieren?" 8 40; then
  if lspci | grep -qi nvidia; then sudo apt install -y nvidia-driver nvidia-kernel-dkms
  elif lspci | grep -qi amd; then sudo apt install -y firmware-amd-graphics
  elif lspci | grep -qi intel; then sudo apt install -y i965-driver intel-media-va-driver-non-free
  fi
fi

# ── Tastatur-Layout
KEYBOARD=$(dialog --menu "Wähle Tastatur-Layout:" 15 60 6 \
1 "Deutsch (DE nodeadkeys)" 2 "English (US)" 3 "Français" 4 "Español" 5 "Italiano" 6 "Polski" 3>&1 1>&2 2>&3)
case $KEYBOARD in
 1) XKB="de nodeadkeys";; 2) XKB="us";; 3) XKB="fr";; 4) XKB="es";; 5) XKB="it";; 6) XKB="pl";; *) XKB="us";;
esac

# ── Browser-Menü
BROWSERS=$(dialog --checklist "Browser installieren:" 15 60 5 \
1 "Firefox ESR" on 2 "Brave" off 3 "Chromium" off 4 "Zen Browser" off 5 "Chrome" off 3>&1 1>&2 2>&3)
for b in $BROWSERS; do
 case $b in
  1) sudo apt install -y firefox-esr;;
  2) sudo apt install -y apt-transport-https curl; \
   curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg; \
   echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list; \
   sudo apt update && sudo apt install -y brave-browser;;
  3) sudo apt install -y chromium;;
  4) wget -O zen.deb https://github.com/zen-browser/desktop/releases/latest/download/zen-browser-linux-amd64.deb && sudo apt install -y ./zen.deb;;
  5) wget -O chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && sudo apt install -y ./chrome.deb;;
 esac
done

# ── Basis-Pakete + Tweaks
sudo apt install -y xorg xinit picom alacritty fish btop fzf eza bat ripgrep fastfetch feh \
pipewire wireplumber pipewire-pulse zram-tools variety arc-theme papirus-icon-theme tlp preload jq xclip
sudo systemctl enable --now tlp.service || true

# ── X11 Dev-Pakete für DWM Build
sudo apt install -y libx11-dev libxft-dev libxinerama-dev libxrandr-dev libxrender-dev libxext-dev

# ── Timeshift optional
if dialog --yesno "Timeshift installieren?" 8 45; then
 sudo sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
 sudo apt update && sudo apt install -y timeshift || echo "⚠️ Timeshift nicht verfügbar."
fi

# ── ZRAM
sudo sed -i 's/^#\?ALGO=.*/ALGO=zstd/' /etc/default/zramswap
sudo sed -i 's/^#\?PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo systemctl enable --now zramswap.service

# ── Nerd Font
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
mkdir -p ~/.local/share/fonts; wget -q $FONT_URL -O /tmp/JBM.zip; unzip -o /tmp/JBM.zip -d ~/.local/share/fonts >/dev/null; fc-cache -fv >/dev/null

# ── .xinitrc + Wallpaper
mkdir -p ~/.config/dwm; [ -f ./wallpaper.png ] && cp ./wallpaper.png ~/.config/dwm/
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

# ── Fish Dashboard + Auto-Start DWM
chsh -s /usr/bin/fish
sudo mkdir -p /var/lib; echo 0 | sudo tee /var/lib/system-uptime.db >/dev/null
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
 set n (math "$u + $s")
 echo $n | sudo tee /var/lib/system-uptime.db >/dev/null
 set d (math "scale=2; $n / 86400")
 echo "🕓 Total Uptime:" $d" days"
 echo "📦 Packages:" (dpkg -l | grep '^ii' | wc -l)" (apt)"
 echo "💻 Shell:" (fish --version | awk '{print $3}')
 echo "🧩 WM: dwm"
 echo "🎮 GPU:" (lspci | grep -E 'VGA|3D' | awk -F ': ' '{print $3}' | head -n1)
 echo "💾 RAM:" (free -h | awk '/Mem/ {print $3 " / " $2}')
 echo "──────────────────────────────────────────────"
 set_color normal
end
alias exa="eza"
# Auto-Start DWM bei Login auf TTY1 (ohne startx)
if test -z "$DISPLAY" and test (tty) = "/dev/tty1"
 echo "🚀 Starting DWM..."
 exec startx -- :0 vt1 >/dev/null 2>&1
end
EOF

# ── DWM + Tools lokal in ~/.config
mkdir -p ~/.config/dwm/src ~/.config/dwm/bin
cd ~/.config/dwm/src
for r in dwm dmenu slstatus; do
 git clone https://git.suckless.org/$r; cd $r
 sed -i "s|^PREFIX =.*|PREFIX = \$(HOME)/.config/dwm|" config.mk
 if [ "$r" = "dwm" ]; then
  sed -i 's|"st", NULL|"alacritty", NULL|' config.def.h
  sed -i 's|Mod1Mask|Mod4Mask|' config.def.h
 fi
 make clean install
 cd ..
done

# ── Optionale DWM-Patches (von GitHub-Mirror)
if dialog --yesno "DWM-Patches installieren (vanitygaps, pertag, systray, alpha)?" 8 60; then
 cd ~/.config/dwm/src/dwm
 PATCH_BASE="https://raw.githubusercontent.com/bakkeby/patches/master/dwm"
 for p in vanitygaps pertag systray alpha; do
  echo "📦 Applying patch: $p"
  curl -fsSL "$PATCH_BASE/$p.diff" -o "$p.diff" || { echo "⚠️ $p konnte nicht geladen werden"; continue; }
  patch -p1 < "$p.diff" || { echo "⚠️ Patch $p übersprungen."; continue; }
 done
 make clean install
fi

# ── PATH
echo 'export PATH="$HOME/.config/dwm/bin:$PATH"' >> ~/.bashrc
echo 'set -Ux PATH $HOME/.config/dwm/bin $PATH' | fish

echo; echo "✅ Installation abgeschlossen!"
echo "🧠 Automatischer Start in DWM nach Login auf TTY1"
echo "🔥 Raw-Patches aktiv und nur eine Passwortabfrage!"
