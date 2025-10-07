#!/usr/bin/env bash
set -e

echo "🧠 Setze slstatus auf minimal-konfiguration (ohne Netz & Batterie) ..."

cd ~/.config/dwm/src/slstatus || { echo "❌ slstatus-Ordner nicht gefunden!"; exit 1; }

# ── Neue minimalistische Konfiguration schreiben
cat > config.def.h <<'EOF'
/* slstatus config — Minimal Setup (Desktop) by Dennis Hilk */
#include <stdio.h>
#include <time.h>
#include "slstatus.h"
#include "util.h"

/* Update Intervall in Sekunden */
static const unsigned int interval = 2;
static const char unknown_str[] = "n/a";
#define MAXLEN 2048

/* Minimaler Statusbar-Block ohne Netzwerk & Batterie */
static const struct arg args[] = {
    { cpu_perc,   "🧠 %3s%% ",      NULL },
    { cpu_freq,   "⚙️ %3sGHz ",     NULL },
    { ram_perc,   "💾 %2s%% ",      NULL },
    { temp,       "🌡️ %2s°C ",      "/sys/class/thermal/thermal_zone0/temp" },
    { vol_perc,   "🔊 %s%% ",       "default" },
    { uptime,     "⏱️ %s ",         NULL },
    { datetime,   "📅 %s",          "%H:%M | %d.%m.%Y" },
};
EOF

# ── Alte Config löschen & neu bauen
rm -f config.h
make clean install

# ── slstatus neu starten
pkill -x slstatus 2>/dev/null || true
slstatus &

echo
echo "✅ slstatus minimal neu gebaut!"
echo "➡️  CPU | RAM | Temp | Volume | Uptime | Datum"
echo "❌ Keine Netz- oder Batterie-Abfragen mehr."
