#!/usr/bin/env bash
set -e
echo "🎮 Installiere Gaming-Optimierungen …"

# ── Pakete
sudo apt install -y gamemode mangohud vkbasalt steam lutris wine winetricks

# ── systemd-Integration aktivieren
sudo systemctl enable --now gamemoded.service

# ── Mangohud Config
mkdir -p ~/.config/MangoHud
cat > ~/.config/MangoHud/MangoHud.conf <<'EOF'
fps_limit=0
toggle_hud=Shift_R+F12
legacy_layout=0
font_size=22
position=top-right
background_alpha=0.6
no_display=0
cpu_stats
gpu_stats
vram
ram
fps
frametime
frame_timing
EOF

# ── VKBasalt (optional post-processing)
mkdir -p ~/.config/vkBasalt
cat > ~/.config/vkBasalt/vkBasalt.conf <<'EOF'
effects = sharpen; contrast; vibrance;
sharpen_intensity = 0.3
contrast = 0.05
vibrance = 0.05
EOF

# ── Auto-Integration für Steam, Lutris, Wine
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/gaming.conf <<'EOF'
# ── Global Gaming Environment
export GAMEMODERUNEXEC="gamemoderun"
export MANGOHUD=1
export VKBASALT_CONFIG_FILE="$HOME/.config/vkBasalt/vkBasalt.conf"
export ENABLE_VKBASALT=1
EOF

# ── Steam Startskript Hook
if command -v steam >/dev/null 2>&1; then
  mkdir -p ~/.local/share/applications
  cat > ~/.local/share/applications/steam-gamemode.desktop <<'EOF'
[Desktop Entry]
Name=Steam (GameMode)
Exec=env MANGOHUD=1 gamemoderun steam
Icon=steam
Type=Application
Categories=Game;
EOF
fi

# ── Wine Hook alias
echo 'alias wine="gamemoderun wine"' >> ~/.config/fish/config.fish
echo 'alias lutris="gamemoderun lutris"' >> ~/.config/fish/config.fish

# ── Powertop optional tuning
sudo apt install -y powertop
sudo powertop --auto-tune || true

# ── Infos
echo
echo "✅ Gaming Setup installiert!"
echo "⚙️  GameMode + MangoHud + VKBasalt aktiv"
echo "🎮  Steam + Wine + Lutris laufen automatisch mit GameMode"
echo "🧠  FPS-Overlay: Rechts Shift + F12"
echo "💡  Beispiel: gamemoderun mangohud glxgears"
