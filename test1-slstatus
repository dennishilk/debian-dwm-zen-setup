#!/usr/bin/env bash
set -e
echo "⚙️  Erweitere slstatus um Systemdaten …"

sudo apt install -y lm-sensors acpi coreutils

cd ~/.config/dwm/src/slstatus || exit 1

cat > config.def.h <<'EOF'
/* slstatus config by Dennis Hilk */
static const struct arg args[] = {
    /* function format          argument */
    { cpu_perc,   "🧠 %3s%% ", NULL },
    { cpu_freq,   "⚙️ %3sGHz ", NULL },
    { temp,       "🌡️ %2s°C ", "/sys/class/thermal/thermal_zone0/temp" },
    { ram_perc,   "💾 %2s%% ", NULL },
    { vol_perc,   "🔊 %s%% ", "default" },
    { uptime,     "⏱️ %s ", NULL },
    { datetime,   "📅 %s", "%H:%M | %d.%m.%Y" },
};
EOF

make clean install

echo "✅ slstatus erweitert! (CPU-Temp, RAM, Uptime, Lautstärke, Akku, Datum)"
