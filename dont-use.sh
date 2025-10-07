#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Dennis Hilk – DWM Installer (BreadOnPenguins Base ! thankya)
# Vollautomatische Installation & Konfiguration für Debian 13
# Enthält: swallow, vanitygaps, statuscmd, xrdb
# ─────────────────────────────────────────────────────────────
set -e
set -o pipefail

USER_NAME=$(logname)
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config/dwm"
REPO_URL="https://github.com/BreadOnPenguins/dwm.git"
WALLPAPER="$PWD/wallpaper.png"

# ── Root-Check
if [[ $EUID -ne 0 ]]; then
    echo "Bitte als root ausführen: sudo bash $0"
    exit 1
fi

echo "──────────────────────────────────────────"
echo "🧰 Dennis Hilk – DWM Installer (BreadOnPenguins Base)"
echo "──────────────────────────────────────────"
sleep 1

# ── Update & Pakete
apt update
apt install -y \
  build-essential gcc make pkg-config git wget curl \
  xorg xinit feh fish alacritty \
  libx11-dev libxft-dev libxinerama-dev libxrandr-dev libxrender-dev libxext-dev

# ── GPU-Erkennung
echo "🔍 Erkenne Grafiktreiber..."
if lspci | grep -i nvidia &>/dev/null; then
    GPU="nvidia"
    apt install -y nvidia-driver firmware-misc-nonfree
elif lspci | grep -i amd &>/dev/null; then
    GPU="amd"
    apt install -y firmware-amd-graphics mesa-vulkan-drivers
elif lspci | grep -i intel &>/dev/null; then
    GPU="intel"
    apt install -y intel-media-va-driver mesa-vulkan-drivers
else
    GPU="unknown"
fi
echo "→ GPU: $GPU"

# ── Browser
if ! command -v google-chrome-stable &>/dev/null; then
    echo "🔽 Installiere Google Chrome Stable..."
    wget -q -O- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | tee /usr/share/keyrings/google.gpg >/dev/null
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
    apt update && apt install -y google-chrome-stable
fi

# ── Clone Repo
echo "⬇️ Klone DWM..."
sudo -u "$USER_NAME" git clone "$REPO_URL" "$CONFIG_DIR" || true
cd "$CONFIG_DIR"

# ── Backup alter Config
[ -f config.def.h ] && mv config.def.h config.def.h.bak

# ── Neue config.def.h
cat > config.def.h <<'EOF'
/* Dennis Hilk – config.def.h (BreadOnPenguins Base) */
static const unsigned int borderpx  = 2;
static const unsigned int snap      = 32;
static const unsigned int gappih    = 8;
static const unsigned int gappiv    = 8;
static const unsigned int gappoh    = 12;
static const unsigned int gappov    = 12;
static const char *fonts[]          = { "JetBrainsMono Nerd Font:size=11" };
static const char col_bg[]          = "#2E3440";
static const char col_fg[]          = "#D8DEE9";
static const char col_acc[]         = "#88C0D0";
static const char *colors[][3]      = {
	[SchemeNorm] = { col_fg, col_bg, col_bg },
	[SchemeSel]  = { col_bg, col_acc, col_acc },
};
#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
	{ MODKEY, KEY, view, {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask, KEY, toggleview, {.ui = 1 << TAG} }, \
	{ MODKEY|ShiftMask, KEY, tag, {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask|ShiftMask, KEY, toggletag, {.ui = 1 << TAG} },

static const char *termcmd[]  = { "alacritty", "-e", "fish", NULL };
static const char *browsercmd[] = { "google-chrome-stable", NULL };
static const char *dmenucmd[] = { "dmenu_run", NULL };

static Key keys[] = {
	{ MODKEY, XK_Return, spawn, {.v = termcmd } },
	{ MODKEY, XK_d,      spawn, {.v = dmenucmd } },
	{ MODKEY, XK_b,      spawn, {.v = browsercmd } },
	{ MODKEY|ShiftMask,  XK_q,  quit, {0} },
	{ MODKEY|ShiftMask,  XK_r,  quit, {1} },
};
EOF

# ── Build
echo "⚙️ Kompiliere DWM..."
sudo -u "$USER_NAME" make clean
sudo -u "$USER_NAME" make
make install

# ── Wallpaper und Autostart
mkdir -p "$USER_HOME/.config/dwm"
if [[ -f "$WALLPAPER" ]]; then
    cp "$WALLPAPER" "$USER_HOME/.config/dwm/wallpaper.png"
    chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/dwm/wallpaper.png"
fi

cat > "$USER_HOME/.xinitrc" <<'EOF'
#!/bin/bash
feh --bg-scale ~/.config/dwm/wallpaper.png &
pipewire &
exec dwm
EOF
chown "$USER_NAME:$USER_NAME" "$USER_HOME/.xinitrc"
chmod +x "$USER_HOME/.xinitrc"

# ── Auto-Login & Startx auf TTY1
AUTOLOGIN_DIR="/etc/systemd/system/getty@tty1.service.d"
mkdir -p "$AUTOLOGIN_DIR"
cat > "$AUTOLOGIN_DIR/override.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I 38400 linux
EOF
systemctl daemon-reexec
systemctl restart getty@tty1.service

AUTO_CMD='[ "$(tty)" = "/dev/tty1" ] && ! pgrep -x dwm >/dev/null && startx'
grep -qxF "$AUTO_CMD" "$USER_HOME/.bash_profile" 2>/dev/null || echo "$AUTO_CMD" >> "$USER_HOME/.bash_profile"
chown "$USER_NAME:$USER_NAME" "$USER_HOME/.bash_profile"

# ── Fertig
clear
echo "✅ Installation abgeschlossen!"
echo "───────────────────────────────"
echo "🎨 Config: $CONFIG_DIR"
echo "🐧 GPU: $GPU"
echo "🐟 Shell: Fish (default)"
echo "🖥️ DWM startet automatisch auf TTY1"
echo "🌄 Wallpaper: $WALLPAPER"
echo "───────────────────────────────"
echo "Neustart oder Abmelden → DWM startet direkt."
