#!/usr/bin/env bash
set -e
echo "🧠 Installing system monitoring tools ..."

sudo apt install -y conky btop lm-sensors fastfetch jq

# ── Sensors einrichten
sudo sensors-detect --auto || true

# ── Fastfetch Branding (für Terminalstart)
mkdir -p ~/.config/fastfetch
cat > ~/.config/fastfetch/config.jsonc <<'EOF'
{
  "display": {
    "separator": " ",
    "color": "blue"
  },
  "modules": [
    { "type": "title" },
    { "type": "os" },
    { "type": "kernel" },
    { "type": "uptime" },
    { "type": "cpu" },
    { "type": "gpu" },
    { "type": "memory" },
    { "type": "disk" },
    { "type": "shell" },
    { "type": "wm" },
    { "type": "terminal" },
    { "type": "packages" },
    { "type": "localip" }
  ]
}
EOF

# ── Fish automatisch fastfetch beim Start anzeigen
if ! grep -q "fastfetch" ~/.config/fish/config.fish; then
  echo "fastfetch" >> ~/.config/fish/config.fish
fi

# ── Conky Config (transparent overlay)
mkdir -p ~/.config/conky
cat > ~/.config/conky/conky.conf <<'EOF'
conky.config = {
    alignment = 'top_right',
    background = false,
    use_xft = true,
    font = 'JetBrainsMono Nerd Font:size=10',
    xftalpha = 0.8,
    own_window = true,
    own_window_type = 'dock',
    own_window_transparent = true,
    own_window_argb_visual = true,
    own_window_argb_value = 80,
    update_interval = 2.0,
    double_buffer = true,
    draw_shades = false,
    draw_outline = false,
    draw_borders = false,
    draw_graph_borders = false,
    use_spacer = 'none',
    gap_x = 25,
    gap_y = 45,
    minimum_width = 250,
    maximum_width = 350,
    cpu_avg_samples = 2,
    short_units = true,
    override_utf8_locale = true
}

conky.text = [[
${color grey}🧠 CPU:${color white} ${cpu cpu0}%  ${color grey}Temp:${color white} ${hwmon 0 temp 1}°C
${color grey}💾 RAM:${color white} $mem/$memmax ($memperc%)
${color grey}💽 Disk:${color white} ${fs_used /}/${fs_size /} (${fs_used_perc /}%)
${color grey}🧩 GPU:${color white} ${execi 10 nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null || sensors | grep -m1 'edge' | awk '{print $2}' | tr -d '+'}°C
${color grey}🌐 Net:${color white} ${downspeed eth0} ↓↑ ${upspeed eth0}
${color grey}⏱️ Uptime:${color white} $uptime
${color grey}📅 Date:${color white} ${time %A, %d %B %Y}
${color grey}🕓 Time:${color white} ${time %H:%M:%S}
]]
EOF

# ── Autostart für Conky hinzufügen
mkdir -p ~/.config/dwm/autostart
if ! grep -q "conky" ~/.config/dwm/autostart.sh 2>/dev/null; then
  echo "conky -c ~/.config/conky/conky.conf &" >> ~/.config/dwm/autostart.sh
fi

# ── btop Config (optional dark theme)
mkdir -p ~/.config/btop
cat > ~/.config/btop/btop.conf <<'EOF'
color_theme = "TTY"
proc_sorting = "cpu lazy"
show_gpu = True
update_ms = 2000
EOF

echo
echo "✅ System Monitoring eingerichtet!"
echo "📊 Conky Overlay aktiv bei Desktop-Start"
echo "⚙️  Fastfetch im Terminal"
echo "📈 btop verfügbar mit GPU/CPU Übersicht"
