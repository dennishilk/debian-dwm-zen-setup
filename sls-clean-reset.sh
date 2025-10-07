#!/usr/bin/env bash
set -e

echo "🧹 Starte kompletten slstatus-Reset (clean rebuild, no network/battery) ..."
sleep 1

# ── Prüfen, ob Verzeichnis existiert
SLDIR="$HOME/.config/dwm/src/slstatus"
if [ ! -d "$SLDIR" ]; then
  echo "❌ slstatus-Ordner nicht gefunden unter: $SLDIR"
  exit 1
fi

cd "$SLDIR"

# ── Laufende Instanzen stoppen und alte Binaries entfernen
sudo pkill -x slstatus 2>/dev/null || true
sudo rm -f /usr/local/bin/slstatus
rm -f slstatus config.h

# ── Sauberer Build-Reset
make clean || true

# ── Neue minimalistische Config schreiben
cat > config.def.h <<'EOF'
/* slstatus config — Minimal Desktop Build by Dennis Hilk */
#include <stdio.h>
#include <time.h>
#include "slstatus.h"
#include "util.h"

static const unsigned int interval = 2;
static const char unknown_str[] = "n/a";
#define MAXLEN 2048

static const struct arg args[] = {
    { cpu_perc, "🧠 %3s%% ", NULL },
    { cpu_freq, "⚙️ %3sGHz ", NULL },
    { ram_perc, "💾 %2s%% ", NULL },
    { temp,     "🌡️ %2s°C ", "/sys/class/thermal/thermal_zone0/temp" },
    { vol_perc, "🔊 %s%% ", "default" },
    { uptime,   "⏱️ %s ", NULL },
    { datetime, "📅 %s", "%H:%M | %d.%m.%Y" },
};
EOF

# ── Kompilieren & Installieren
make clean install

# ── Neustart von slstatus
pkill -x slstatus 2>/dev/null || true
slstatus &

# ── Ergebnis
echo
echo "✅ slstatus wurde vollständig neu gebaut!"
echo "🧠 CPU | ⚙️ Freq | 💾 RAM | 🌡️ Temp | 🔊 Volume | ⏱️ Uptime | 📅 Datum"
echo "❌ Keine Netz- oder Akku-Infos mehr enthalten."
echo
ls -lh /usr/local/bin/slstatus | awk '{print "📦 Binary: " $9 " (" $5 ")"}'
